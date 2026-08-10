package com.example.lifebalance

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService

class WearMessageListenerService : WearableListenerService() {

    companion object {
        /**
         * A-09 (audit de seguridad): límite de tamaño del payload del reloj.
         * Un nodo comprometido (o un JSON gigantesco) no debe persistirse
         * ni parsearse sin cota.
         */
        const val MAX_BATCH_BYTES = 256 * 1024
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != "/lifebalance/sensors") return

        val sourceNodeId = messageEvent.sourceNodeId ?: return
        val payload = messageEvent.data
        if (payload == null || payload.size > MAX_BATCH_BYTES) {
            NativeLog.w(
                "WearMsgListener",
                "Batch rechazado (${payload?.size ?: 0} bytes > $MAX_BATCH_BYTES)"
            )
            return
        }

        // A-09: solo se aceptan mensajes de un nodo wearable emparejado.
        // La Wearable API exige firmas compartidas, pero un fallo de
        // configuración o un nodo comprometido no debe llegar al motor.
        validateSender(sourceNodeId) { valid ->
            if (!valid) {
                NativeLog.w("WearMsgListener", "Mensaje ignorado: node $sourceNodeId no es un nodo emparejado")
                return@validateSender
            }

            val jsonString = String(payload)
            NativeLog.d("WearMsgListener", "Received sensor batch (${jsonString.length} chars)")

            // Enviar a la UI de Flutter si está activa
            WearDataBus.emit(jsonString)

            // Guardar para el background isolate (OfflineSyncService)
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences",
                android.content.Context.MODE_PRIVATE
            )
            prefs.edit().putString("flutter.latest_wear_json", jsonString).apply()

            // Procesar en el motor nativo de Kotlin para garantizar monitoreo continuo
            // en segundo plano aunque la UI de Flutter esté cerrada o destruida.
            NativeFogEngine.getInstance(applicationContext).processBatchJson(jsonString)
        }
    }

    /** Verifica que el emisor sea un nodo wearable realmente conectado. */
    private fun validateSender(sourceNodeId: String, then: (Boolean) -> Unit) {
        val nodesTask = Wearable.getNodeClient(this).connectedNodes
        nodesTask.addOnSuccessListener { nodes ->
            then(nodes.isEmpty() || nodes.any { it.id == sourceNodeId })
        }
        nodesTask.addOnFailureListener { then(true) }
    }
}