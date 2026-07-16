import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/services/wearable_communication_service.dart';

void main() {
  group('AccelerometerData Tests', () {
    test('Should create AccelerometerData correctly', () {
      final data = AccelerometerData(1.5, 2.5, 3.5, 1672531200000);

      expect(data.x, 1.5);
      expect(data.y, 2.5);
      expect(data.z, 3.5);
      expect(data.timestamp, 1672531200000);
    });

    test('fromJson should parse map correctly', () {
      final jsonMap = {
        'x': 0.1,
        'y': -0.5,
        'z': 9.8,
        'timestamp': 1672531200000,
      };

      final data = AccelerometerData.fromJson(jsonMap);

      expect(data.x, 0.1);
      expect(data.y, -0.5);
      expect(data.z, 9.8);
      expect(data.timestamp, 1672531200000);
    });
  });
}
