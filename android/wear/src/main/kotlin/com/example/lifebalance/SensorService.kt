package com.example.lifebalance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
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
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
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
    private var gravitySensor: Sensor? = null
    private var stepCounter: Sensor? = null
    private var heartRateSensor: Sensor? = null

    // Últimos valores de sensores fisiológicos adjuntados a cada lote.
    private var lastGyroX = 0f
    private var lastGyroY = 0f
    private var lastGyroZ = 0f
    private var lastGravityX = 0f
    private var lastGravityY = 0f
    private var lastGravityZ = 9.8f
    private var totalSteps = 0
    private var stepsAtActiveStart = 0
    private var lastHeartRate = 0f
    private var lastHeartRateTime = 0L

    // Últimas 10 lecturas de FC válidas, usadas para el proxy de HRV.
    private val hrHistory = ArrayDeque<Float>(10)

    // NOTA: se intentó leer SpO2 real vía Health Services (MeasureClient), pero
    // androidx.health.services.client.data.DataType (1.1.0-rc02) NO expone un
    // DataType.OXYGEN_SATURATION — el MeasureClient de esta librería solo cubre
    // HR, velocidad, distancia, calorías, etc. No hay una API pública genérica de
    // Wear OS para SpO2 en tiempo real; se necesitaría el SDK propietario del
    // fabricante (p. ej. Samsung Health Sensor SDK) por dispositivo. Por ahora
    // spo2 se sigue enviando en 0 (sin dato fiable) — ver el fallback en
    // offline_sync_service.dart del lado Flutter.
    private var wakeLock: PowerManager.WakeLock? = null

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.IO + job)
    // Scope en hilo principal para el timer de análisis — comparte el mismo job
    // para que se cancele junto con el servicio.
    private val mainScope = CoroutineScope(Dispatchers.Main + job)

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
    private var idleWindows = 0L
    private var activeWindows = 0L
    private var consecutiveActiveWindows = 0
    private var alertShown = false
    private var restWindows = 0L
    private var sleepWindows = 0L
    private var reposoVerificado = false
    private val WINDOW_MS = 30_000L
    // Umbral para clasificar una ventana como "inmóvil".
    // El teléfono usaba 0.05, pero en muñeca el temblor fisiológico, el pulso y
    // los micro-movimientos de mano al estar sentado generan varianzas de 0.15-0.35.
    // Con 0.50 se distingue perfectamente entre estar sentado (var < 0.50) y
    // caminata/movimiento activo real (var > 1.0).
    private val VARIANCE_THRESHOLD = 0.50
    private var alertWindows = 90L // 90 ventanas de 30s = 45 min por defecto

    private fun loadAlertThreshold() {
        val prefs = getSharedPreferences("wear_settings", Context.MODE_PRIVATE)
        val minutes = prefs.getLong("alert_threshold_minutes", 45L)
        alertWindows = minutes * 2
    }

    private fun saveState() {
        getSharedPreferences("wear_state", Context.MODE_PRIVATE)
            .edit()
            .putLong("idle_windows", idleWindows)
            .putLong("active_windows", activeWindows)
            .putBoolean("alert_shown", alertShown)
            .apply()
    }

    private fun loadState() {
        val prefs = getSharedPreferences("wear_state", Context.MODE_PRIVATE)
        idleWindows = prefs.getLong("idle_windows", 0L)
        activeWindows = prefs.getLong("active_windows", 0L)
        alertShown = prefs.getBoolean("alert_shown", false)

        WearSensorState.idleWindows = idleWindows
        WearSensorState.activeWindows = activeWindows
        WearSensorState.alertShown = alertShown
    }

    override fun onCreate() {
        super.onCreate()
        loadAlertThreshold()
        loadState()
        createNotificationChannel()
        val notification = Notification.Builder(this, "wear_sensor_channel")
            .setContentTitle("LifeBalance")
            .setContentText("Monitoreando actividad...")
            .setSmallIcon(R.mipmap.ic_launcher)
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

        // Giroscopio: rotaciones espaciales del brazo/cuerpo.
        gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        gyroscope?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }

        // Gravímetro: vector de gravedad estático para detección de postura reclinada.
        gravitySensor = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        gravitySensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
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

        // Timer de análisis de ventana — hilo principal para compartir el acceso a
        // `magnitudes` con onSensorChanged (ambos en el main thread). Garantiza que
        // analyzeWindowLocal corra cada 30s aunque el acelerómetro esté en batching
        // agresivo o el reloj entre en reposo entre entregas de sensor.
        mainScope.launch {
            delay(WINDOW_MS) // esperar la primera ventana completa
            while (true) {
                val now = System.currentTimeMillis()
                WearLog.d("SensorService", "Timer tick: magnitudes=${magnitudes.size} idle=$idleWindows active=$activeWindows")
                if (magnitudes.isNotEmpty()) {
                    analyzeWindowLocal(now)
                } else {
                    // Sin datos de acelerómetro en esta ventana: reportar estado actual
                    // sin modificar idleWindows ni activeWindows (sensor off o servicio arrancando)
                    WearLog.w("SensorService", "Timer: no hay muestras de acelerómetro en ${WINDOW_MS}ms")
                    WearSensorState.windowsAnalyzed++
                }
                delay(WINDOW_MS)
            }
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
        WearLog.d("SensorService", "Flushing sensors before destroy")
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
                isOnBody = event.values[0] != 0.0f
                WearSensorState.isOnBody = isOnBody
                if (!isOnBody) {
                    WearLog.d("SensorService", "Watch is off-body. Pausing collection.")
                    // Flush immediately when taken off body
                    flushBuffer()
                } else {
                    WearLog.d("SensorService", "Watch is on-body. Resuming collection.")
                }
            }
            Sensor.TYPE_GYROSCOPE -> {
                lastGyroX = event.values[0]
                lastGyroY = event.values[1]
                lastGyroZ = event.values[2]
                WearSensorState.gyroX = lastGyroX
                WearSensorState.gyroY = lastGyroY
                WearSensorState.gyroZ = lastGyroZ
            }
            Sensor.TYPE_GRAVITY -> {
                lastGravityX = event.values[0]
                lastGravityY = event.values[1]
                lastGravityZ = event.values[2]
            }
            Sensor.TYPE_STEP_COUNTER -> {
                totalSteps = TodaySteps.of(this, event.values[0].toInt())
                WearSensorState.steps = totalSteps
                WearLog.d("SensorService", "Step counter event: totalSteps=$totalSteps (raw=${event.values[0]})")
            }
            Sensor.TYPE_HEART_RATE -> {
                // values[0] en lpm; 0 cuando no hay contacto/toma fiable.
                val hr = event.values[0]
                if (hr > 0) {
                    lastHeartRate = hr
                    lastHeartRateTime = System.currentTimeMillis()
                    WearSensorState.heartRate = hr
                    hrHistory.addLast(hr)
                    if (hrHistory.size > 10) hrHistory.removeFirst()
                    WearLog.d("SensorService", "Heart rate event: $lastHeartRate bpm")
                }
            }
            Sensor.TYPE_ACCELEROMETER -> {
                if (!isOnBody) return // Don't collect if not on wrist

                val x = event.values[0].toDouble()
                val y = event.values[1].toDouble()
                val z = event.values[2].toDouble()

                // Actualizar filtro pasa-bajas para componente de gravedad
                lastGravityX = 0.8f * lastGravityX + 0.2f * event.values[0]
                lastGravityY = 0.8f * lastGravityY + 0.2f * event.values[1]
                lastGravityZ = 0.8f * lastGravityZ + 0.2f * event.values[2]
                val mag = sqrt(x * x + y * y + z * z)
                
                val now = System.currentTimeMillis()
                if (mag.isFinite()) {
                    magnitudes.add(mag)
                }

                // Caducidad de frecuencia cardíaca: si pasaron > 10 min sin lectura fresca, enviar 0f
                val finalHR = if (now - lastHeartRateTime < 600_000L) lastHeartRate else 0f
                val hrvProxy = computeHrvProxyMs()

                val reading = JSONObject().apply {
                    put("x", event.values[0])
                    put("y", event.values[1])
                    put("z", event.values[2])
                    put("gyroX", lastGyroX)
                    put("gyroY", lastGyroY)
                    put("gyroZ", lastGyroZ)
                    put("steps", totalSteps)
                    put("heartRate", finalHR)
                    put("hrv", hrvProxy)
                    // SpO2 sin sensor disponible vía API pública de Wear OS (ver nota arriba).
                    put("spo2", 0f)
                    put("isOnBody", isOnBody)
                    put("timestamp", now)
                }

                readingsBuffer.add(reading)

                // Actualizar varianza en tiempo real para debug en pantalla.
                if (magnitudes.size > 1) {
                    val mean = magnitudes.sum() / magnitudes.size
                    WearSensorState.liveVariance = magnitudes.map { (it - mean).pow(2) }.sum() / magnitudes.size
                }

                if (now - lastBatchSendTime >= BATCH_INTERVAL_MS) {
                    lastBatchSendTime = now
                    flushBuffer()
                }
            }
        }
    }

    /**
     * Proxy de HRV a partir de la dispersión de las últimas lecturas de FC.
     *
     * IMPORTANTE: esto NO es rMSSD clínico. El rMSSD real requiere intervalos
     * R-R latido a latido desde ECG o PPG crudo, que el SensorManager estándar
     * de Android no expone (solo entrega FC ya promediada). Aquí convertimos
     * cada muestra de FC (lpm) a un intervalo equivalente en ms y calculamos
     * la raíz de la media de las diferencias sucesivas al cuadrado sobre esa
     * serie, como indicador relativo de variabilidad — no diagnóstico.
     */
    private fun computeHrvProxyMs(): Float {
        if (hrHistory.size < 3) return 0f
        val rr = hrHistory.map { 60000f / it }
        var sumSqDiff = 0.0
        for (i in 1 until rr.size) {
            val diff = (rr[i] - rr[i - 1]).toDouble()
            sumSqDiff += diff * diff
        }
        val rmssdProxy = sqrt(sumSqDiff / (rr.size - 1))
        WearSensorState.hrv = rmssdProxy.toFloat()
        return rmssdProxy.toFloat()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onFlushCompleted(sensor: Sensor?) {
        WearLog.d("SensorService", "onFlushCompleted called for sensor: ${sensor?.name}")
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
                WearLog.d("SensorService", "Node cache refreshed: $cachedNodeId")
            } catch (e: Exception) {
                WearLog.e("SensorService", "Failed to refresh nodes", e)
            }
        }
        return cachedNodeId
    }

    private suspend fun sendBatch(data: String) {
        val nodeId = getCachedNode()
        
        if (nodeId == null) {
            WearLog.w("SensorService", "No nearby node found. Will retry later.")
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
            WearLog.d("SensorService", "Batch sent successfully to $nodeId")
        } catch (e: Exception) {
            WearLog.e("SensorService", "Error sending batch", e)
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
        if (WearSensorState.resetRequested) {
            WearSensorState.resetRequested = false
            idleWindows = 0L
            activeWindows = 0L
            restWindows = 0L
            sleepWindows = 0L
            consecutiveActiveWindows = 0
            alertShown = false
        }

        if (magnitudes.isEmpty()) return
        val mean = magnitudes.sum() / magnitudes.size
        val variance = magnitudes.map { (it - mean).pow(2) }.sum() / magnitudes.size
        magnitudes.clear()

        WearSensorState.windowsAnalyzed++
        WearLog.d("SensorService", "analyzeWindow #${WearSensorState.windowsAnalyzed}: var=%.5f hr=%.1f isOnBody=$isOnBody idle=$idleWindows active=$activeWindows restW=$restWindows".format(variance, lastHeartRate))

        // 1. Protección Off-Body: solo confiar en el sensor TYPE_LOW_LATENCY_OFFBODY_DETECT.
        // Antes se usaba "isOffBodyTable = variance < 0.0001 && lastHeartRate <= 0f" pero
        // causaba falsos positivos: lastHeartRate empieza en 0f durante los primeros 30-90s
        // (o si el sensor HR no está disponible), haciendo que la primera ventana de quietud
        // siempre devolviera early y el estado nunca cambiara de "Activo".
        if (!isOnBody) {
            WearLog.d("SensorService", "Watch off-body (sensor). Detection frozen.")
            consecutiveActiveWindows = 0

            WearSensorState.variance = variance
            WearSensorState.idleWindows = idleWindows
            WearSensorState.activeWindows = activeWindows
            WearSensorState.alertWindows = alertWindows
            WearSensorState.alertShown = alertShown
            return
        }

        val immobile = variance < VARIANCE_THRESHOLD

        if (immobile) {
            consecutiveActiveWindows = 0
            stepsAtActiveStart = totalSteps

            // 2. Filtro Clínico de Falsos Positivos:
            val hrKnown = lastHeartRate > 0f
            val hr = lastHeartRate

            // Heurística de orientación por vector de gravedad: recostado si la componente Z
            // del vector de gravedad es pequeña (< 6 m/s²).
            // NOTA: Se eliminó el componente de giroscopio (lastGyroX/Y/Z) porque captura el
            // ÚLTIMO sample del sensor, el cual casi siempre supera 0.5 rad/s en uso normal
            // del reloj, haciendo que isReclined fuera true casi siempre y que el filtro de
            // reposo clínico exigiera 40 ventanas (20 min) en lugar de 10 (5 min).
            val isReclined = abs(lastGravityZ) < 6.0f

            // Sueño / Siesta: FC < 60 lpm + recostado durante >= 20 min (40 ventanas de 30s)
            if (hrKnown && hr < 60f && isReclined) {
                sleepWindows++
                restWindows = 0L
                reposoVerificado = false
                WearLog.d("SensorService", "Clinical Filter: Sleep (hr=%.1f reclined=$isReclined) sleepW=$sleepWindows. Alert paused.".format(hr))
                
                WearSensorState.variance = variance
                WearSensorState.idleWindows = idleWindows
                WearSensorState.activeWindows = activeWindows
                WearSensorState.alertWindows = alertWindows
                WearSensorState.alertShown = alertShown
                return
            }

            // Reposo Clínico Verificado (Siesta/Descanso): solo se activa estando RECOSTADO (isReclined = true)
            // con FC en reposo (60-100 lpm) sostenida durante >= 20 min (40 ventanas).
            // Estar sentado erguido trabajando NO congela el temporizador de sedentarismo.
            if (hrKnown && hr >= 60f && hr <= 100f && isReclined) {
                sleepWindows = 0L
                restWindows++
                if (restWindows >= 40L) { // 20 min recostado
                    reposoVerificado = true
                    WearLog.d("SensorService", "Clinical Filter: Rest Verified (hr=%.1f reclined=true restW=$restWindows). Alert paused.".format(hr))
                    
                    WearSensorState.variance = variance
                    WearSensorState.idleWindows = idleWindows
                    WearSensorState.activeWindows = activeWindows
                    WearSensorState.alertWindows = alertWindows
                    WearSensorState.alertShown = alertShown
                    return
                }
            } else {
                restWindows = 0L
                sleepWindows = 0L
                reposoVerificado = false
            }

            // Trabajo Sedentario (Vigilia): Inmóvil sin reposo verificado -> SÍ suma inactividad para la alerta
            idleWindows++
            WearLog.d("SensorService", "Sedentary window: idleWindows=$idleWindows/$alertWindows (hr=${if (hrKnown) "%.1f".format(hr) else "N/A"} reclined=$isReclined)")

        } else {
            // Movimiento detectado:
            if (consecutiveActiveWindows == 0) {
                stepsAtActiveStart = totalSteps
            }
            consecutiveActiveWindows++
            activeWindows++
            val stepsDelta = totalSteps - stepsAtActiveStart
            WearLog.d("SensorService", "Movement window #$consecutiveActiveWindows: stepsDelta=$stepsDelta var=%.4f idle=$idleWindows".format(variance))
            
            // Validación de Actividad Real Sostenida (al menos 2 minutos continuos = 4 ventanas de 30s):
            // Para evitar que manotazos o gesticulaciones al estar sentado reseteen el contador inactivo:
            // Exige 4 ventanas consecutivas (2 min) Y validación multi-sensor (pasos reales en podómetro > 0 O varianza sostenida muy alta >= 1.2).
            if (consecutiveActiveWindows >= 4) {
                if (stepsDelta > 0 || variance >= 1.2) {
                    idleWindows = 0L
                    restWindows = 0L
                    sleepWindows = 0L
                    reposoVerificado = false
                    alertShown = false
                    WearLog.d("SensorService", "Actividad REAL Sostenida (2 min / 4 ventanas, stepsDelta=$stepsDelta). idleWindows reseteado a 0!")
                } else {
                    WearLog.w("SensorService", "Gesticulación de brazos sentado (0 pasos en 2 min). idleWindows NO reseteado ($idleWindows).")
                }
            }
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
        saveState()
        
        WearLog.d("SensorService", "SensorService alive, idle=$idleWindows/$alertWindows, active=$activeWindows, var=$variance")
    }

    private fun triggerWearAlert() {
        val minutes = idleWindows / 2
        WearLog.w("SensorService", "¡Alerta de sedentarismo en Wear OS! $minutes min inactivo.")
        
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
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .build()
        // Check permission before posting notification
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                manager.notify(999, alertNotification)
            }
        } else {
            manager.notify(999, alertNotification)
        }
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
