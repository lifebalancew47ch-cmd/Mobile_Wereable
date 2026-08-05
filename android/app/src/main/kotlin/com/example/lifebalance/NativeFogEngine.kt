package com.example.lifebalance

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.sqrt

/**
 * Motor nativo de detección de sedentarismo en Kotlin (FogEngine nativo).
 * Procesa datos recibidos del wearable cuando la UI de Flutter no está activa
 * (app en segundo plano o destruida por el sistema).
 */
class NativeFogEngine private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: NativeFogEngine? = null

        fun getInstance(context: Context): NativeFogEngine {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: NativeFogEngine(context.applicationContext).also { INSTANCE = it }
            }
        }

        private const val PREFS_NAME = "native_fog_prefs"
        private const val KEY_IDLE_WINDOWS = "idle_windows"
        private const val KEY_ALERT_SHOWN = "alert_shown"
        private const val KEY_THRESHOLD_MINUTES = "alert_threshold_minutes"
        private const val VARIANCE_THRESHOLD = 0.05
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val currentMagnitudes = mutableListOf<Double>()
    private var lastWindowTime = System.currentTimeMillis()
    private var alertShown: Boolean
        get() = prefs.getBoolean(KEY_ALERT_SHOWN, false)
        set(value) = prefs.edit().putBoolean(KEY_ALERT_SHOWN, value).apply()

    private var idleWindows: Long
        get() = prefs.getLong(KEY_IDLE_WINDOWS, 0L)
        set(value) = prefs.edit().putLong(KEY_IDLE_WINDOWS, value).apply()

    private val alertThresholdMinutes: Long
        get() = prefs.getLong(KEY_THRESHOLD_MINUTES, 45L)

    init {
        createNotificationChannel()
    }

    /**
     * Procesa un lote de lecturas JSON recibido del Wearable.
     */
    @Synchronized
    fun processBatchJson(jsonString: String) {
        try {
            val jsonArray = JSONArray(jsonString)
            val now = System.currentTimeMillis()

            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                val x = obj.optDouble("x", 0.0)
                val y = obj.optDouble("y", 0.0)
                val z = obj.optDouble("z", 0.0)

                val mag = sqrt(x * x + y * y + z * z)
                if (mag.isFinite() && mag > 0) {
                    currentMagnitudes.add(mag)
                }
            }

            // Si han pasado 30 segundos o más desde el último análisis de ventana
            if (now - lastWindowTime >= 30_000L) {
                analyzeWindow()
                lastWindowTime = now
            }
        } catch (e: Exception) {
            Log.e("NativeFogEngine", "Error procesando lote JSON: ${e.message}")
        }
    }

    private fun analyzeWindow() {
        if (currentMagnitudes.isEmpty()) return

        val count = currentMagnitudes.size
        var sum = 0.0
        for (v in currentMagnitudes) {
            sum += v
        }
        val mean = sum / count

        var sqSum = 0.0
        for (v in currentMagnitudes) {
            val diff = v - mean
            sqSum += diff * diff
        }
        val variance = sqSum / count
        currentMagnitudes.clear()

        val alertThresholdWindows = alertThresholdMinutes * 2

        if (variance < VARIANCE_THRESHOLD) {
            // Ventana inactiva
            idleWindows++
            Log.d("NativeFogEngine", "Ventana inactiva nativa ($idleWindows/$alertThresholdWindows). Varianza: $variance")

            if (idleWindows >= alertThresholdWindows && !alertShown) {
                alertShown = true
                triggerNotification()
            }
        } else {
            // Movimiento detectado -> Reinicia contador
            Log.d("NativeFogEngine", "Movimiento detectado nativo. Varianza: $variance. Contador reiniciado.")
            idleWindows = 0L
            alertShown = false
        }
    }

    private fun triggerNotification() {
        val minutes = idleWindows / 2
        Log.w("NativeFogEngine", "¡ALERTA DE SEDENTARISMO NATIVA! $minutes minutos inactivo.")

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, "inactivity_alert_channel")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle("LifeBalance · ¡Hora de moverse!")
            .setContentText("Llevas $minutes minutos inactivo. Tómate una pausa activa.")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(8888, builder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "inactivity_alert_channel",
                "Inactivity Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alertas de sedentarismo de LifeBalance"
                enableVibration(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
