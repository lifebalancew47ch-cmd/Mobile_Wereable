import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

/// Muestra de acelerómetro (compatibilidad heredada: solo X/Y/Z + timestamp).
class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final int timestamp;

  AccelerometerData(this.x, this.y, this.z, this.timestamp);

  factory AccelerometerData.fromJson(Map<String, dynamic> json) {
    return AccelerometerData(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['z'] as num).toDouble(),
      json['timestamp'] as int,
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
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as int,
    );
  }
}

class WearableCommunicationService {
  static const EventChannel _wearableEventChannel =
      EventChannel('com.example.lifebalance/wearable_sensors');

  Stream<List<Map<String, dynamic>>> get _batches {
    return _wearableEventChannel.receiveBroadcastStream().map((event) {
      final String dataString = event as String;
      final List<dynamic> batch = jsonDecode(dataString);
      return batch.map((item) => item as Map<String, dynamic>).toList();
    });
  }

  /// Stream de datos de acelerómetro (compatibilidad heredada).
  Stream<AccelerometerData> get accelerometerStream {
    return _batches.expand(
      (batch) => batch.map(AccelerometerData.fromJson),
    );
  }

  /// Stream de muestras fisiológicas completas (acel + giro + salud + pasos).
  Stream<WearableSensorSample> get sensorStream {
    return _batches.expand(
      (batch) => batch.map(WearableSensorSample.fromJson),
    );
  }

  /// Stream de muestras completas throttled para la UI.
  Stream<WearableSensorSample> get sensorStreamThrottled {
    return sensorStream.throttleTime(const Duration(seconds: 5));
  }

  /// Stream de acelerómetro throttled para la UI.
  Stream<AccelerometerData> get accelerometerStreamThrottled {
    return accelerometerStream.throttleTime(const Duration(seconds: 5));
  }
}