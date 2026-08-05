package com.example.lifebalance

import android.os.Bundle
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val WEARABLE_EVENT_CHANNEL = "com.example.lifebalance/wearable_sensors"
    private val WEARABLE_SETTINGS_CHANNEL = "com.example.lifebalance/wearable_settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WEARABLE_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    WearDataBus.setEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    WearDataBus.setEventSink(null)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEARABLE_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncAlertInterval" -> {
                        val minutes = (call.argument<Number>("minutes"))?.toLong() ?: 45L
                        syncAlertInterval(minutes)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Escribe el umbral en el DataClient de Wear OS bajo la ruta
     * "/lifebalance/settings". No necesita buscar nodos manualmente:
     * Play Services distribuye el DataItem a todos los nodos conectados y lo
     * sincroniza al reconectarse (entrega garantizada eventual).
     */
    private fun syncAlertInterval(minutes: Long) {
        val request = PutDataMapRequest.create("/lifebalance/settings").apply {
            dataMap.putLong("alert_threshold_minutes", minutes)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(this).putDataItem(request)
    }
}
