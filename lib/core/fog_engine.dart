import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/fog_state.dart';
import '../services/notification_service.dart';
import '../services/wearable_communication_service.dart';
import '../data/datasources/secure_database_service.dart';
import 'filters/clinical_state_classifier.dart';
import 'utils/app_log.dart';

/// Función top-level invocada en un Isolate secundario (vía [compute]) para
/// calcular la varianza de las magnitudes del acelerómetro sin bloquear el
/// hilo principal ni el aislado del motor Fog. Devuelve 0 para listas vacías.
double _computeVarianceOf(List<double> values) {
  if (values.isEmpty) return 0.0;
  final length = values.length;
  var sum = 0.0;
  for (final v in values) {
    sum += v;
  }
  final mean = sum / length;
  var sq = 0.0;
  for (final v in values) {
    final d = v - mean;
    sq += d * d;
  }
  return sq / length;
}

/// FogEngine es el motor principal de detección de sedentarismo.
/// Evalúa la varianza del acelerómetro en ventanas de 30 segundos y lo cruza
/// con el Filtro Clínico de Falsos Positivos ([ClinicalStateClassifier]).
class FogEngine {
  final WearableCommunicationService _wearableService;
  final NotificationService _notificationService;

  StreamSubscription? _accelSub;
  Timer? _analysisTimer;

  // Acumula magnitudes vectoriales y vectores crudos de la ventana actual.
  final List<double> _magnitudes = [];
  final List<AccelerometerData> _vectors = [];

  // Contador de ventanas inactivas y activas consecutivas (30s c/u).
  int _inactiveWindows = 0;
  int _activeWindows = 0;
  int _alertThresholdWindows = 90;
  static const double _varianceThreshold = 0.05;
  static const int _minutesPerWindow = 2; // 2 ventanas por minuto (30s c/u)

  int _consecutiveActiveWindows = 0;

  DateTime _lastMovement = DateTime.now();
  String _sessionStartTime = DateTime.now().toIso8601String();
  String _activeStartTime = DateTime.now().toIso8601String();

  // Filtro Clínico de Falsos Positivos.
  final ClinicalStateClassifier _clinicalClassifier = ClinicalStateClassifier();
  double? _latestHeartRate;
  double? _latestHrv;
  bool _windowInFlight = false;

  // Cola de reintento para escrituras a SQLite que fallaron (p. ej. disco
  // lleno, error de I/O de SQLCipher). Antes estas escrituras se disparaban
  // sin `await` y una excepción se perdía en silencio, fuera del alcance del
  // try/catch de `_analyzeWindow`. Ahora se esperan, y si fallan quedan en
  // esta cola acotada para reintentarse en la próxima ventana en vez de
  // perderse. Tope bajo a propósito: si la cola se llena es señal de que el
  // problema (disco lleno) no se va a resolver solo reintentando.
  final List<Future<void> Function()> _pendingWrites = [];
  static const int _maxPendingWrites = 100;

  static const MethodChannel _nativeFogChannel = MethodChannel('com.example.lifebalance/native_fog_sync');

  // Métricas del motor real (expuestas a la UI).
  int _samplesProcessed = 0;
  int _windowsAnalyzed = 0;
  int _alertsTriggered = 0;
  bool _isRunning = false;
  Duration _lastWindowAnalysis = Duration.zero;

  final _stateController = StreamController<FogState>.broadcast();

  /// Stream con actualizaciones en tiempo real del estado Fog.
  Stream<FogState> get stateStream => _stateController.stream;

  int get samplesProcessed => _samplesProcessed;
  int get windowsAnalyzed => _windowsAnalyzed;
  int get alertsTriggered => _alertsTriggered;
  bool get isRunning => _isRunning;
  Duration get lastWindowAnalysis => _lastWindowAnalysis;

  /// Estado clínico actual (Filtro de Falsos Positivos).
  ClinicalState get clinicalState => _toUiState(_clinicalClassifier.state);

  /// `true` cuando el reposo clínico fue verificado (steady-state).
  bool get reposoVerificado => _clinicalClassifier.reposoVerificado;

  /// Minutos acumulados de reposo clínico.
  int get restMinutes => _clinicalClassifier.restMinutes;

  /// `true` si hay escrituras de actividad/alertas pendientes de reintentar
  /// (la última escritura a SQLite falló). La UI puede usarlo para avisar al
  /// usuario de un problema de almacenamiento en vez de fallar en silencio.
  bool get hasPendingWrites => _pendingWrites.isNotEmpty;

  FogEngine(this._wearableService, this._notificationService);

  /// Inyecta la lectura clínica más reciente (FC y HRV) desde el sensor
  /// de salud del wearable para alimentar el Filtro de Falsos Positivos.
  void feedClinicalSample({required double? heartRate, required double? hrv}) {
    _latestHeartRate = heartRate;
    _latestHrv = hrv;
  }

  /// Inicia el motor escuchando el acelerómetro del wearable.
  Future<void> start() async {
    if (_isRunning) return;

    try {
      final int idleCount = await _nativeFogChannel.invokeMethod('getIdleWindows') ?? 0;
      if (idleCount > _inactiveWindows) {
        _inactiveWindows = idleCount;
      }
      await _nativeFogChannel.invokeMethod('resetIdleWindows');
    } catch (e) {
      AppLog.d('Error syncing with NativeFogEngine: $e');
    }

    _accelSub = _wearableService.accelerometerStream.listen((AccelerometerData data) {
      final double mag = sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
      // Descarta muestras no finitas para no envenenar la varianza.
      if (!mag.isFinite) return;
      _magnitudes.add(mag);
      _vectors.add(data);
      _samplesProcessed++;
    });

    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _analyzeWindow();
    });

    _isRunning = true;
  }

  void pause() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _accelSub = null;
    _analysisTimer = null;
    _isRunning = false;
  }

  void resume() {
    if (_isRunning) return;
    _accelSub = _wearableService.accelerometerStream.listen((AccelerometerData data) {
      final double mag = sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
      if (!mag.isFinite) return;
      _magnitudes.add(mag);
      _vectors.add(data);
      _samplesProcessed++;
    });
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _analyzeWindow();
    });
    _isRunning = true;
  }

  void stop() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _accelSub = null;
    _analysisTimer = null;
    _isRunning = false;
    _stateController.close();
  }

  /// Ejecuta una escritura a SQLite (`insertActivitySession`/`logAlert`) con
  /// `await` real y la encola para reintento si falla, en vez de dejar que la
  /// excepción se pierda como un `Future` sin manejar. También intenta vaciar
  /// la cola de reintentos previa antes de fallar de nuevo, para no perder el
  /// orden de las ventanas cuando el almacenamiento se recupera.
  Future<void> _persistWithRetry(Future<void> Function() write) async {
    if (_pendingWrites.isNotEmpty) {
      final queued = List<Future<void> Function()>.from(_pendingWrites);
      _pendingWrites.clear();
      for (final queuedWrite in queued) {
        try {
          await queuedWrite();
        } catch (_) {
          if (_pendingWrites.length < _maxPendingWrites) {
            _pendingWrites.add(queuedWrite);
          }
        }
      }
    }
    try {
      await write();
    } catch (e, st) {
      AppLog.d('[FogEngine] Fallo al persistir en SQLite, se encola para reintento: $e\n$st');
      if (_pendingWrites.length >= _maxPendingWrites) {
        AppLog.d('[FogEngine] Cola de reintento llena ($_maxPendingWrites); se descarta el registro más antiguo.');
        _pendingWrites.removeAt(0);
      }
      _pendingWrites.add(write);
    }
  }

  Future<void> _analyzeWindow() async {
    if (_windowInFlight) return; // evita análisis superpuestos
    _windowInFlight = true;
    _windowsAnalyzed++;
    try {
      if (_magnitudes.isEmpty) return;

      final stopwatch = Stopwatch()..start();

      // Aislar el cálculo de varianza en un Isolate (no bloquea el UI).
      final samples = List<double>.from(_magnitudes);
      _magnitudes.clear();
      final variance = await compute(_computeVarianceOf, samples);

      // Vector promedio de la ventana para estimar orientación corporal.
      var sx = 0.0, sy = 0.0, sz = 0.0;
      final vectors = List<AccelerometerData>.from(_vectors);
      _vectors.clear();
      for (final v in vectors) {
        sx += v.x;
        sy += v.y;
        sz += v.z;
      }
      final count = vectors.isEmpty ? 1 : vectors.length;
      final orientation = inferBodyOrientation(sx / count, sy / count, sz / count);

      // Alimentar el Filtro Clínico (immobile = varianza baja).
      // Si la varianza es prácticamente nula (< 0.0001) y no hay lectura de pulso,
      // el reloj está inmóvil sobre una mesa (Off-Body). No sumar inactividad.
      final isOffBodyTable = (variance < 0.0001) && (_latestHeartRate == null || _latestHeartRate! <= 0);
      final insufficientSamples = samples.length < 5;

      final immobile = variance < _varianceThreshold && !isOffBodyTable && !insufficientSamples;
      if (immobile) {
        _consecutiveActiveWindows = 0;
      } else {
        _consecutiveActiveWindows++;
      }

      final isSustainedActive = _consecutiveActiveWindows >= 4;

      _clinicalClassifier.feed(
        immobile: immobile,
        orientation: orientation,
        heartRate: _latestHeartRate,
        hrv: _latestHrv,
        sustainedActive: isSustainedActive,
      );

      final suppressed = _clinicalClassifier.state == SedentaryState.clinicalRest ||
          _clinicalClassifier.state == SedentaryState.sleep;

      ActivityStatus status;
      if (immobile && !suppressed) {
        if (_activeWindows > 0) {
          final activeMins = max(1, _activeWindows ~/ 2);
          final activeStart = _activeStartTime;
          final activeEnd = DateTime.now().toIso8601String();
          await _persistWithRetry(() => SecureDatabaseService.instance.insertActivitySession(
                activeStart,
                activeEnd,
                'active',
                activeMins,
              ));
          _activeWindows = 0;
        }
        _inactiveWindows++;
        status = ActivityStatus.idle;
      } else if (immobile && suppressed) {
        if (_activeWindows > 0) {
          final activeMins = max(1, _activeWindows ~/ 2);
          final activeStart = _activeStartTime;
          final activeEnd = DateTime.now().toIso8601String();
          await _persistWithRetry(() => SecureDatabaseService.instance.insertActivitySession(
                activeStart,
                activeEnd,
                'active',
                activeMins,
              ));
          _activeWindows = 0;
        }
        _inactiveWindows = 0;
        status = ActivityStatus.idle;
      } else if (!isSustainedActive) {
        // Movimiento aislado de brazo o gesticulación sentado (< 2 min / < 4 ventanas de 30s):
        // NO resetea _inactiveWindows ni destruye la sesión inactiva previa.
        status = ActivityStatus.idle;
      } else {
        // Movimiento activo sostenido real (>= 2 min / >= 4 ventanas de 30s): se cierra la sesión inactiva previa.
        if (_inactiveWindows > 0) {
          final idleMins = max(1, _inactiveWindows ~/ 2);
          final idleStart = _sessionStartTime;
          final idleEnd = DateTime.now().toIso8601String();
          await _persistWithRetry(() => SecureDatabaseService.instance.insertActivitySession(
                idleStart,
                idleEnd,
                'idle',
                idleMins,
              ));
          _sessionStartTime = DateTime.now().toIso8601String();
        }
        if (_activeWindows == 0) {
          _activeStartTime = DateTime.now().toIso8601String();
        }
        _activeWindows++;
        _inactiveWindows = 0;
        _lastMovement = DateTime.now();
        status = ActivityStatus.active;

        // Persistir sesión activa acumulada
        final currentActiveMins = _activeWindows ~/ 2;
        if (currentActiveMins >= 1) {
          final activeStart = _activeStartTime;
          final activeEnd = DateTime.now().toIso8601String();
          await _persistWithRetry(() => SecureDatabaseService.instance.insertActivitySession(
                activeStart,
                activeEnd,
                'active',
                currentActiveMins,
              ));
        }
      }

      // Procesamiento de alerta tras N ventanas inactivas consecutivas.
      final thresholdMinutes = _alertThresholdWindows ~/ _minutesPerWindow;
      if (_inactiveWindows >= _alertThresholdWindows) {
        status = ActivityStatus.alertTriggered;
        await _triggerAlert(thresholdMinutes);
        _inactiveWindows = 0;
      }

      _lastWindowAnalysis = stopwatch.elapsed;

      if (!_stateController.isClosed) {
        _stateController.add(FogState(
          status: status,
          inactiveMinutes: _inactiveWindows ~/ 2,
          lastMovement: _lastMovement,
          clinicalState: clinicalState,
          reposoVerificado: reposoVerificado,
          restMinutes: restMinutes,
          hasPendingWrites: hasPendingWrites,
        ));
      }
    } catch (e, st) {
      AppLog.d('[FogEngine] Error analizando ventana: $e\n$st');
    } finally {
      _windowInFlight = false;
    }
  }

  Future<void> _triggerAlert(int minutes) async {
    _alertsTriggered++;
    _notificationService.showInactivityAlert(minutes);

    final alertTimestamp = DateTime.now().toIso8601String();
    await _persistWithRetry(
      () => SecureDatabaseService.instance.logAlert(alertTimestamp, minutes, false),
    );

    final sessionStart = _sessionStartTime;
    final sessionEnd = DateTime.now().toIso8601String();
    await _persistWithRetry(
      () => SecureDatabaseService.instance.insertActivitySession(
        sessionStart,
        sessionEnd,
        'alert',
        minutes,
      ),
    );
    _sessionStartTime = DateTime.now().toIso8601String();
  }

  /// Umbral de alerta actual en minutos.
  int get alertThresholdMinutes => _alertThresholdWindows ~/ _minutesPerWindow;

  /// Configura el umbral de alerta en minutos (recalcula las ventanas de 30s).
  void setAlertThreshold(int minutes) {
    _alertThresholdWindows = (minutes * _minutesPerWindow).clamp(1, 10000);
    _inactiveWindows = 0;
  }

  static ClinicalState _toUiState(SedentaryState s) {
    switch (s) {
      case SedentaryState.clinicalRest:
        return ClinicalState.clinicalRest;
      case SedentaryState.sleep:
        return ClinicalState.sleep;
      case SedentaryState.sedentaryWork:
        return ClinicalState.sedentaryWork;
    }
  }
}