import 'dart:async';
import 'dart:math';
import '../models/fog_state.dart';
import '../services/notification_service.dart';
import '../services/wearable_communication_service.dart';
import '../data/datasources/secure_database_service.dart';

/// FogEngine is the main algorithms engine for sedentary detection.
/// It evaluates accelerometer variance in 30-second windows.
/// (Sección 5 of the PDF Technical Specification).
class FogEngine {
  final WearableCommunicationService _wearableService;
  final NotificationService _notificationService;

  StreamSubscription? _accelSub;
  Timer? _analysisTimer;

  // Accummulates acceleration vector magnitudes in the current window
  final List<double> _magnitudes = [];

  // Counter for consecutive inactive windows (30s each)
  // 90 windows × 30s = 2700s = 45 minutes (configurable)
  int _inactiveWindows = 0;
  int _alertThresholdWindows = 90;
  static const double _varianceThreshold = 0.05;
  static const int _minutesPerWindow = 2; // 2 windows por minuto (30s c/u)

  DateTime _lastMovement = DateTime.now();
  String _sessionStartTime = DateTime.now().toIso8601String();

  // Real engine metrics (exposed to the UI)
  int _samplesProcessed = 0;
  int _windowsAnalyzed = 0;
  int _alertsTriggered = 0;
  bool _isRunning = false;
  Duration _lastWindowAnalysis = Duration.zero;

  final _stateController = StreamController<FogState>.broadcast();

  /// Stream that provides real-time updates of the Fog status to the UI.
  Stream<FogState> get stateStream => _stateController.stream;

  /// Total accelerometer samples processed by the engine.
  int get samplesProcessed => _samplesProcessed;

  /// Number of 30-second analysis windows completed.
  int get windowsAnalyzed => _windowsAnalyzed;

  /// Number of inactivity alerts triggered.
  int get alertsTriggered => _alertsTriggered;

  /// Whether the engine is currently listening to the wearable.
  bool get isRunning => _isRunning;

  /// Duration of the last window analysis pass.
  Duration get lastWindowAnalysis => _lastWindowAnalysis;

  FogEngine(this._wearableService, this._notificationService);

  /// Starts the engine listening to accelerometer data from the wearable.
  void start() {
    if (_isRunning) return;

    // 1. Receive stream from the wearable accelerometer
    _accelSub = _wearableService.accelerometerStream.listen((AccelerometerData data) {
      // 2. Calculate vector magnitude: |a| = sqrt(x² + y² + z²)
      final double mag = sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
      // Security: descartar muestras no finitas (NaN/±Inf) provenientes de
      // sensores comprometidos; un único NaN convertiría la varianza en NaN y
      // rompería la detección de inactividad (alerta silenciosa).
      if (!mag.isFinite) return;
      _magnitudes.add(mag);
      _samplesProcessed++;
    });

    // 3. Analysis window: Group data in 30-second buffers
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _analyzeWindow();
    });

    _isRunning = true;
  }

  /// Pauses processing without releasing the state stream.
  void pause() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _accelSub = null;
    _analysisTimer = null;
    _isRunning = false;
  }

  /// Resumes processing after [pause] (keeps accumulated metrics).
  void resume() {
    if (_isRunning) return;
    _accelSub = _wearableService.accelerometerStream.listen((AccelerometerData data) {
      final double mag = sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
      if (!mag.isFinite) return;
      _magnitudes.add(mag);
      _samplesProcessed++;
    });
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _analyzeWindow();
    });
    _isRunning = true;
  }

  /// Stops the engine and releases resources.
  void stop() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _accelSub = null;
    _analysisTimer = null;
    _isRunning = false;
    _stateController.close();
  }

  void _analyzeWindow() {
    _windowsAnalyzed++;
    if (_magnitudes.isEmpty) return;

    final Stopwatch stopwatch = Stopwatch()..start();

    // 4. Calculate statistical variance (σ²) of the magnitude in this window
    final double mean = _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final double variance = _magnitudes.map((m) => pow(m - mean, 2).toDouble()).reduce((a, b) => a + b) / _magnitudes.length;
    _magnitudes.clear();

    ActivityStatus status;

    // 5. Detection logic: Compare variance against threshold
    if (variance < _varianceThreshold) {
      // State: idle (inactive)
      _inactiveWindows++;
      status = ActivityStatus.idle;
    } else {
      // State: active (in movement)
      if (_inactiveWindows > 0) {
        // Log the ended idle session to DB
        SecureDatabaseService.instance.insertActivitySession(
          _sessionStartTime,
          DateTime.now().toIso8601String(),
          'idle',
          _inactiveWindows ~/ 2,
        );
        _sessionStartTime = DateTime.now().toIso8601String();
      }
      _inactiveWindows = 0;
      _lastMovement = DateTime.now();
      status = ActivityStatus.active;
    }

    // 6. Alert processing: Trigger after N consecutive inactive windows
    final int thresholdMinutes = _alertThresholdWindows ~/ _minutesPerWindow;
    if (_inactiveWindows >= _alertThresholdWindows) {
      status = ActivityStatus.alertTriggered;
      _triggerAlert(thresholdMinutes);

      // Reset counter after alert or keep tracking?
      // PDF says "al llegar a 90 ventanas... cambiar el estado a alertTriggered"
      _inactiveWindows = 0;
    }

    _lastWindowAnalysis = stopwatch.elapsed;

    // Notify listeners (UI) in real-time
    _stateController.add(FogState(
      status: status,
      inactiveMinutes: _inactiveWindows ~/ 2,
      lastMovement: _lastMovement,
    ));
  }

  void _triggerAlert(int minutes) {
    _alertsTriggered++;

    // Notify user
    _notificationService.showInactivityAlert(minutes);

    // 7. Register in alerts_log table (Sección 16)
    SecureDatabaseService.instance.logAlert(
      DateTime.now().toIso8601String(),
      minutes,
      false
    );

    // Also insert an activity session record for the alert period
    SecureDatabaseService.instance.insertActivitySession(
      _sessionStartTime,
      DateTime.now().toIso8601String(),
      'alert',
      minutes,
    );
    _sessionStartTime = DateTime.now().toIso8601String();
  }

  /// Configura el umbral de alerta en minutos (recomputa las ventanas de 30s).
  void setAlertThreshold(int minutes) {
    _alertThresholdWindows = (minutes * _minutesPerWindow).clamp(1, 10000);
    _inactiveWindows = 0;
  }
}
