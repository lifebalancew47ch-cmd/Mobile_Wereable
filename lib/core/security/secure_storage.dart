import '../utils/app_log.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Instancia de `flutter_secure_storage` con `encryptedSharedPreferences:
/// true` en Android (M-02 del audit de seguridad): el default de la v9.x es
/// `false`, que usa el modo heredado (valores cifrados individualmente con
/// el Android Keystore dentro de una SharedPreferences normal) en vez de
/// `EncryptedSharedPreferences` de Jetpack Security. En iOS `AndroidOptions`
/// simplemente se ignora (ya usa Keychain, no hay nada que migrar).
///
/// Esta es la instancia real que se inyecta en producción (`main.dart`,
/// `token_service.dart`, `api_client.dart`, `encryption_service.dart`,
/// `login_screen.dart`, `biometric_profile_screen.dart`). Los tests siguen
/// inyectando su propio mock de `FlutterSecureStorage`, así que no se ven
/// afectados por este cambio.
const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Instancia con las opciones heredadas (el default anterior a este fix),
/// usada únicamente por la migración de arranque.
const _legacySecureStorage = FlutterSecureStorage();

/// Todas las claves que vivían en el almacenamiento heredado antes de M-02.
/// Debe mantenerse en sync con `TokenService`, `EncryptionService`,
/// `LoginScreen` y `BiometricProfileScreen`.
const _legacyKeys = [
  'access_token',
  'refresh_token',
  'user_cache',
  'db_encryption_key',
  'saved_email',
  'remember_me',
  'biometric_gender',
  'biometric_height_cm',
  'biometric_weight_kg',
  'biometric_age',
];

/// Migra, una sola vez por arranque, los valores que existan bajo el backend
/// heredado de `flutter_secure_storage` hacia `secureStorage`
/// (`encryptedSharedPreferences: true`). En Android, cambiar esa opción sin
/// migrar equivale a perder el valor -- es un archivo de almacenamiento
/// distinto, no solo un cifrado distinto. Para tokens/biométricos eso solo
/// forzaría un re-login molesto; para la clave de `EncryptionService` sería
/// mucho peor: la base SQLCipher local quedaría ilegible y se borraría por
/// completo al no poder abrirse con una clave nueva generada por error.
///
/// Debe llamarse en `main()` antes de `SecureDatabaseService.instance.database`
/// (que dispara `EncryptionService.getEncryptionKey()`) y antes de que
/// cualquier pantalla lea tokens. Nunca lanza: cualquier fallo se degrada a
/// "no había nada que migrar" en vez de bloquear el arranque de la app.
Future<void> migrateLegacySecureStorageIfNeeded() async {
  for (final key in _legacyKeys) {
    try {
      final alreadyMigrated = await secureStorage.containsKey(key: key);
      if (alreadyMigrated) continue;

      final legacyValue = await _legacySecureStorage.read(key: key);
      if (legacyValue == null) continue;

      await secureStorage.write(key: key, value: legacyValue);
      await _legacySecureStorage.delete(key: key);
    } catch (e) {
      AppLog.d('[SecureStorageMigration] No se pudo migrar "$key": $e');
    }
  }
}
