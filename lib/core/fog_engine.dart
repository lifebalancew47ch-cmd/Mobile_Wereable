import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/fog_state.dart';
import '../services/notification_service.dart';
import '../data/datasources/secure_database_service.dart';

/// FogEngine is the main algorithms engine for sedentary detection.
/// It evaluates accelerometer variance in 30-second windows.
/// (Sección 5 of the PDF Technical Specification).
class FogEngine {
  final NotificationService _notificationService;

  StreamSubscription? _accelSub;
  Timer? _analysisTimer;

  // Accummulates acceleration vector magnitudes in the current window
  final List<double> _magnitudes = [];

  // Counter for consecutive inactive windows (30s each)
  // 90 windows × 30s = 2700s = 45 minutes
  int _inactiveWindows = 0;
  static const int _alertThresholdWindows = 90;
  static const double _varianceThreshold = 0.05;

  DateTime _lastMovement = DateTime.now();
  String _sessionStartTime = DateTime.now().toIso8601String();

  final _stateController = StreamController<FogState>.broadcast();

  /// Stream that provides real-time updates of the Fog status to the UI.
  Stream<FogState> get stateStream => _stateController.stream;

  FogEngine(this._notificationService);

  /// Starts the engine listening to phone sensors (sensors_plus).
  void start() {
    // 1. Receive stream from sensors_plus (accelerometer)
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent event) {
      // 2. Calculate vector magnitude: |a| = sqrt(x² + y² + z²)
      final double mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _magnitudes.add(mag);
    });

    // 3. Analysis window: Group data in 30-second buffers
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _analyzeWindow();
    });
  }

  /// Stops the engine and releases resources.
  void stop() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _stateController.close();
  }

  void _analyzeWindow() {
    if (_magnitudes.isEmpty) return;

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

    // 6. Alert processing: Trigger after 90 consecutive inactive windows (45 minutes)
    if (_inactiveWindows >= _alertThresholdWindows) {
      status = ActivityStatus.alertTriggered;
      _triggerAlert();

      // Reset counter after alert or keep tracking?
      // PDF says "al llegar a 90 ventanas... cambiar el estado a alertTriggered"
      _inactiveWindows = 0;
    }

    // Notify listeners (UI) in real-time
    _stateController.add(FogState(
      status: status,
      inactiveMinutes: _inactiveWindows ~/ 2,
      lastMovement: _lastMovement,
    ));
  }

  void _triggerAlert() {
    // Notify user
    _notificationService.showInactivityAlert(45);

    // 7. Register in alerts_log table (Sección 16)
    SecureDatabaseService.instance.logAlert(
      DateTime.now().toIso8601String(),
      45,
      false
    );

    // Also insert an activity session record for the alert period
    SecureDatabaseService.instance.insertActivitySession(
      _sessionStartTime,
      DateTime.now().toIso8601String(),
      'alert',
      45,
    );
    _sessionStartTime = DateTime.now().toIso8601String();
  }
}
