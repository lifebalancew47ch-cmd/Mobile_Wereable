import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/utils/app_log.dart';

/// Muestra de acelerómetro (compatibilidad heredada: solo X/Y/Z + timestamp).
class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final int timestamp;

  AccelerometerData(this.x, this.y, this.z, this.timestamp);

  factory AccelerometerData.fromJson(Map<String, dynamic> json) {
    return AccelerometerData(
      (json['x'] as num? ?? 0).toDouble(),
      (json['y'] as num? ?? 0).toDouble(),
      (json['z'] as num? ?? 0).toDouble(),
      (json['timestamp'] as num? ?? 0).toInt(),
    );
  }
}

/// Muestra fisiológica completa proveniente del wearable:
/// acelerómetro, giroscopio, podómetro, FC/HRV/SpO2 y GPS (Sección 1.A).
class WearableSensorSample {
  final double x, y, z; // acelerómetro
  final double gyroX, gyroY, gyroZ; // giroscopio (rad/s)
  final int steps; // podómetro acumulado
  final double heartRate; // lpm
  final double hrv; // ms
  final double spo2; // %
  final bool isOnBody; // detectado en muñeca
  final double? latitude, longitude; // GPS (solo en cambios drásticos)
  final int timestamp;

  WearableSensorSample({
    required this.x,
    required this.y,
    required this.z,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.steps,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    this.isOnBody = true,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  factory WearableSensorSample.fromJson(Map<String, dynamic> json) {
    return WearableSensorSample(
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      z: (json['z'] as num? ?? 0).toDouble(),
      gyroX: (json['gyroX'] as num? ?? 0).toDouble(),
      gyroY: (json['gyroY'] as num? ?? 0).toDouble(),
      gyroZ: (json['gyroZ'] as num? ?? 0).toDouble(),
      steps: (json['steps'] as num? ?? 0).toInt(),
      heartRate: (json['heartRate'] as num? ?? 0).toDouble(),
      hrv: (json['hrv'] as num? ?? 0).toDouble(),
      spo2: (json['spo2'] as num? ?? 0).toDouble(),
      isOnBody: (json['isOnBody'] as bool? ?? true),
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      timestamp: (json['timestamp'] as num? ?? 0).toInt(),
    );
  }
}

class WearableCommunicationService {
  static final WearableCommunicationService _instance =
      WearableCommunicationService._internal();

  factory WearableCommunicationService() => _instance;

  WearableCommunicationService._internal();

  static const EventChannel _wearableEventChannel =
      EventChannel('com.example.lifebalance/wearable_sensors');

  // Nuevo MethodChannel para enviar configuración al código nativo Android.
  static const MethodChannel _settingsChannel =
      MethodChannel('com.example.lifebalance/wearable_settings');

  /// Sincroniza el umbral de alerta de sedentarismo con el reloj vía DataClient.
  /// Retorna silenciosamente si falla (best-effort, DataClient reintenta solo).
  Future<void> syncAlertInterval(int minutes) async {
    try {
      await _settingsChannel.invokeMethod('syncAlertInterval', {'minutes': minutes});
    } catch (e) {
      // Silenciar: DataClient persiste el dato para sync futuro.
      AppLog.d('[WearSync] Error sincronizando umbral: $e');
    }
  }

  /// Stream "broadcast" compartido y cacheados: todos los getters derivan de
  /// una única suscripción al EventChannel nativo. Esto es obligatorio porque
  /// en Android un EventChannel admite UN solo sink: si cada getter llamara a
  /// `receiveBroadcastStream()` por separado, el último listener se llevaría
  /// todos los eventos y el resto vería "sin datos".
  late final Stream<List<Map<String, dynamic>>> _batches =
      _wearableEventChannel.receiveBroadcastStream().map((event) {
    try {
      final String dataString = event as String;
      AppLog.d('[Wearable] Batch recibido en Dart (${dataString.length} chars)');
      final List<dynamic> batch = jsonDecode(dataString);
      return batch.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      AppLog.d('[Wearable] Error parseando lote nativo: $e');
      return <Map<String, dynamic>>[];
    }
  }).asBroadcastStream();

  /// Stream de datos de acelerómetro (compatibilidad heredada).
  Stream<AccelerometerData> get accelerometerStream {
    return _batches.expand(
      (batch) => batch.map((item) {
        try {
          return AccelerometerData.fromJson(item);
        } catch (e) {
          return null;
        }
      }).where((s) => s != null).cast<AccelerometerData>(),
    );
  }

  /// Stream de muestras fisiológicas completas (acel + giro + salud + pasos).
  Stream<WearableSensorSample> get sensorStream {
    return _batches.expand(
      (batch) => batch.map((item) {
        try {
          return WearableSensorSample.fromJson(item);
        } catch (e) {
          return null;
        }
      }).where((s) => s != null).cast<WearableSensorSample>(),
    );
  }

  /// Stream de muestras completas throttled para la UI (última del lote).
  Stream<WearableSensorSample> get sensorStreamThrottled {
    return _batches.map((batch) {
      if (batch.isEmpty) return null;
      try {
        final sample = WearableSensorSample.fromJson(batch.last);
        AppLog.d('[Wearable] UI sample: steps=${sample.steps} '
            'hr=${sample.heartRate} hrv=${sample.hrv} spo2=${sample.spo2}');
        if (sample.spo2 > 0 && sample.spo2 < 50) {
          AppLog.d('[Wearable] ⚠️ SpO2 fuera de rango API (50-100%): '
              '${sample.spo2} — se filtrará en sync');
        }
        return sample;
      } catch (e) {
        AppLog.d('[Wearable] UI sample ERROR: $e');
        return null;
      }
    }).where((sample) => sample != null).cast<WearableSensorSample>();
  }

  /// Stream de acelerómetro throttled para la UI (última del lote).
  Stream<AccelerometerData> get accelerometerStreamThrottled {
    return _batches.map((batch) {
      if (batch.isEmpty) return null;
      try {
        return AccelerometerData.fromJson(batch.last);
      } catch (e) {
        AppLog.d('[Wearable] Accel throttled ERROR: $e');
        return null;
      }
    }).where((data) => data != null).cast<AccelerometerData>();
  }
}