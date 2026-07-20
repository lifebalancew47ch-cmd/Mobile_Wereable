import 'dart:async';
import '../models/vital_sign.dart';
import '../data/datasources/secure_database_service.dart';

abstract class IWatchService {
  Future<bool> requestPermissions();
  Future<bool> isApiAvailable();
  Future<VitalSign?> getLatestMetrics();
  void startPeriodicSync();
}

class WatchService implements IWatchService {
  Timer? _syncTimer;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> isApiAvailable() async => true;

  @override
  Future<VitalSign?> getLatestMetrics() async => null;

  @override
  void startPeriodicSync() {
    _syncTimer?.cancel();
    // Implementación del Timer.periodic (Sección 15.2) cada 5 minutos
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final hasPerm = await requestPermissions();
      if (hasPerm) {
        final metrics = await getLatestMetrics();
        if (metrics != null) {
          // Persistencia en base de datos segura (Sección 7)
          await SecureDatabaseService.instance.insertVitalSign(metrics);
        }
      }
    });
  }
}