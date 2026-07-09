import 'package:sensors_plus/sensors_plus.dart';

class SensorData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  SensorData(this.x, this.y, this.z, this.timestamp);
}

class SensorService {
  Stream<SensorData> get accelerometerStream {
    return accelerometerEventStream().map((event) {
      return SensorData(event.x, event.y, event.z, DateTime.now());
    });
  }
}
