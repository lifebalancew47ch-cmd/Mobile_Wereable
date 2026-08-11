import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_log.dart';
import 'secure_storage.dart';

/// Preferencia de bloqueo biométrico al reabrir la app (`AuthGate`).
///
/// A-02 (fix 07/08/2026): migrado de SharedPreferences (texto plano,
/// manipulable con root) a FlutterSecureStorage (Android Keystore /
/// iOS Keychain). Un atacante con root ya no puede deshabilitar el
/// biometric lock modificando un archivo XML plano.
///
/// Incluye migración one-shot transparente: si el valor existe en
/// SharedPreferences (instalaciones previas), se migra y se borra.
class AppLockPreferences {
  static const _kBiometricLockEnabled = 'security_biometric_lock_enabled';

  static Future<bool> isBiometricLockEnabled() async {
    try {
      // Intentar leer desde SecureStorage (nuevo destino).
      final secureVal = await secureStorage.read(key: _kBiometricLockEnabled);
      if (secureVal != null) return secureVal == 'true';

      // Migración one-shot desde SharedPreferences (instalaciones previas).
      final prefs = await SharedPreferences.getInstance();
      final legacyVal = prefs.getBool(_kBiometricLockEnabled);
      if (legacyVal != null) {
        await secureStorage.write(
          key: _kBiometricLockEnabled,
          value: legacyVal.toString(),
        );
        await prefs.remove(_kBiometricLockEnabled);
        return legacyVal;
      }

      return false; // Default: bloqueo desactivado.
    } catch (e) {
      // Fail-closed: si no se puede leer, tratar como desactivado
      // (no bloquear al usuario fuera de su propia app).
      AppLog.d('[AppLockPreferences] Error leyendo preferencia: $e');
      return false;
    }
  }

  static Future<void> setBiometricLockEnabled(bool value) async {
    try {
      await secureStorage.write(
        key: _kBiometricLockEnabled,
        value: value.toString(),
      );
    } catch (e) {
      AppLog.d('[AppLockPreferences] Error guardando preferencia: $e');
    }
    if (!value) {
      // Si el usuario apaga el bloqueo, no debe quedar una sesión
      // "a medio desbloquear" pendiente de una vuelta anterior.
      appUnlockedThisSession = true;
    } else {
      // Si lo enciende, la próxima navegación protegida debe pedirlo.
      appUnlockedThisSession = false;
    }
  }
}

/// `true` una vez que el usuario ya desbloqueó `AuthGate` en esta sesión de
/// proceso. Deliberadamente NO persiste entre reinicios: cada arranque en
/// frío del proceso Dart debe volver a pedir biometría si el bloqueo está
/// activo.
///
/// A-03 (fix 07/08/2026): se resetea también cuando la app va a background,
/// via `WidgetsBindingObserver.didChangeAppLifecycleState` en `_MyAppState`.
/// Así se exige biometría tanto al reiniciar en frío como al volver
/// de background dentro del mismo proceso.
bool appUnlockedThisSession = false;
