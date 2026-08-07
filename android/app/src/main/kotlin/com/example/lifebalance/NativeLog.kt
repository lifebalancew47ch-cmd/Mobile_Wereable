package com.example.lifebalance

import android.util.Log

/**
 * A-02 (audit de seguridad): los logs de PHI (HR, HRV, SpO2, pasos) de los
 * componentes Kotlin del teléfono deben desaparecer de logcat en release.
 * `debugPrint` de Dart no se elimina en release, y `Log.d` de Android tampoco.
 * Este wrapper es no-op fuera de DEBUG como defensa determinista (la regla
 * ProGuard de `-assumenosideeffects` es un refuerzo adicional).
 */
object NativeLog {
    private val ENABLED = BuildConfig.DEBUG

    fun d(tag: String, msg: String) {
        if (ENABLED) Log.d(tag, msg)
    }

    fun w(tag: String, msg: String) {
        if (ENABLED) Log.w(tag, msg)
    }

    fun e(tag: String, msg: String, t: Throwable? = null) {
        if (ENABLED) Log.e(tag, msg, t)
    }
}