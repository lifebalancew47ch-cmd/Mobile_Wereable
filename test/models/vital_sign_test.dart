import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/models/vital_sign.dart';

void main() {
  group('VitalSign Tests', () {
    test('Should create VitalSign correctly', () {
      final now = DateTime.now();
      final vitalSign = VitalSign(
        timestamp: now,
        heartRate: 75.0,
        hrv: 45.5,
        spo2: 98.0,
        steps: 1200,
        isSedentaryRisk: false,
      );

      expect(vitalSign.timestamp, now);
      expect(vitalSign.heartRate, 75.0);
      expect(vitalSign.hrv, 45.5);
      expect(vitalSign.spo2, 98.0);
      expect(vitalSign.steps, 1200);
    });

    test('toMap should convert VitalSign to Map correctly', () {
      final now = DateTime(2023, 1, 1, 12, 0, 0);
      final vitalSign = VitalSign(
        timestamp: now,
        heartRate: 72.0,
        hrv: 40.0,
        spo2: 99.0,
        steps: 5000,
        isSedentaryRisk: false,
      );

      final map = vitalSign.toMap();

      expect(map['timestamp'], now.toIso8601String());
      expect(map['heart_rate'], 72.0);
      expect(map['hrv'], 40.0);
      expect(map['spo2'], 99.0);
      expect(map['steps'], 5000);
    });

    test('fromMap should create VitalSign from Map correctly', () {
      final nowString = '2023-01-01T12:00:00.000';
      final map = {
        'timestamp': nowString,
        'heart_rate': 80.0,
        'hrv': 50.0,
        'spo2': 97.0,
        'steps': 3000,
      };

      final vitalSign = VitalSign.fromMap(map);

      expect(vitalSign.timestamp, DateTime.parse(nowString));
      expect(vitalSign.heartRate, 80.0);
      expect(vitalSign.hrv, 50.0);
      expect(vitalSign.spo2, 97.0);
      expect(vitalSign.steps, 3000);
    });
  });
}
