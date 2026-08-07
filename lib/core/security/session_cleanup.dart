import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_log.dart';

/// SessionWiper: limpia de `SharedPreferences` (almacenamiento plano) las
/// claves no-credenciales que escriben distintos servicios del dispositivo:
/// datos biométricos locales, el último JSON crudo del wearable y el estado
/// del motor Fog nativo.
///
/// Aislado de `token_service.dart` a propósito: los tokens JWT viven
/// ÚNICAMENTE en `flutter_secure_storage`. Este módulo es el único lugar de
/// la capa de seguridad que toca `shared_preferences`, y garantiza que jamás
/// se escriba un `access_token`/`refresh_token` en almacenamiento plano.
Future<void> clearSensitiveSharedPreferences() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keysToClear = prefs.getKeys().where((k) =>
      k.startsWith('biometric_') ||
      k == 'flutter.latest_wear_json' ||
      k.contains('native_fog')
    ).toList();
    for (final key in keysToClear) {
      await prefs.remove(key);
    }
  } catch (e) {
    // No se puede hacer nada útil si SharedPreferences falla; el logout ya
    // borró tokens y purgó la base cifrada. El error no debe propagarse.
    AppLog.d('[SessionWiper] Error limpiando SharedPreferences: $e');
  }
}