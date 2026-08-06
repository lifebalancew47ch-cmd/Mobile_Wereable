import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de bloqueo biométrico al reabrir la app (`AuthGate`).
///
/// `AuthGate` (`core/security/auth_gate.dart`) implementaba un app-lock
/// biométrico completo con `local_auth` que nunca se instanciaba en ningún
/// flujo de navegación real -- una app de datos de salud sin bloqueo al
/// reabrir. Este archivo persiste la preferencia (apagada por defecto, para
/// no bloquear a usuarios existentes al actualizar sin aviso) y el router
/// (`app_router.dart`) la consulta para decidir si interceptar la navegación
/// con `AuthGate`.
class AppLockPreferences {
  static const _kBiometricLockEnabled = 'security_biometric_lock_enabled';

  static Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricLockEnabled) ?? false;
  }

  static Future<void> setBiometricLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricLockEnabled, value);
    if (!value) {
      // Si el usuario apaga el bloqueo, no debe quedar una sesión "a medio
      // desbloquear" pendiente de una vuelta anterior.
      appUnlockedThisSession = true;
    } else {
      // Si lo enciende, la próxima navegación protegida debe volver a pedirlo.
      appUnlockedThisSession = false;
    }
  }
}

/// `true` una vez que el usuario ya desbloqueó `AuthGate` en esta sesión de
/// proceso. Deliberadamente NO persiste entre reinicios: cada arranque en
/// frío del proceso Dart debe volver a pedir biometría si el bloqueo está
/// activo. (No re-bloquea al volver de background dentro del mismo proceso;
/// eso requeriría un `WidgetsBindingObserver` a nivel app, fuera del alcance
/// de este fix.)
bool appUnlockedThisSession = false;
