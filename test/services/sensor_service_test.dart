import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/services/sensor_service.dart';

void main() {
  group('SensorData Tests', () {
    test('Should create SensorData correctly', () {
      final now = DateTime.now();
      final data = SensorData(1.0, 2.0, 3.0, now);

      expect(data.x, 1.0);
      expect(data.y, 2.0);
      expect(data.z, 3.0);
      expect(data.timestamp, now);
    });
  });
}
