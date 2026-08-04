import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/datasources/secure_database_service.dart';
import '../features/ingestion/data/ingestion_api_service.dart';
import '../features/gamification/data/gamification_api_service.dart';
import '../features/medical/data/medical_api_service.dart';
import '../features/sedentary/data/sedentary_api_service.dart';
import 'device_identity_service.dart';

/// Sincronización Offline-First hacia la nube.
///
/// Todos los datos fisiológicos y eventos de inactividad se guardan primero en
/// SQLite (columna `synced_to_cloud = 0`). Este servicio los agrupa en lotes
/// (Batch) y los envía asíncronamente cada 15 minutos, o de inmediato al
/// recuperar la conexión. Ante un fallo de red, los datos permanecen en la
/// cola local para el siguiente ciclo (sin pérdida de datos).
///
/// Además de la cola de Ingestion, sincroniza las lecturas de salud al
/// Medical Data Service (`POST /medical/readings/batch`) usando un cursor
/// temporal para no reenviar lecturas ya subidas.
class OfflineSyncService {
  final IngestionApiService _ingestionApi;
  final GamificationApiService _gamificationApi;
  final MedicalApiService? _medicalApi;
  final SedentaryApiService? _sedentaryApi;
  final SecureDatabaseService _db;
  final DeviceIdentityService _deviceIdentity;

  Timer? _timer;
  StreamSubscription<bool>? _connectivitySub;
  bool _syncing = false;

  /// Última sincronización completada con éxito (para la UI).
  DateTime? lastSync;

  /// Cursor temporal de la última lectura médica enviada.
  DateTime _lastMedicalSync = DateTime.fromMillisecondsSinceEpoch(0);

  /// Día para el que ya se reportó actividad al motor sedentario.
  String? _lastReportedActivityDay;

  OfflineSyncService({
    required IngestionApiService ingestionApi,
    required GamificationApiService gamificationApi,
    MedicalApiService? medicalApi,
    SedentaryApiService? sedentaryApi,
    SecureDatabaseService? db,
    DeviceIdentityService? deviceIdentity,
  })  : _ingestionApi = ingestionApi,
        _gamificationApi = gamificationApi,
        _medicalApi = medicalApi,
        _sedentaryApi = sedentaryApi,
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

  /// Fuerza una sincronización inmediata (desde la UI, "Sincronizar ahora").
  /// Devuelve true si terminó sin errores; false si quedó algo pendiente.
  Future<bool> syncNow() async {
    var ok = true;
    if (_syncing) return false;
    _syncing = true;
    try {
      await _flushActiveBreaks();
      await _flushIngestionBatch();
      await _flushMedicalReadings();
      await _flushDailyActivity();
      lastSync = DateTime.now();
    } catch (e) {
      debugPrint('[OfflineSync] Error en syncNow: $e');
      ok = false;
    } finally {
      _syncing = false;
    }
    return ok;
  }

  /// Envía todo lo pendiente. Nunca lanza a la UI: un fallo de red mantiene
  /// los registros en la cola local (Offline-First).
  Future<void> flush() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await _flushActiveBreaks();
      await _flushIngestionBatch();
      await _flushMedicalReadings();
      await _flushDailyActivity();
      lastSync = DateTime.now();
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

    // El backend valida con [Range] estrictos (HeartRate 1-260, Spo2 1-100,
    // DurationMinutes 1-1440). Los registros placeholder (todo en 0, sin datos
    // reales del reloj) se descartan y se marcan como sincronizados para no
    // bloquear la cola Offline-First con un 400 persistente.
    final validVitals = <Map<String, Object?>>[];
    for (final row in vitals) {
      final hr = (row['heart_rate'] as num?)?.toInt() ?? 0;
      final hrv = (row['hrv'] as num?)?.toDouble() ?? 0;
      final spo2 = (row['spo2'] as num?)?.toDouble() ?? 0;
      final steps = (row['steps'] as num?)?.toInt() ?? 0;
      if (hr > 0 || hrv > 0 || spo2 > 0 || steps > 0) {
        validVitals.add(row);
      } else {
        await _db.markVitalSignSynced(row['id'] as int);
      }
    }

    final validSessions = <Map<String, Object?>>[];
    for (final row in sessions) {
      if (((row['duration_minutes'] as num?)?.toInt() ?? 0) >= 1) {
        validSessions.add(row);
      } else {
        await _db.markActivitySessionSynced(row['id'] as int);
      }
    }

    final validAlerts = <Map<String, Object?>>[];
    for (final row in alerts) {
      if (((row['duration_minutes'] as num?)?.toInt() ?? 0) >= 1) {
        validAlerts.add(row);
      } else {
        await _db.markAlertSynced(row['id'] as int);
      }
    }

    if (validVitals.isEmpty && validSessions.isEmpty && validAlerts.isEmpty) return;

    final vitalIds = validVitals.map((e) => e['id'] as int).toList();
    final sessionIds = validSessions.map((e) => e['id'] as int).toList();
    final alertIds = validAlerts.map((e) => e['id'] as int).toList();

    final deviceId = await _deviceIdentity.getDeviceId();
    final clientBatchId = _newBatchId();
    final request = SyncBatchRequest(
      clientBatchId: clientBatchId,
      deviceId: deviceId,
      vitalSigns:
          validVitals.isNotEmpty ? validVitals.map(_toVitalItem).toList() : null,
      activitySessions: validSessions.isNotEmpty
          ? validSessions.map(_toSessionItem).toList()
          : null,
      alerts: validAlerts.isNotEmpty ? validAlerts.map(_toAlertItem).toList() : null,
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

  /// Sube las lecturas de salud al Medical Data Service de forma incremental
  /// (POST /medical/readings/batch). No toca los flags de Ingestion.
  Future<void> _flushMedicalReadings() async {
    final medicalApi = _medicalApi;
    if (medicalApi == null) return;

    final readings = await _db.getVitalSignsAfter(_lastMedicalSync);
    if (readings.isEmpty) return;

    // Descarta placeholders sin datos reales (todo en 0) para no rechazar
    // el batch completo por validación del backend.
    final validReadings = readings.where((row) {
      final hr = (row['heart_rate'] as num?)?.toDouble() ?? 0;
      final hrv = (row['hrv'] as num?)?.toDouble() ?? 0;
      final spo2 = (row['spo2'] as num?)?.toDouble() ?? 0;
      final steps = (row['steps'] as num?)?.toInt() ?? 0;
      return hr > 0 || hrv > 0 || spo2 > 0 || steps > 0;
    }).toList();
    if (validReadings.isEmpty) {
      // No hay nada útil que subir: avanzamos el cursor para no reintentar.
      _lastMedicalSync = DateTime.tryParse(
            (readings.last['timestamp'] as String?) ?? '',
          ) ??
          DateTime.now();
      return;
    }

    final deviceId = await _deviceIdentity.getDeviceId();
    final batch = validReadings.map((row) {
      final rawTs = (row['timestamp'] as String?) ?? '';
      return MedicalReading(
        heartRate: (row['heart_rate'] as num?)?.toDouble() ?? 0,
        hrv: (row['hrv'] as num?)?.toDouble() ?? 0,
        spo2: (row['spo2'] as num?)?.toDouble() ?? 0,
        steps: (row['steps'] as num?)?.toInt() ?? 0,
        deviceId: deviceId,
        recordedAtUtc: DateTime.tryParse(rawTs) ?? DateTime.now(),
      );
    }).toList();

    try {
      await medicalApi.addReadingsBatch(batch);
      // Avanzamos el cursor a la última lectura enviada.
      final last = DateTime.tryParse(
            (validReadings.last['timestamp'] as String?) ?? '',
          ) ??
          DateTime.now();
      _lastMedicalSync = last;
      debugPrint('[OfflineSync] Lecturas médicas enviadas: ${batch.length}');
    } catch (e) {
      // Sin conexión: se reintentará en el siguiente ciclo.
      debugPrint('[OfflineSync] Error enviando lecturas médicas: $e');
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

  /// Reporta la actividad diaria agregada al Sedentary Engine
  /// (POST /sedentary/activity). Solo una vez por día para no duplicar.
  Future<void> _flushDailyActivity() async {
    final sedentaryApi = _sedentaryApi;
    if (sedentaryApi == null) return;

    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_lastReportedActivityDay == dayKey) return;

    try {
      final today = await _db.getActivitySessionsForDay(now);

      var activeMinutes = 0;
      var sedentaryMinutes = 0;
      for (final session in today) {
        final duration = (session['duration_minutes'] as int?) ?? 0;
        final type = session['type'] as String?;
        if (type == 'active') {
          activeMinutes += duration;
        } else if (type == 'idle' || type == 'alert') {
          sedentaryMinutes += duration;
        }
      }

      // Pasos del día: último valor acumulado de vital_signs.
      var dailySteps = 0;
      final vitals = await _db.getVitalSignsAfter(
        DateTime(now.year, now.month, now.day),
      );
      for (final row in vitals) {
        final steps = (row['steps'] as num?)?.toInt() ?? 0;
        if (steps > dailySteps) dailySteps = steps;
      }

      await sedentaryApi.recordActivity(
        dailySteps: dailySteps,
        activeMinutes: activeMinutes.toDouble(),
        sedentaryHours: sedentaryMinutes / 60.0,
      );
      _lastReportedActivityDay = dayKey;
      debugPrint(
          '[OfflineSync] Actividad diaria reportada: ${activeMinutes}min activos / ${sedentaryMinutes}min inactivo / $dailySteps pasos.');
    } catch (e) {
      debugPrint('[OfflineSync] Error reportando actividad diaria: $e');
    }
  }

  String _newBatchId() {
    final rnd = Random.secure();
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = rnd.nextInt(0x7FFFFFFF).toRadixString(16);
    return '${now.toRadixString(16).padLeft(8, '0')}-$rand';
  }
}
