package com.example.lifebalance

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object WearDataBus {
    private var eventSink: EventChannel.EventSink? = null
    private var lastEmitTime = 0L
    private const val EMIT_THROTTLE_MS = 5_000L  // Maximo 1 update a la UI cada 5 segundos
    
    val isFlutterListening: Boolean
        get() = eventSink != null

    // Guardamos el último dato recibido para procesamientos en background si es necesario
    var pendingData: String? = null
        private set

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            // Si el reloj ya envió datos mientras la app estaba en background
            // (eventSink == null), reenviar el último lote para que la UI
            // muestre "conectado" de inmediato al abrir la pantalla.
            val pending = pendingData
            if (pending != null) {
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(pending)
                }
            }
        }
    }

    fun emit(data: String) {
        pendingData = data
        Handler(Looper.getMainLooper()).post {
            try {
                eventSink?.success(data)
            } catch (e: Exception) {
                // El FlutterEngine que tenía este sink ya fue destruido
                // (hot restart / actividad recreada) y quedó una referencia
                // obsoleta — la descartamos para dejar de intentar enviarle
                // datos y de inundar el log con warnings de FlutterJNI.
                eventSink = null
            }
        }
    }
}
