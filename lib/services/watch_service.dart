import 'package:health/health.dart';
import '../models/vital_sign.dart';
import 'database_service.dart';
import 'dart:async';

class WatchService {
  final Health _health = Health();
  Timer? _syncTimer;

  static const types = [
    HealthDataType.HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.STEPS,
  ];

  Future<bool> requestPermissions() async {
    final permissions = [
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
      HealthDataAccess.READ,
    ];
    bool hasPermissions =
        await _health.hasPermissions(types, permissions: permissions) ?? false;
    if (!hasPermissions) {
      try {
        hasPermissions = await _health.requestAuthorization(types,
            permissions: permissions);
      } catch (e) {
        print('Error requesting health permissions: $e');
      }
    }
    return hasPermissions;
  }

  Future<VitalSign?> fetchLatestVitals() async {
    final now = DateTime.now();
    final past = now.subtract(const Duration(minutes: 5));

    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        startTime: past,
        endTime: now,
        types: types,
      );

      if (healthData.isEmpty) return null;

      double hr = 0;
      double hrv = 0;
      double spo2 = 0;
      int steps = 0;

      for (var data in healthData) {
        if (data.type == HealthDataType.HEART_RATE) {
          hr = double.tryParse(data.value.toString()) ?? 0;
        } else if (data.type == HealthDataType.HEART_RATE_VARIABILITY_SDNN) {
          hrv = double.tryParse(data.value.toString()) ?? 0;
        } else if (data.type == HealthDataType.BLOOD_OXYGEN) {
          spo2 = double.tryParse(data.value.toString()) ?? 0;
        } else if (data.type == HealthDataType.STEPS) {
          steps += int.tryParse(data.value.toString()) ?? 0;
        }
      }

      return VitalSign(
        timestamp: now,
        heartRate: hr,
        hrv: hrv,
        spo2: spo2,
        steps: steps,
      );
    } catch (e) {
      print('Error fetching health data: $e');
      return null;
    }
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (timer) async {
      final hasPerm = await requestPermissions();
      if (hasPerm) {
        final vitals = await fetchLatestVitals();
        if (vitals != null) {
          await DatabaseService.instance.insertVitalSign(vitals);
        }
      }
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }
}
