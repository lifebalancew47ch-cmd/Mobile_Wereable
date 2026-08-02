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

  WatchService() {
    _accelSub = _wearableService.accelerometerStream.listen((data) {
      _latestSign = VitalSign(
        timestamp: DateTime.fromMillisecondsSinceEpoch(data.timestamp),
        heartRate: 0, // Placeholder
        hrv: 0,
        spo2: 0,
        steps: 0,
        isSedentaryRisk: false,
      );
    });
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
      final hasPerm = await requestPermissions();
      if (hasPerm) {
        final metrics = await getLatestMetrics();
        if (metrics != null) {
          // Delegar al aislar WorkManager nativo u optimización de bajo consumo en SQLite.
          // Aquí realizamos una pequeña inserción cada 5 minutos. 
          await SecureDatabaseService.instance.insertVitalSign(metrics);
        }
      }
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _accelSub?.cancel();
  }
}