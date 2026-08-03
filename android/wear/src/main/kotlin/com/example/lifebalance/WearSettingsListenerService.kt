package com.example.lifebalance

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Recibe los cambios de configuración de alertas enviados por el teléfono
 * vía DataClient (ruta "/lifebalance/settings") y los persiste en
 * SharedPreferences del reloj. El sistema Wear OS lo despierta
 * automáticamente incluso con la app cerrada.
 */
class WearSettingsListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED &&
                event.dataItem.uri.path == "/lifebalance/settings") {

                val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                val minutes = dataMap.getLong("alert_threshold_minutes", 45L)

                // Persistir en SharedPreferences del reloj
                getSharedPreferences("wear_settings", Context.MODE_PRIVATE)
                    .edit()
                    .putLong("alert_threshold_minutes", minutes)
                    .apply()

                Log.d("WearSettings", "Umbral actualizado a $minutes min")
            }
        }
    }
}
