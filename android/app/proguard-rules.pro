# Reglas ProGuard/R8 para el release del APK.
#
# A-02 (audit de seguridad): los logs de Android (Log.d/v/i) escriben a
# logcat incluso en release. En el módulo :app el release minifica con R8,
# así que estas reglas eliminan las llamadas de las capas Kotlin. Las capas
# Dart usan AppLog (no-op fuera de debug) y el módulo :wear usa WearLog.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}