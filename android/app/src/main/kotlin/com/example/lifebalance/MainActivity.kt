package com.example.lifebalance

import android.os.Bundle
import android.view.WindowManager
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (no FlutterActivity): el plugin local_auth exige
// que la Activity anfitriona sea una FragmentActivity para poder mostrar el
// BiometricPrompt nativo (huella/rostro/PIN). Con FlutterActivity plano,
// authenticate() fallaba de inmediato con PlatformException(no_fragment_activity)
// sin llegar a pintar el diálogo del sistema, dejando al usuario sin forma de
// pasar la pantalla de bloqueo tras activarlo en Ajustes.
class MainActivity : FlutterFragmentActivity(), MessageClient.OnMessageReceivedListener {

    private val WEARABLE_EVENT_CHANNEL = "com.example.lifebalance/wearable_sensors"
    private val WEARABLE_SETTINGS_CHANNEL = "com.example.lifebalance/wearable_settings"
    private val NATIVE_FOG_CHANNEL = "com.example.lifebalance/native_fog_sync"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        Wearable.getMessageClient(this).addListener(this)
    }

    override fun onDestroy() {
        Wearable.getMessageClient(this).removeListener(this)
        super.onDestroy()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != "/lifebalance/sensors") return
        val payload = messageEvent.data ?: return
        if (payload.size > 256 * 1024) return

        val jsonString = String(payload)
        NativeLog.d("MainActivity", "Direct received sensor batch (${jsonString.length} chars)")

        WearDataBus.emit(jsonString)

        val prefs = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            MODE_PRIVATE
        )
        val encryptedJson = WearDataEncryptor.encrypt(jsonString)
        prefs.edit().putString("flutter.latest_wear_json", encryptedJson).apply()

        NativeFogEngine.getInstance(applicationContext).processBatchJson(jsonString)
    }

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_FOG_CHANNEL)
            .setMethodCallHandler { call, result ->
                val engine = NativeFogEngine.getInstance(applicationContext)
                when (call.method) {
                    "getIdleWindows" -> {
                        result.success(engine.readIdleWindows())
                    }
                    "getAlertShown" -> {
                        result.success(engine.readAlertShown())
                    }
                    "resetIdleWindows" -> {
                        engine.resetIdleWindows()
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

    // Se llama cuando este FlutterEngine se destruye (hot restart, actividad
    // recreada, etc). Sin esto, WearDataBus podía quedarse con un EventSink
    // apuntando a un engine ya muerto y seguir intentando emitir hacia él.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        WearDataBus.setEventSink(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
