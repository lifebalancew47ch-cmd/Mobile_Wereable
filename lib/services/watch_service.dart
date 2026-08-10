import 'dart:async';
import '../models/vital_sign.dart';
import '../data/datasources/secure_database_service.dart';
import 'wearable_communication_service.dart';

abstract class IWatchService {
  Future<bool> requestPermissions();
  Future<bool> isApiAvailable();
  Future<VitalSign?> getLatestMetrics();
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)});
}

class WatchService implements IWatchService {
  Timer? _syncTimer;
  final WearableCommunicationService _wearableService = WearableCommunicationService();
  StreamSubscription? _accelSub;
  VitalSign? _latestSign;
  DateTime? _lastSavedTime;

  WatchService() {
    _accelSub = _wearableService.sensorStream.listen((data) {
      _latestSign = VitalSign(
        timestamp: DateTime.fromMillisecondsSinceEpoch(data.timestamp),
        heartRate: data.heartRate,
        hrv: data.hrv,
        spo2: data.spo2,
        steps: data.steps,
        isSedentaryRisk: false,
        accelX: data.x,
        accelY: data.y,
        accelZ: data.z,
        gyroX: data.gyroX,
        gyroY: data.gyroY,
        gyroZ: data.gyroZ,
      );
      _maybeSaveMetricsImmediately();
    });
    startPeriodicSync();
  }

  void _maybeSaveMetricsImmediately() async {
    final metrics = _latestSign;
    if (metrics == null) return;
    if (metrics.heartRate <= 0 &&
        metrics.hrv <= 0 &&
        metrics.spo2 <= 0 &&
        metrics.steps <= 0) {
      return;
    }
    final now = DateTime.now();
    if (_lastSavedTime == null || now.difference(_lastSavedTime!).inSeconds >= 60) {
      _lastSavedTime = now;
      await SecureDatabaseService.instance.insertVitalSign(metrics);
    }
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> isApiAvailable() async => true;

  @override
  Future<VitalSign?> getLatestMetrics() async => _latestSign;

  @override
  void startPeriodicSync({Duration interval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (timer) async {
      final metrics = _latestSign;
      if (metrics == null ||
          (metrics.heartRate <= 0 &&
              metrics.hrv <= 0 &&
              metrics.spo2 <= 0 &&
              metrics.steps <= 0)) {
        return;
      }
      _lastSavedTime = DateTime.now();
      await SecureDatabaseService.instance.insertVitalSign(metrics);
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _accelSub?.cancel();
  }
}