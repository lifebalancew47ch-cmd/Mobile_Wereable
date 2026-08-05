package com.example.lifebalance

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == "/lifebalance/sensors") {
            val jsonString = String(messageEvent.data)
            Log.d("WearMsgListener", "Received sensor batch (${jsonString.length} chars)")
            
            // Enviar a la UI de Flutter si está activa
            WearDataBus.emit(jsonString)

            // Procesar en el motor nativo de Kotlin para garantizar monitoreo continuo
            // en segundo plano aunque la UI de Flutter esté cerrada o destruida.
            NativeFogEngine.getInstance(applicationContext).processBatchJson(jsonString)
        }
    }
}
