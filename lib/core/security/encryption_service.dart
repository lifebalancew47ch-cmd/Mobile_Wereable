import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'secure_storage.dart';

class EncryptionService {
  // Tipado explícito a `FlutterSecureStorage` (Keystore/Keychain) a
  // propósito, aunque `secureStorage` ya lo es: `test/security/masvs/
  // secure_storage_test.dart` verifica estáticamente que este archivo
  // referencia `FlutterSecureStorage` y nunca `SharedPreferences` para la
  // clave de cifrado (MASVS-STORAGE-2).
  static const FlutterSecureStorage _storage = secureStorage;
  static const _keyAlias = 'db_encryption_key';

  /// Recupera la clave de encriptación AES. Si no existe, genera una nueva y la guarda de forma segura.
  ///
  /// La migración desde el backend heredado de `flutter_secure_storage`
  /// (antes de M-02) ya corrió una sola vez al arrancar la app
  /// (`migrateLegacySecureStorageIfNeeded` en `main.dart`), así que para
  /// cuando esto se llama la clave ya está en `secureStorage` si existía.
  /// Deliberadamente NO se migra aquí en cada lectura: esta es la clave que
  /// abre la base SQLCipher local, y si por error se generara una nueva
  /// clave creyendo que no existía, la base cifrada con la vieja quedaría
  /// ilegible (`_initDB` la borraría por completo al no poder abrirla).
  static Future<String> getEncryptionKey() async {
    String? key = await _storage.read(key: _keyAlias);
    if (key == null) {
      key = generateRandomKey();
      await _storage.write(key: _keyAlias, value: key);
    }
    return key;
  }

  /// Genera una clave AES-256 (32 bytes) con [Random.secure], codificada en
  /// base64url. Nunca debe loguearse ni persistirse fuera de Secure Storage.
  static String generateRandomKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  /// Borra la clave de encriptación almacenada en Secure Storage (SessionWiper).
  static Future<void> clearEncryptionKey() async {
    await _storage.delete(key: _keyAlias);
  }
}
