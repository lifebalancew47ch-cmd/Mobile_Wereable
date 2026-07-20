package com.example.lifebalance

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class SensorService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private val scope = CoroutineScope(Dispatchers.IO)
    private var lastSendTime = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = Notification.Builder(this, "wear_sensor_channel")
            .setContentTitle("LifeBalance")
            .setContentText("Enviando datos al celular")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .build()
        startForeground(1, notification)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_ACCELEROMETER) {
            val currentTime = System.currentTimeMillis()
            // Send data max 2 times per second to save battery & bandwidth (500ms limit)
            if (currentTime - lastSendTime > 500) {
                lastSendTime = currentTime
                
                val x = event.values[0]
                val y = event.values[1]
                val z = event.values[2]
                
                val payload = JSONObject()
                payload.put("x", x)
                payload.put("y", y)
                payload.put("z", z)
                payload.put("timestamp", currentTime)

                sendDataToMobile(payload.toString())
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun sendDataToMobile(data: String) {
        scope.launch {
            try {
                val nodes = Wearable.getNodeClient(this@SensorService).connectedNodes.await()
                // Validar que el nodo conectado es el dispositivo pareado legítimo y cercano
                val trustedNode = nodes.firstOrNull { it.isNearby }
                trustedNode?.let { node ->
                    Wearable.getMessageClient(this@SensorService).sendMessage(
                        node.id,
                        "/lifebalance/sensors",
                        data.toByteArray()
                    ).await()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
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
