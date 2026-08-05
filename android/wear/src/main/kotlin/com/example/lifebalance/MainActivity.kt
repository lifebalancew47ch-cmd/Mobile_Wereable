package com.example.lifebalance

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Dashboard nativo del wearable: muestra el estado de actividad, 
 * minutos inactivos y alertas leyendo los datos procesados por el
 * SensorService en background, evitando registrar sus propios listeners
 * para no interferir con el ciclo de vida de los sensores del sistema.
 */
class MainActivity : Activity() {

    private lateinit var statusText: TextView
    private lateinit var minutesText: TextView
    private lateinit var varianceText: TextView
    private lateinit var stepsText: TextView
    private lateinit var bpmText: TextView

    private var uiUpdateJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        minutesText = findViewById(R.id.minutesText)
        varianceText = findViewById(R.id.varianceText)
        stepsText = findViewById(R.id.stepsText)
        bpmText = findViewById(R.id.bpmText)

        findViewById<Button>(R.id.pauseButton).setOnClickListener {
            // Reinicia el estado compartido al pausar (pausa activa)
            WearSensorState.idleWindows = 0
            WearSensorState.activeWindows = 0
            WearSensorState.alertShown = false
            updateUi()
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
            requestBackgroundSensorPermissionIfNeeded()
            startSensorService()
        }
    }

    private fun requestBackgroundSensorPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.BODY_SENSORS_BACKGROUND) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.BODY_SENSORS_BACKGROUND), 101)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 100) {
            requestBackgroundSensorPermissionIfNeeded()
            startSensorService()
        } else if (requestCode == 101) {
            startSensorService()
        }
    }

    private fun startSensorService() {
        startForegroundService(Intent(this, SensorService::class.java))
    }

    private fun startUiUpdates() {
        uiUpdateJob?.cancel()
        uiUpdateJob = scope.launch {
            while (isActive) {
                updateUi()
                delay(1000L) // Actualizar UI cada segundo
            }
        }
    }

    private fun stopUiUpdates() {
        uiUpdateJob?.cancel()
        uiUpdateJob = null
    }

    override fun onResume() {
        super.onResume()
        startUiUpdates()
    }

    override fun onPause() {
        stopUiUpdates()
        super.onPause()
    }

    private fun updateUi() {
        stepsText.text = WearSensorState.steps.toString()
        bpmText.text = WearSensorState.heartRate.toInt().toString()
        varianceText.text = "varianza: %.4f".format(WearSensorState.variance)

        val idleWindows = WearSensorState.idleWindows
        val alertWindows = WearSensorState.alertWindows
        val activeWindows = WearSensorState.activeWindows

        if (idleWindows >= alertWindows) {
            val minutes = idleWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "¡Alerta de sedentarismo!"
            statusText.setTextColor(android.graphics.Color.parseColor("#E0564C"))
        } else if (idleWindows > 0) {
            val minutes = idleWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "Inactivo"
            statusText.setTextColor(android.graphics.Color.parseColor("#E8A24C"))
        } else {
            val minutes = activeWindows / 2
            minutesText.text = "$minutes min"
            statusText.text = "Activo"
            statusText.setTextColor(android.graphics.Color.parseColor("#52C480"))
        }
    }
}