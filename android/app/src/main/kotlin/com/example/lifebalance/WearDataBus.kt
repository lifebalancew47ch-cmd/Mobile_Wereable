package com.example.lifebalance

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object WearDataBus {
    private var eventSink: EventChannel.EventSink? = null
    private var lastEmitTime = 0L
    private const val EMIT_THROTTLE_MS = 5_000L  // Maximo 1 update a la UI cada 5 segundos
    
    // Guardamos el último dato recibido para procesamientos en background si es necesario
    var pendingData: String? = null
        private set

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun emit(data: String) {
        pendingData = data

        val now = System.currentTimeMillis()
        if (now - lastEmitTime >= EMIT_THROTTLE_MS) {
            lastEmitTime = now
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(data)
            }
        }
    }
}
