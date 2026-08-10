import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/secure_database_service.dart';
import '../features/ingestion/data/ingestion_api_service.dart';
import '../features/gamification/data/gamification_api_service.dart';
import '../features/medical/data/medical_api_service.dart';
import '../features/sedentary/data/sedentary_api_service.dart';
import 'device_identity_service.dart';
import 'location_service.dart';
import '../core/security/secure_storage.dart';
import '../core/utils/app_log.dart';

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
  /// Persistido en SharedPreferences para sobrevivir reinicios del app/isolate.
  String? _lastReportedActivityDay;
  static const _kLastReportedDayKey = 'offline_sync_last_reported_day';

  // M-05 (fix 07/08/2026): cursor de sincronización médica persistido en
  // SharedPreferences. Antes se reiniciaba a epoch en cada arranque, lo que
  // enviaba todas las lecturas históricas al backend en cada inicio de app.
  static const _kLastMedicalSyncKey = 'offline_sync_last_medical_sync_ts';

  /// Carga el estado persistido (cursor médico + día reportado) al arrancar.
  Future<void> _loadLastReportedDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastReportedActivityDay = prefs.getString(_kLastReportedDayKey);
      // M-05: restaurar cursor médico desde SharedPreferences.
      final ts = prefs.getString(_kLastMedicalSyncKey);
      if (ts != null) {
        _lastMedicalSync = DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (_) {
      // Si falla, se re-reportará el día actual y se re-subirán lecturas
      // médicas recientes (sin consecuencias graves; el backend deduplica).
    }
  }

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
  /// M-05: persiste el cursor de sincronización médica en SharedPreferences
  /// para que el próximo arranque de app/isolate no reenvíe lecturas ya subidas.
  void _persistMedicalSyncCursor() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kLastMedicalSyncKey, _lastMedicalSync.toIso8601String());
    }).catchError((_) {});
  }

  void startPeriodicSync({
    Duration interval = const Duration(minutes: 15),
    Stream<bool>? connectivityStream,
  }) {
    _loadLastReportedDay(); // Restaura el estado persistido al iniciar.
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => flush());
    flush(); // Sync inmediato al arrancar la app
    _connectivitySub?.cancel();
    if (connectivityStream != null) {
      _connectivitySub = connectivityStream
          .where((online) => online)
          .listen((_) {
        flush();
      });
    }
    AppLog.d('[OfflineSync] Sincronización periódica activa (${interval.inMinutes} min).');
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

  /// Lecturas médicas pendientes de subir al Medical Data Service (después de cursor).
  Future<int> pendingMedicalCount() async {
    final readings = await _db.getVitalSignsAfter(_lastMedicalSync);
    return readings.length;
  }

  /// Fuerza una sincronización inmediata (desde la UI, "Sincronizar ahora").
  /// Devuelve true si terminó sin errores; false si quedó algo pendiente.
  Future<bool> syncNow() async {
    if (_syncing) return false;
    _syncing = true;
    var anySuccess = false;
    var hasErrors = false;

    try {
      try {
        await _flushActiveBreaks();
      } catch (e) {
        AppLog.d('[OfflineSync] Error en _flushActiveBreaks: $e');
        hasErrors = true;
      }

      try {
        await _flushIngestionBatch();
        anySuccess = true;
      } catch (e) {
        AppLog.d('[OfflineSync] Error en _flushIngestionBatch: $e');
        hasErrors = true;
      }

      try {
        await _flushMedicalReadings();
      } catch (e) {
        AppLog.d('[OfflineSync] Error en _flushMedicalReadings: $e');
        hasErrors = true;
      }

      try {
        await _flushDailyActivity();
      } catch (e) {
        AppLog.d('[OfflineSync] Error en _flushDailyActivity: $e');
        hasErrors = true;
      }

      lastSync = DateTime.now();
    } finally {
      _syncing = false;
    }

    return !hasErrors || anySuccess;
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
      await _db.purgeSyncedData(); // Purga automática de registros antiguos sincronizados
      lastSync = DateTime.now();
    } catch (e) {
      AppLog.d('[OfflineSync] Error en flush: $e');
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
    // Determinista: el mismo conjunto de filas pendientes produce el mismo
    // ClientBatchId en cada reintento (ver `_stableBatchId`). Antes era
    // aleatorio en cada llamada, así que si el servidor procesaba el lote
    // pero la respuesta se perdía (timeout, desconexión post-envío), el
    // siguiente flush lo reenviaba con un ID distinto y el servidor no tenía
    // forma de deduplicarlo -> datos médicos duplicados.
    final clientBatchId = _stableBatchId(deviceId, vitalIds, sessionIds, alertIds);
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

    final spo2Values = validVitals.map((r) => r['spo2']).toList();
    AppLog.d('[OfflineSync] Enviando lote $clientBatchId: '
        '${validVitals.length} vitals, spo2 raw en DB: $spo2Values');

    try {
      final response = await _ingestionApi.sync(request);

      // Si no hay errores de rechazo, marcamos el lote como sincronizado en una sola transacción atómica.
      if (response.status != 'CompletedWithErrors') {
        await _db.markBatchAsSynced(
          vitalIds: vitalIds,
          sessionIds: sessionIds,
          alertIds: alertIds,
        );
        AppLog.d('[OfflineSync] Ingestión exitosa del lote $clientBatchId');
      } else {
        AppLog.d('[OfflineSync] Lote $clientBatchId con errores (se reintenta).');
      }
    } on DioException catch (e) {
      AppLog.d('[OfflineSync] Error HTTP en Ingestion '
          '(${e.response?.statusCode}): ${e.response?.data}');
      if (e.response?.statusCode == 400 || e.response?.statusCode == 409) {
        // En caso de error 400 (inválido) o 409 (Conflicto por BatchId idempotente previamente procesado),
        // marcamos los elementos como sincronizados en una transacción atómica para desahogar la cola local.
        await _db.markBatchAsSynced(
          vitalIds: vitalIds,
          sessionIds: sessionIds,
          alertIds: alertIds,
        );
        AppLog.d('[OfflineSync] Lote $clientBatchId resuelto (Código ${e.response?.statusCode}).');
      } else {
        rethrow;
      }
    } catch (e) {
      AppLog.d('[OfflineSync] Error enviando lote de ingestión: $e');
      rethrow;
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

    // Biometría guardada del usuario (peso / altura) para cálculo automático de IMC y calorías en backend
    double userWeight = 0;
    double userHeight = 0;
    try {
      final wStr = await secureStorage.read(key: 'biometric_weight_kg');
      final hStr = await secureStorage.read(key: 'biometric_height_cm');
      if (wStr != null) userWeight = double.tryParse(wStr) ?? 0;
      if (hStr != null) userHeight = double.tryParse(hStr) ?? 0;
    } catch (_) {}

    // GPS bajo demanda (Sección: solo se captura en alertas de sedentarismo,
    // nunca en streaming continuo). Se adjunta la última coordenada conocida
    // si sigue siendo razonablemente reciente; si no hay ninguna o ya expiró,
    // la lectura médica viaja sin geolocalización.
    final lastGps = LocationService.lastKnown;
    final gpsFresh = lastGps != null &&
        DateTime.now().difference(lastGps.capturedAt) < const Duration(minutes: 60);

    final batch = <MedicalReading>[];
    for (final row in validReadings) {
      final rawTs = (row['timestamp'] as String?) ?? '';
      final hrRaw = ((row['heart_rate'] as num?)?.toDouble() ?? 0).round();
      // Contract: [Range(30, 250)] en backend C# MedicalReadingRequest
      final validHr = (hrRaw >= 30 && hrRaw <= 250) ? hrRaw.toDouble() : 70.0;
      final hrvRaw = (row['hrv'] as num?)?.toDouble() ?? 0;
      // Contract: [Range(0, 300)]
      final validHrv = (hrvRaw >= 0.0 && hrvRaw <= 300.0) ? hrvRaw : 0.0;
      final spo2Raw = (row['spo2'] as num?)?.toDouble() ?? 0;
      // Contract: [Range(50, 100)]
      final validSpo2 = (spo2Raw >= 50.0 && spo2Raw <= 100.0) ? spo2Raw : 95.0;
      final stepsRaw = (row['steps'] as num?)?.toInt() ?? 0;
      // Contract: [Range(0, 50000)]
      final validSteps = max(0, min(50000, stepsRaw));

      AppLog.d('[OfflineSync] Medical reading id=${row['id']} '
          'hr=$hrRaw→$validHr hrv=$hrvRaw→$validHrv spo2=$spo2Raw→$validSpo2 steps=$stepsRaw→$validSteps weight=$userWeight height=$userHeight');

      batch.add(MedicalReading(
        heartRate: validHr,
        hrv: validHrv,
        spo2: validSpo2,
        steps: validSteps,
        weight: userWeight,
        height: userHeight,
        deviceId: deviceId,
        recordedAtUtc: DateTime.tryParse(rawTs) ?? DateTime.now(),
        accelerometerX: (row['accel_x'] as num?)?.toDouble(),
        accelerometerY: (row['accel_y'] as num?)?.toDouble(),
        accelerometerZ: (row['accel_z'] as num?)?.toDouble(),
        gyroscopeX: (row['gyro_x'] as num?)?.toDouble(),
        gyroscopeY: (row['gyro_y'] as num?)?.toDouble(),
        gyroscopeZ: (row['gyro_z'] as num?)?.toDouble(),
        latitude: gpsFresh ? lastGps.latitude : null,
        longitude: gpsFresh ? lastGps.longitude : null,
      ));
    }

    if (batch.isEmpty) {
      final last = DateTime.tryParse(
            (validReadings.last['timestamp'] as String?) ?? '',
          ) ??
          DateTime.now();
      _lastMedicalSync = last;
      return;
    }

    try {
      await medicalApi.addReadingsBatch(batch);
      final last = DateTime.tryParse(
            (validReadings.last['timestamp'] as String?) ?? '',
          ) ??
          DateTime.now();
      _lastMedicalSync = last;
      // M-05: persistir cursor para que el próximo arranque no reenvíe todo.
      _persistMedicalSyncCursor();
      AppLog.d('[OfflineSync] Lecturas médicas enviadas: ${batch.length}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        // Validation error, advance cursor to not block queue
        final last = DateTime.tryParse(
              (validReadings.last['timestamp'] as String?) ?? '',
            ) ??
            DateTime.now();
        _lastMedicalSync = last;
        _persistMedicalSyncCursor(); // M-05
        AppLog.d('[OfflineSync] Lote médico descartado por HTTP 400.');
      } else {
        AppLog.d('[OfflineSync] Error HTTP enviando lecturas médicas: $e '
            '(se reintenta luego)');
      }
    } catch (e) {
      AppLog.d('[OfflineSync] Error inesperado enviando lecturas médicas: $e '
          '(se reintenta luego)');
    }
  }

  VitalSignSyncItem _toVitalItem(Map<String, Object?> row) {
    final rawTs = (row['timestamp'] as String?) ?? '';
    final hrRaw = ((row['heart_rate'] as num?)?.toDouble() ?? 0).round();
    final validHr = (hrRaw >= 1 && hrRaw <= 260) ? hrRaw : null;
    final hrvRaw = (row['hrv'] as num?)?.toDouble() ?? 0;
    final validHrv = (hrvRaw >= 1.0 && hrvRaw <= 300.0) ? hrvRaw : null;
    final spo2Raw = (row['spo2'] as num?)?.toDouble() ?? 0;
    // El backend requiere SpO2 en [50, 100] (campo no-nullable en C#).
    // Si el reloj no mide SpO2 (0) o da lectura inválida (1-49), usamos
    // 95.0 como placeholder — igual que hace biometric_profile_screen.dart.
    final validSpo2 = (spo2Raw >= 50.0 && spo2Raw <= 100.0) ? spo2Raw : 95.0;
    final stepsRaw = (row['steps'] as num?)?.toInt() ?? 0;
    final validSteps = max(0, stepsRaw);
    AppLog.d('[OfflineSync] _toVitalItem id=${row['id']} '
        'hr=$hrRaw→${validHr ?? "null"} '
        'hrv=${hrvRaw.toStringAsFixed(2)}→${validHrv != null ? validHrv.toStringAsFixed(2) : "null"} '
        'spo2=$spo2Raw→$validSpo2${spo2Raw < 50.0 ? "(placeholder)" : ""} '
        'steps=$stepsRaw');

    return VitalSignSyncItem(
      timestamp: DateTime.tryParse(rawTs) ?? DateTime.now(),
      heartRate: validHr,
      hrv: validHrv,
      spo2: validSpo2,
      steps: validSteps,
    );
  }

  ActivitySessionSyncItem _toSessionItem(Map<String, Object?> row) {
    final duration = max(1, (row['duration_minutes'] as num?)?.toInt() ?? 1);
    return ActivitySessionSyncItem(
      startTime: DateTime.tryParse((row['start_time'] as String?) ?? '') ?? DateTime.now(),
      endTime: DateTime.tryParse((row['end_time'] as String?) ?? '') ?? DateTime.now(),
      type: (row['type'] as String?) ?? 'idle',
      durationMinutes: duration,
    );
  }

  AlertSyncItem _toAlertItem(Map<String, Object?> row) {
    final duration = max(1, (row['duration_minutes'] as num?)?.toInt() ?? 1);
    return AlertSyncItem(
      timestamp: DateTime.tryParse((row['timestamp'] as String?) ?? '') ?? DateTime.now(),
      type: (row['type'] as String?) ?? 'sedentary',
      durationMinutes: duration,
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

      // Pasos del día y mapa de calor por hora (24 enteros).
      var dailySteps = 0;
      final hourlyHeatmap = List<int>.filled(24, 0);
      final maxStepsPerHour = List<int>.filled(24, 0);

      final vitals = await _db.getVitalSignsAfter(
        DateTime(now.year, now.month, now.day),
      );
      for (final row in vitals) {
        final steps = (row['steps'] as num?)?.toInt() ?? 0;
        if (steps > dailySteps) dailySteps = steps;

        final rawTs = row['timestamp'] as String?;
        if (rawTs != null) {
          final dt = DateTime.tryParse(rawTs)?.toLocal();
          if (dt != null && dt.hour >= 0 && dt.hour < 24) {
            if (steps > maxStepsPerHour[dt.hour]) {
              maxStepsPerHour[dt.hour] = steps;
            }
          }
        }
      }

      // Calcular el delta horaria de pasos para el heatmap
      int previousMax = 0;
      for (var h = 0; h < 24; h++) {
        if (maxStepsPerHour[h] > 0) {
          final delta = maxStepsPerHour[h] - previousMax;
          hourlyHeatmap[h] = delta > 0 ? delta : 0;
          previousMax = maxStepsPerHour[h];
        }
      }

      // Calorías quemadas: activeMinutes * 5.0 (o de pasos)
      final caloriesBurned = (activeMinutes * 5.0) + (dailySteps * 0.04);

      // Opción B.1: Enviar sesión de actividad directa al SedentaryEngine
      await sedentaryApi.recordActivity(
        dailySteps: dailySteps,
        activeMinutes: activeMinutes.toDouble(),
        sedentaryHours: sedentaryMinutes / 60.0,
        caloriesBurned: caloriesBurned,
        hourlyHeatmap: hourlyHeatmap,
        recordedAtUtc: now,
      );

      // Opción B.2: Enviar como evento crudo de sincronización al IngestionService
      try {
        final deviceId = await _deviceIdentity.getDeviceId();
        await _ingestionApi.postEvent(
          deviceId: deviceId,
          eventType: 'ActivitySession',
          source: 'MobileApp',
          occurredAtUtc: now,
          payload: {
            'dailySteps': dailySteps,
            'activeMinutes': activeMinutes.toDouble(),
            'sedentaryHours': (sedentaryMinutes / 60.0),
            'caloriesBurned': caloriesBurned,
            'hourlyHeatmap': hourlyHeatmap,
          },
        );
      } catch (ingestionErr) {
        AppLog.d('[OfflineSync] Evento ActivitySession en Ingestion omitido/error: $ingestionErr');
      }

      _lastReportedActivityDay = dayKey;
      // Persistir para que el próximo inicio de app/isolate no duplique.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kLastReportedDayKey, dayKey);
      } catch (_) {}
      // A-02: métricas de actividad son datos de salud del usuario; usar
      // AppLog (no-op fuera de kDebugMode) en vez de debugPrint (que sí
      // escribe a logcat en release).
      AppLog.d(
          '[OfflineSync] Actividad diaria reportada (Sedentary + Ingestion): ${activeMinutes}min activos / ${sedentaryMinutes}min inactivo / $dailySteps pasos / ${caloriesBurned.toStringAsFixed(1)} kcal.');
    } catch (e) {
      AppLog.d('[OfflineSync] Error reportando actividad diaria: $e');
    }
  }

  /// ClientBatchId determinista: función pura del dispositivo + IDs locales
  /// que componen el lote. Reintentar el envío del mismo conjunto de filas
  /// no sincronizadas (porque la respuesta anterior se perdió, no porque el
  /// servidor haya rechazado los datos) produce siempre el mismo ID, dándole
  /// al backend una clave de idempotencia real para deduplicar.
  ///
  /// Si el conjunto de filas cambia (llegaron datos nuevos, o algunas ya se
  /// marcaron `synced_to_cloud=1`), el ID cambia también -- es, por diseño,
  /// un lote distinto.
  String _stableBatchId(
    String deviceId,
    List<int> vitalIds,
    List<int> sessionIds,
    List<int> alertIds,
  ) {
    final v = (List<int>.from(vitalIds)..sort()).join('.');
    final s = (List<int>.from(sessionIds)..sort()).join('.');
    final a = (List<int>.from(alertIds)..sort()).join('.');
    return _fnv1a64('$deviceId|v:$v|s:$s|a:$a');
  }

  /// FNV-1a de 64 bits. Determinista y sin dependencias externas (no se
  /// añade el paquete `crypto` solo para esto); no necesita ser criptográfico,
  /// solo estable para la misma entrada entre reintentos.
  String _fnv1a64(String input) {
    const int mask64 = 0xFFFFFFFFFFFFFFFF;
    const int prime = 0x100000001b3;
    int hash = 0xcbf29ce484222325;
    for (final codeUnit in input.codeUnits) {
      hash = (hash ^ codeUnit) & mask64;
      hash = (hash * prime) & mask64;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
