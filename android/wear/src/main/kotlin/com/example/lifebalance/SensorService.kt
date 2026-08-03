package com.example.lifebalance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener2
import android.hardware.SensorManager
import android.os.IBinder
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

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = Notification.Builder(this, "wear_sensor_channel")
            .setContentTitle("LifeBalance")
            .setContentText("Monitoreando actividad...")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .build()
        startForeground(1, notification)

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
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d("SensorService", "Flushing sensors before destroy")
        sensorManager.flush(this)
        sensorManager.unregisterListener(this)
        job.cancel()
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return

        when (event.sensor.type) {
            Sensor.TYPE_LOW_LATENCY_OFFBODY_DETECT -> {
                isOnBody = event.values[0] == 1.0f
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
                totalSteps = event.values[0].toInt()
            }
            Sensor.TYPE_HEART_RATE -> {
                // values[0] en lpm; 0 cuando no hay contacto/toma fiable.
                lastHeartRate = event.values[0]
            }
            Sensor.TYPE_ACCELEROMETER -> {
                if (!isOnBody) return // Don't collect if not on wrist

                val timestamp = System.currentTimeMillis() // Or use event.timestamp for better accuracy relative to boot
                val reading = JSONObject().apply {
                    put("x", event.values[0])
                    put("y", event.values[1])
                    put("z", event.values[2])
                    put("gyroX", lastGyroX)
                    put("gyroY", lastGyroY)
                    put("gyroZ", lastGyroZ)
                    put("steps", totalSteps)
                    put("heartRate", lastHeartRate)
                    put("timestamp", timestamp)
                }

                readingsBuffer.add(reading)

                val now = System.currentTimeMillis()
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

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "wear_sensor_channel",
            "Sensor Service",
            NotificationManager.IMPORTANCE_LOW
        )
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}
