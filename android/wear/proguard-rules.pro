# Reglas ProGuard/R8 del módulo Wear OS.
# El release de :wear NO minifica (isMinifyEnabled = false) porque el
# framework Wear OS + Health Services no lo tolera sin reglas extensas.
# La protección de logs a logcat en release la garantiza WearLog (no-op
# fuera de BuildConfig.DEBUG). Estas reglas se conservan por si en el
# futuro se activa R8 en este módulo.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}