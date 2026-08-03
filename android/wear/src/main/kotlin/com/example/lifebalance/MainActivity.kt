package com.example.lifebalance

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Dashboard nativo del wearable: analiza localmente la varianza del
 * acelerómetro en ventanas de 30s (misma lógica que el FogEngine del móvil)
 * y muestra el estado de actividad, minutos inactivos y alertas.
 */
class MainActivity : Activity(), SensorEventListener {

    companion object {
        private const val WINDOW_MS = 30_000L
        private const val VARIANCE_THRESHOLD = 0.8 // Aumentado para ignorar movimientos leves de brazo
        private const val DEFAULT_ALERT_WINDOWS = 90L // 90 ventanas x 30s = 45 min
    }

    private var alertWindows = DEFAULT_ALERT_WINDOWS // Se actualiza desde SharedPreferences

    private lateinit var statusText: TextView
    private lateinit var minutesText: TextView
    private lateinit var varianceText: TextView
    private lateinit var stepsText: TextView
    private lateinit var bpmText: TextView

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var stepCounter: Sensor? = null
    private var heartRateSensor: Sensor? = null

    private val magnitudes = ArrayList<Double>(200)
    private var windowStartTime = 0L
    private var idleWindows = 0L
    private var activeWindows = 0L
    private var alertShown = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        loadAlertThreshold()

        statusText = findViewById(R.id.statusText)
        minutesText = findViewById(R.id.minutesText)
        varianceText = findViewById(R.id.varianceText)
        stepsText = findViewById(R.id.stepsText)
        bpmText = findViewById(R.id.bpmText)

        findViewById<Button>(R.id.pauseButton).setOnClickListener {
            idleWindows = 0
            activeWindows = 0
            updateUi(0.0)
        }

        // Habilitar el scroll nativo con el bisel rotatorio de Samsung
        val scrollView = findViewById<android.view.View>(R.id.scrollView)
        scrollView.requestFocus()

        requestRequiredPermissions()
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf(Manifest.permission.BODY_SENSORS)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            permissions.add(Manifest.permission.ACTIVITY_RECOGNITION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.BODY_SENSORS_BACKGROUND)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
        }

        val missing = permissions.filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), 100)
        } else {
            startSensors()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) startSensors()
    }

    private fun startSensors() {
        sensorManager = getSystemService(SensorManager::class.java)
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        heartRateSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HEART_RATE)

        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            statusText.text = "Monitorizando..."
            startSensorService()
        } ?: run {
            statusText.text = "Sin acelerómetro disponible."
        }
        
        stepCounter?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        heartRateSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun startSensorService() {
        startForegroundService(Intent(this, SensorService::class.java))
    }

    /**
     * Lee el umbral de alerta (en minutos) persistido por
     * WearSettingsListenerService y lo traduce a ventanas de 30s.
     */
    private fun loadAlertThreshold() {
        val prefs = getSharedPreferences("wear_settings", Context.MODE_PRIVATE)
        val minutes = prefs.getLong("alert_threshold_minutes", 45L)
        alertWindows = minutes * 2 // 2 ventanas de 30s por minuto
        Log.d("MainActivity", "Alert threshold: $minutes min ($alertWindows windows)")
    }

    override fun onResume() {
        super.onResume()
        loadAlertThreshold() // NUEVO: captar cambios mientras la app estaba en background
        if (::sensorManager.isInitialized) {
            accelerometer?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
            }
            stepCounter?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
            heartRateSensor?.let {
                sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (::sensorManager.isInitialized) {
            sensorManager.unregisterListener(this)
        }
    }

    override fun onDestroy() {
        if (::sensorManager.isInitialized) {
            sensorManager.unregisterListener(this)
        }
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event ?: return
        
        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                stepsText.text = TodaySteps.of(this, event.values[0].toInt()).toString()
            }
            Sensor.TYPE_HEART_RATE -> {
                bpmText.text = event.values[0].toInt().toString()
            }
            Sensor.TYPE_ACCELEROMETER -> {
                val mag = sqrt(
                    event.values[0].toDouble().pow(2) +
                            event.values[1].toDouble().pow(2) +
                            event.values[2].toDouble().pow(2)
                )
                if (!mag.isFinite()) return

                val now = System.currentTimeMillis()
                if (windowStartTime == 0L) windowStartTime = now

                magnitudes.add(mag)
                if (now - windowStartTime >= WINDOW_MS) {
                    analyzeWindow(now)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun analyzeWindow(now: Long) {
        val variance = computeVariance()
        magnitudes.clear()
        windowStartTime = now

        if (variance < VARIANCE_THRESHOLD) {
            idleWindows++
            activeWindows = 0L
        } else {
            idleWindows = 0L
            activeWindows++
            alertShown = false
        }

        if (idleWindows >= alertWindows && !alertShown) {
            alertShown = true
        }
        updateUi(variance)
    }

    private fun computeVariance(): Double {
        if (magnitudes.isEmpty()) return 0.0
        val mean = magnitudes.sum() / magnitudes.size
        return magnitudes.map { (it - mean).pow(2) }.sum() / magnitudes.size
    }

    private fun updateUi(variance: Double) {
        if (idleWindows >= alertWindows) {
            val minutes = idleWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "¡Alerta de sedentarismo!"
            statusText.setTextColor(android.graphics.Color.parseColor("#FF3B30"))
        } else if (idleWindows > 0) {
            val minutes = idleWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "Inactivo"
            statusText.setTextColor(android.graphics.Color.parseColor("#FF9500"))
        } else {
            val minutes = activeWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "Activo"
            statusText.setTextColor(android.graphics.Color.parseColor("#00C2FF"))
        }
        varianceText.text = "varianza: %.4f".format(variance)
    }
}