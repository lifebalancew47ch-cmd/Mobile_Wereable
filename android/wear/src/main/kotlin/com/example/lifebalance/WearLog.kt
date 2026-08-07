package com.example.lifebalance

import android.util.Log

/**
 * A-02 (audit de seguridad): `Log.d/i/v` escriben a logcat incluso en
 * release. El reloj recoge HR, HRV, SpO2 y pasos; esos datos no deben
 * aparecer en logcat de producción. Este wrapper es no-op fuera de debug
 * y, además, el release del módulo :wear NO minifica (isMinifyEnabled=false),
 * así que una regla ProGuard por sí sola no bastaría aquí.
 */
object WearLog {
    private val ENABLED = BuildConfig.DEBUG

    fun d(tag: String, msg: String) {
        if (ENABLED) Log.d(tag, msg)
    }

    fun w(tag: String, msg: String) {
        if (ENABLED) Log.w(tag, msg)
    }

    fun e(tag: String, msg: String) {
        if (ENABLED) Log.e(tag, msg)
    }

    fun e(tag: String, msg: String, t: Throwable?) {
        if (ENABLED) Log.e(tag, msg, t)
    }
}