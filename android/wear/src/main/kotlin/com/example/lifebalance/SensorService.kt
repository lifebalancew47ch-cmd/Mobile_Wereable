package com.example.lifebalance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener2
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.Log
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.pow
import kotlin.math.sqrt

class SensorService : Service(), SensorEventListener2 {

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var offBodySensor: Sensor? = null
    private var gyroscope: Sensor? = null
    private var stepCounter: Sensor? = null
    private var heartRateSensor: Sensor? = null

    // Últimos valores de sensores fisiológicos adjuntados a cada lote.
    private var lastGyroX = 0f
    private var lastGyroY = 0f
    private var lastGyroZ = 0f
    private var totalSteps = 0
    private var lastHeartRate = 0f
    private var lastHeartRateTime = 0L

    private var wakeLock: PowerManager.WakeLock? = null

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.IO + job)

    private val readingsBuffer = ArrayDeque<JSONObject>(50)
    private var lastBatchSendTime = 0L
    private val BATCH_INTERVAL_MS = 5_000L

    private var cachedNodeId: String? = null
    private var lastNodeRefreshTime = 0L
    private val NODE_CACHE_TTL_MS = 30_000L

    private var retryIntervalMs = 5_000L
    private val MAX_RETRY_INTERVAL_MS = 60_000L

    private var isOnBody = true // Default to true initially

    // Análisis de inactividad local en segundo plano (Wear OS background detection)
    private val magnitudes = ArrayList<Double>(200)
    private var windowStartTime = 0L
    private var idleWindows = 0L
    private var activeWindows = 0L
    private var consecutiveActiveWindows = 0
    private var alertShown = false
    private var restWindows = 0L
    private var sleepWindows = 0L
    private var reposoVerificado = false
    private val WINDOW_MS = 30_000L
    private val VARIANCE_THRESHOLD = 0.05 // Alineado con el teléfono (0.05)
    private var alertWindows = 90L // 90 ventanas de 30s = 45 min por defecto

    private fun loadAlertThreshold() {
        val prefs = getSharedPreferences("wear_settings", Context.MODE_PRIVATE)
        val minutes = prefs.getLong("alert_threshold_minutes", 45L)
        alertWindows = minutes * 2
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = Notification.Builder(this, "wear_sensor_channel")
            .setContentTitle("LifeBalance")
            .setContentText("Monitoreando actividad...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val fgsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            }
            startForeground(1, notification, fgsType)
        } else {
            startForeground(1, notification)
        }

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LifeBalance:SensorServiceWakeLock").apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L) // Timeout de 4 horas para evitar drenaje si crashea
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        
        // Register off-body sensor
        offBodySensor = sensorManager.getDefaultSensor(Sensor.TYPE_LOW_LATENCY_OFFBODY_DETECT)
        offBodySensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }

        // Register accelerometer with 5-second maxReportLatencyUs for hardware batching
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelerometer?.let {
            sensorManager.registerListener(
                this,
                it,
                SensorManager.SENSOR_DELAY_GAME,
                5_000_000 // 5 seconds batching in microseconds
            )
        }

        // Giroscopio: orientación espacial del brazo/cuerpo (Filtro Clínico).
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        gyroscope?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }

        // Podómetro: contador acumulativo de pasos diarios.
        stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepCounter?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }

        // Frecuencia cardíaca (lpm). Requiere permiso BODY_SENSORS en runtime.
        heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        heartRateSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        wakeLock?.let {
            if (!it.isHeld) {
                it.acquire(4 * 60 * 60 * 1000L)
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d("SensorService", "Flushing sensors before destroy")
        sensorManager.flush(this)
        sensorManager.unregisterListener(this)
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        job.cancel()
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return

        when (event.sensor.type) {
            Sensor.TYPE_LOW_LATENCY_OFFBODY_DETECT -> {
                isOnBody = event.values[0] == 1.0f
                WearSensorState.isOnBody = isOnBody
                if (!isOnBody) {
                    Log.d("SensorService", "Watch is off-body. Pausing collection.")
                    // Flush immediately when taken off body
                    flushBuffer()
                } else {
                    Log.d("SensorService", "Watch is on-body. Resuming collection.")
                }
            }
            Sensor.TYPE_GYROSCOPE -> {
                lastGyroX = event.values[0]
                lastGyroY = event.values[1]
                lastGyroZ = event.values[2]
            }
            Sensor.TYPE_STEP_COUNTER -> {
                totalSteps = TodaySteps.of(this, event.values[0].toInt())
                WearSensorState.steps = totalSteps
                Log.d("SensorService", "Step counter event: totalSteps=$totalSteps (raw=${event.values[0]})")
            }
            Sensor.TYPE_HEART_RATE -> {
                // values[0] en lpm; 0 cuando no hay contacto/toma fiable.
                val hr = event.values[0]
                if (hr > 0) {
                    lastHeartRate = hr
                    lastHeartRateTime = System.currentTimeMillis()
                    WearSensorState.heartRate = hr
                    Log.d("SensorService", "Heart rate event: $lastHeartRate bpm")
                }
            }
            Sensor.TYPE_ACCELEROMETER -> {
                if (!isOnBody) return // Don't collect if not on wrist

                val x = event.values[0].toDouble()
                val y = event.values[1].toDouble()
                val z = event.values[2].toDouble()
                val mag = sqrt(x * x + y * y + z * z)
                
                val now = System.currentTimeMillis()
                if (mag.isFinite()) {
                    if (windowStartTime == 0L) windowStartTime = now
                    magnitudes.add(mag)
                    if (now - windowStartTime >= WINDOW_MS) {
                        analyzeWindowLocal(now)
                    }
                }

                // Caducidad de frecuencia cardíaca: si pasaron > 15s sin lectura fresca, enviar 0f
                val finalHR = if (now - lastHeartRateTime < 15_000L) lastHeartRate else 0f

                val reading = JSONObject().apply {
                    put("x", event.values[0])
                    put("y", event.values[1])
                    put("z", event.values[2])
                    put("gyroX", lastGyroX)
                    put("gyroY", lastGyroY)
                    put("gyroZ", lastGyroZ)
                    put("steps", totalSteps)
                    put("heartRate", finalHR)
                    put("isOnBody", isOnBody)
                    put("timestamp", now)
                }

                readingsBuffer.add(reading)

                if (now - lastBatchSendTime >= BATCH_INTERVAL_MS) {
                    lastBatchSendTime = now
                    flushBuffer()
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onFlushCompleted(sensor: Sensor?) {
        Log.d("SensorService", "onFlushCompleted called for sensor: ${sensor?.name}")
        flushBuffer()
    }

    private fun flushBuffer() {
        if (readingsBuffer.isEmpty()) return

        val batch = JSONArray()
        while (readingsBuffer.isNotEmpty()) {
            batch.put(readingsBuffer.removeFirst())
        }

        scope.launch {
            sendBatch(batch.toString())
        }
    }

    private suspend fun getCachedNode(): String? {
        val now = System.currentTimeMillis()
        if (cachedNodeId == null || now - lastNodeRefreshTime > NODE_CACHE_TTL_MS) {
            try {
                cachedNodeId = Wearable.getNodeClient(this@SensorService)
                    .connectedNodes.await()
                    .firstOrNull { it.isNearby }?.id
                lastNodeRefreshTime = now
                Log.d("SensorService", "Node cache refreshed: $cachedNodeId")
            } catch (e: Exception) {
                Log.e("SensorService", "Failed to refresh nodes", e)
            }
        }
        return cachedNodeId
    }

    private suspend fun sendBatch(data: String) {
        val nodeId = getCachedNode()
        
        if (nodeId == null) {
            Log.w("SensorService", "No nearby node found. Will retry later.")
            onSendFailed()
            return
        }

        try {
            Wearable.getMessageClient(this@SensorService).sendMessage(
                nodeId,
                "/lifebalance/sensors",
                data.toByteArray()
            ).await()
            onSendSucceeded()
            Log.d("SensorService", "Batch sent successfully to $nodeId")
        } catch (e: Exception) {
            Log.e("SensorService", "Error sending batch", e)
            onSendFailed()
        }
    }

    private fun onSendFailed() {
        cachedNodeId = null // Invalidate cache to force a refresh next time
        retryIntervalMs = minOf(retryIntervalMs * 2, MAX_RETRY_INTERVAL_MS)
        // In a more complex implementation, we might requeue the data here, 
        // but for now we drop it to avoid memory bounds issues.
    }

    private fun onSendSucceeded() {
        retryIntervalMs = 5_000L // Reset backoff
    }

    private fun analyzeWindowLocal(now: Long) {
        if (magnitudes.isEmpty()) return
        val mean = magnitudes.sum() / magnitudes.size
        val variance = magnitudes.map { (it - mean).pow(2) }.sum() / magnitudes.size
        magnitudes.clear()
        windowStartTime = now

        // 1. Protección Off-Body (reloj quitado de la muñeca o reposando sobre una mesa):
        val isOffBodyTable = (variance < 0.0001) && (lastHeartRate <= 0f)
        if (!isOnBody || isOffBodyTable) {
            // Reloj fuera del cuerpo: congelar temporizadores (no suma inactividad ni declara caminata activa)
            Log.d("SensorService", "Watch off-body or resting on table. Detection frozen.")
            consecutiveActiveWindows = 0
            return
        }

        val immobile = variance < VARIANCE_THRESHOLD

        if (immobile) {
            consecutiveActiveWindows = 0

            // 2. Filtro Clínico de Falsos Positivos:
            val hrKnown = lastHeartRate > 0f
            val hr = lastHeartRate

            // Heurística de orientación por giroscopio: recostado si hay inclinación espacial dominada por X/Y
            val isReclined = (abs(lastGyroX) > 0.5f || abs(lastGyroY) > 0.5f)

            // Sueño / Siesta: FC < 60 lpm + recostado durante >= 20 min (40 ventanas de 30s)
            if (hrKnown && hr < 60f && isReclined) {
                sleepWindows++
                restWindows = 0L
                reposoVerificado = false
                Log.d("SensorService", "Clinical Filter: Sleep state active ($sleepWindows windows). Alert paused.")
                return
            }

            // Reposo Clínico Verificado (Descanso Legítimo): FC estrictamente 60-100 lpm en steady-state
            if (hrKnown && hr >= 60f && hr <= 100f) {
                sleepWindows = 0L
                restWindows++
                val requiredWindows = if (isReclined) 40L else 10L // 20 min recostado (40w), 5 min sentado (10w)
                if (restWindows >= requiredWindows) {
                    reposoVerificado = true
                    Log.d("SensorService", "Clinical Filter: Clinical Rest Verified ($restWindows windows). Alert paused.")
                    return
                }
            } else {
                restWindows = 0L
                sleepWindows = 0L
                reposoVerificado = false
            }

            // Trabajo Sedentario (Vigilia): Inmóvil sin reposo verificado -> SÍ suma inactividad para la alerta
            idleWindows++

        } else {
            // Movimiento detectado:
            consecutiveActiveWindows++
            if (consecutiveActiveWindows >= 2) {
                // Movimiento activo sostenido (caminata real >= 1 min)
                idleWindows = 0L
                activeWindows++
                restWindows = 0L
                sleepWindows = 0L
                reposoVerificado = false
                alertShown = false
            }
            // Si consecutiveActiveWindows == 1, es un gesto de brazo aislado; se ignora sin borrar el estado previo
        }

        loadAlertThreshold()
        if (idleWindows >= alertWindows && !alertShown) {
            alertShown = true
            triggerWearAlert()
        }

        WearSensorState.variance = variance
        WearSensorState.idleWindows = idleWindows
        WearSensorState.activeWindows = activeWindows
        WearSensorState.alertWindows = alertWindows
        WearSensorState.alertShown = alertShown
        
        Log.d("SensorService", "SensorService alive, idle=$idleWindows/$alertWindows, active=$activeWindows, var=$variance")
    }

    private fun triggerWearAlert() {
        val minutes = idleWindows / 2
        Log.w("SensorService", "¡Alerta de sedentarismo en Wear OS! $minutes min inactivo.")
        
        // Vibración háptica en el reloj
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 500, 200, 500, 200, 500), -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
        }

        // Notificación nativa de Wear OS de alta prioridad
        val manager = getSystemService(NotificationManager::class.java)
        val alertNotification = Notification.Builder(this, "wear_alert_channel")
            .setContentTitle("¡Hora de moverse!")
            .setContentText("Llevas $minutes min inactivo. ¡Tómate una pausa activa!")
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setAutoCancel(true)
            .build()
        manager.notify(999, alertNotification)
    }

    private fun createNotificationChannel() {
        val manager = getSystemService(NotificationManager::class.java)

        val channel = NotificationChannel(
            "wear_sensor_channel",
            "Sensor Service",
            NotificationManager.IMPORTANCE_LOW
        )
        manager.createNotificationChannel(channel)

        val alertChannel = NotificationChannel(
            "wear_alert_channel",
            "Inactivity Alerts",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alertas de sedentarismo en el reloj"
            enableVibration(true)
        }
        manager.createNotificationChannel(alertChannel)
    }
}
