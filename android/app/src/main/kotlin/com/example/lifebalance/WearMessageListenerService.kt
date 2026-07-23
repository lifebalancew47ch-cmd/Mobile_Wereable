package com.example.lifebalance

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {

    override fun onMessageReceived(messageEvent: MessageEvent) {
        // Ejecutamos lo menos posible aquí para soltar el wakelock rápidamente
        if (messageEvent.path == "/lifebalance/sensors") {
            val jsonString = String(messageEvent.data)
            Log.d("WearMsgListener", "Received sensor batch")
            WearDataBus.emit(jsonString)
        }
    }
}
