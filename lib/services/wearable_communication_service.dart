import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

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

class WearableCommunicationService {
  static const EventChannel _wearableEventChannel =
      EventChannel('com.example.lifebalance/wearable_sensors');

  /// Stream of accelerometer data coming from the Wear OS watch
  Stream<AccelerometerData> get accelerometerStream {
    return _wearableEventChannel.receiveBroadcastStream().expand((event) {
      final String dataString = event as String;
      final List<dynamic> batch = jsonDecode(dataString);
      return batch.map((item) => AccelerometerData.fromJson(item as Map<String, dynamic>));
    });
  }

  /// Throttled stream for UI updates (e.g. 1 update every 5 seconds max)
  Stream<AccelerometerData> get accelerometerStreamThrottled {
    return accelerometerStream.throttleTime(const Duration(seconds: 5));
  }
}
