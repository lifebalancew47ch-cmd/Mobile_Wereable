import 'package:flutter/foundation.dart';

/// Wrapper de logging de la aplicación (A-02 del audit de seguridad).
///
/// `debugPrint` NO se elimina en release: escribe a stdout/logcat siempre.
/// Todo log que pueda llevar datos personales o de salud (HR, HRV, SpO2,
/// pasos, peso, sexo, edad, etc.) DEBE pasar por [AppLog.d]: fuera de
/// debug/profile no imprime nada, así un build de producción no puede volcar
/// PHI a logcat.
abstract final class AppLog {
  /// Log de depuración. No-op fuera de `kDebugMode`.
  static void d(String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    if (error != null) {
      debugPrint('$message\n$error'
          '${stackTrace != null ? '\n$stackTrace' : ''}');
    } else {
      debugPrint(message);
    }
  }
}