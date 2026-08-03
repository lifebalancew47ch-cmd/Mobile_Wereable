package com.example.lifebalance

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Convierte el contador acumulado de `TYPE_STEP_COUNTER` (desde el último
 * reinicio del reloj) en pasos del día actual, guardando el baseline del
 * día en SharedPreferences. Al cambiar de fecha el baseline se reinicia.
 */
object TodaySteps {
    private const val PREFS = "wear_settings"
    private const val KEY_VALUE = "steps_baseline_value"
    private const val KEY_DATE = "steps_baseline_date"

    fun of(context: Context, rawSteps: Int): Int {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val savedDate = prefs.getString(KEY_DATE, null)
        val savedValue = prefs.getInt(KEY_VALUE, -1)

        if (savedDate != today || savedValue < 0) {
            prefs.edit()
                .putString(KEY_DATE, today)
                .putInt(KEY_VALUE, rawSteps)
                .apply()
            return 0
        }

        if (rawSteps < savedValue) {
            // El reloj se reinició: el contador vuelve a 0. Reiniciar baseline.
            prefs.edit().putInt(KEY_VALUE, rawSteps).apply()
            return 0
        }

        return rawSteps - savedValue
    }
}
