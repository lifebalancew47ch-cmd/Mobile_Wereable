import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/datasources/secure_database_service.dart';
import '../features/ingestion/data/ingestion_api_service.dart';
import '../features/gamification/data/gamification_api_service.dart';
import 'device_identity_service.dart';

/// Sincronización Offline-First hacia el Ingestion Service.
///
/// Todos los datos fisiológicos y eventos de inactividad se guardan primero en
/// SQLite (columna `synced_to_cloud = 0`). Este servicio los agrupa en lotes
/// (Batch) y los envía asíncronamente cada 15 minutos, o de inmediato al
/// recuperar la conexión. Ante un fallo de red, los datos permanecen en la
/// cola local para el siguiente ciclo (sin pérdida de datos).
class OfflineSyncService {
  final IngestionApiService _ingestionApi;
  final GamificationApiService _gamificationApi;
  final SecureDatabaseService _db;
  final DeviceIdentityService _deviceIdentity;

  Timer? _timer;
  StreamSubscription<bool>? _connectivitySub;
  bool _syncing = false;

  OfflineSyncService({
    required IngestionApiService ingestionApi,
    required GamificationApiService gamificationApi,
    SecureDatabaseService? db,
    DeviceIdentityService? deviceIdentity,
  })  : _ingestionApi = ingestionApi,
        _gamificationApi = gamificationApi,
        _db = db ?? SecureDatabaseService.instance,
        _deviceIdentity = deviceIdentity ?? DeviceIdentityService();

  /// Inicia el ciclo periódico (por defecto 15 min) y, si se provee un stream
  /// de conectividad, sincroniza de inmediato al recuperar conexión.
  void startPeriodicSync({
    Duration interval = const Duration(minutes: 15),
    Stream<bool>? connectivityStream,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => flush());
    _connectivitySub?.cancel();
    if (connectivityStream != null) {
      _connectivitySub = connectivityStream
          .where((online) => online)
          .listen((_) {
        flush();
      });
    }
    debugPrint('[OfflineSync] Sincronización periódica activa (${interval.inMinutes} min).');
  }

  void stop() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    _timer = null;
    _connectivitySub = null;
  }

  /// Registros en espera de sincronización (para la UI).
  Future<int> pendingCount() async {
    final vitals = await _db.getUnsyncedVitalSigns();
    final sessions = await _db.getUnsyncedActivitySessions();
    final alerts = await _db.getUnsyncedAlerts();
    final breaks = await _db.getUnsyncedActiveBreaks();
    return vitals.length + sessions.length + alerts.length + breaks.length;
  }

  /// Envía todo lo pendiente. Nunca lanza a la UI: un fallo de red mantiene
  /// los registros en la cola local (Offline-First).
  Future<void> flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _flushActiveBreaks();
      await _flushIngestionBatch();
    } catch (e) {
      debugPrint('[OfflineSync] Error en flush: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _flushActiveBreaks() async {
    final breaks = await _db.getUnsyncedActiveBreaks();
    for (final b in breaks) {
      try {
        await _gamificationApi.sendEvent(
          eventType: 'ACTIVE_BREAK_COMPLETED',
          points: b.points,
          rewardName: b.type,
        );
        await _db.markActiveBreakSynced(b.id!);
      } catch (_) {
        // Sin conexión: se queda en la cola local.
      }
    }
  }

  Future<void> _flushIngestionBatch() async {
    final vitals = await _db.getUnsyncedVitalSigns();
    final sessions = await _db.getUnsyncedActivitySessions();
    final alerts = await _db.getUnsyncedAlerts();

    if (vitals.isEmpty && sessions.isEmpty && alerts.isEmpty) return;

    final vitalIds = vitals.map((e) => e['id'] as int).toList();
    final sessionIds = sessions.map((e) => e['id'] as int).toList();
    final alertIds = alerts.map((e) => e['id'] as int).toList();

    final deviceId = await _deviceIdentity.getDeviceId();
    final clientBatchId = _newBatchId();
    final request = SyncBatchRequest(
      clientBatchId: clientBatchId,
      deviceId: deviceId,
      vitalSigns: vitals.isNotEmpty ? vitals.map(_toVitalItem).toList() : null,
      activitySessions:
          sessions.isNotEmpty ? sessions.map(_toSessionItem).toList() : null,
      alerts: alerts.isNotEmpty ? alerts.map(_toAlertItem).toList() : null,
    );

    final response = await _ingestionApi.sync(request);

    // Si no hay errores de rechazo, marcamos el lote como sincronizado.
    if (response.status != 'CompletedWithErrors') {
      for (final id in vitalIds) {
        await _db.markVitalSignSynced(id);
      }
      for (final id in sessionIds) {
        await _db.markActivitySessionSynced(id);
      }
      for (final id in alertIds) {
        await _db.markAlertSynced(id);
      }
    } else {
      debugPrint('[OfflineSync] Lote $clientBatchId con errores (se reintenta).');
    }
  }

  VitalSignSyncItem _toVitalItem(Map<String, Object?> row) {
    final rawTs = (row['timestamp'] as String?) ?? '';
    return VitalSignSyncItem(
      timestamp: DateTime.tryParse(rawTs) ?? DateTime.now(),
      heartRate: ((row['heart_rate'] as num?)?.toDouble() ?? 0).round(),
      hrv: (row['hrv'] as num?)?.toDouble() ?? 0,
      spo2: (row['spo2'] as num?)?.toDouble() ?? 0,
      steps: (row['steps'] as num?)?.toInt() ?? 0,
    );
  }

  ActivitySessionSyncItem _toSessionItem(Map<String, Object?> row) {
    return ActivitySessionSyncItem(
      startTime: DateTime.tryParse((row['start_time'] as String?) ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse((row['end_time'] as String?) ?? '') ?? DateTime.now(),
      type: (row['type'] as String?) ?? 'unknown',
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  AlertSyncItem _toAlertItem(Map<String, Object?> row) {
    return AlertSyncItem(
      timestamp: DateTime.tryParse((row['timestamp'] as String?) ?? '') ?? DateTime.now(),
      type: (row['type'] as String?) ?? 'sedentary',
      durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 0,
      acknowledged: (row['acknowledged'] as num? ?? 0) == 1,
    );
  }

  String _newBatchId() {
    final rnd = Random.secure();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = rnd.nextInt(0x7FFFFFFF).toRadixString(16);
    return '${now.toRadixString(16).padLeft(8, '0')}-$rand';
  }
}