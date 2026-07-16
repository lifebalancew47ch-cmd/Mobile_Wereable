import 'dart:async';
import 'dart:math';
import '../models/fog_state.dart';
import '../services/wearable_communication_service.dart';
import '../services/notification_service.dart';
import '../data/datasources/secure_database_service.dart';

/// FogEngine es el motor principal de detección de sedentarismo.
/// Evalúa la varianza del acelerómetro en ventanas de 30 segundos.
/// Cada ventana representa 0.5 minutos; al llegar a 90 ventanas
/// inactivas consecutivas (= 45 minutos) dispara la alerta.
class FogEngine {
  final WearableCommunicationService _wearableService;
  final NotificationService _notificationService;

  StreamSubscription? _accelSub;
  Timer? _analysisTimer;

  // Acumula las magnitudes del vector aceleración en la ventana actual
  final List<double> _magnitudes = [];

  // Contador de ventanas inactivas consecutivas de 30s cada una
  // 90 ventanas × 30s = 2700s = 45 minutos
  int _inactiveWindows = 0;
  static const int _alertThresholdWindows = 90;

  DateTime _lastMovement = DateTime.now();
  String _sessionStartTime = DateTime.now().toIso8601String();

  final _stateController = StreamController<FogState>.broadcast();
  Stream<FogState> get stateStream => _stateController.stream;

  FogEngine(this._wearableService, this._notificationService);

  void start() {
    _accelSub = _wearableService.accelerometerStream.listen((data) {
      final double mag =
          sqrt(data.x * data.x + data.y * data.y + data.z * data.z);
      _magnitudes.add(mag);
    });

    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _analyzeWindow();
    });
  }

  void stop() {
    _accelSub?.cancel();
    _analysisTimer?.cancel();
    _stateController.close();
  }

  void _analyzeWindow() {
    if (_magnitudes.isEmpty) return;

    final double mean =
        _magnitudes.reduce((a, b) => a + b) / _magnitudes.length;
    final double variance =
        _magnitudes.map((m) => pow(m - mean, 2).toDouble()).reduce((a, b) => a + b) /
            _magnitudes.length;
    _magnitudes.clear();

    if (variance < 0.05) {
      // Ventana inactiva: acumular
      _inactiveWindows++;
    } else {
      // Hay movimiento: cerrar sesión inactiva si existía y resetear
      if (_inactiveWindows > 0) {
        SecureDatabaseService.instance.insertActivitySession(
          _sessionStartTime,
          DateTime.now().toIso8601String(),
          'idle',
          _inactiveWindows ~/ 2, // Convertir ventanas a minutos aprox.
        );
        _sessionStartTime = DateTime.now().toIso8601String();
      }
      _inactiveWindows = 0;
      _lastMovement = DateTime.now();
    }

    ActivityStatus status;
    if (_inactiveWindows == 0) {
      status = ActivityStatus.active;
    } else if (_inactiveWindows >= _alertThresholdWindows) {
      // 45 minutos de inactividad: disparar alerta
      status = ActivityStatus.alertTriggered;
      _triggerAlert();
      SecureDatabaseService.instance.insertActivitySession(
        _sessionStartTime,
        DateTime.now().toIso8601String(),
        'alert',
        45,
      );
      _sessionStartTime = DateTime.now().toIso8601String();
      _inactiveWindows = 0; // Reiniciar después de la alerta
    } else {
      status = ActivityStatus.idle;
    }

    _stateController.add(FogState(
      status: status,
      inactiveMinutes: _inactiveWindows ~/ 2,
      lastMovement: _lastMovement,
    ));
  }

  void _triggerAlert() {
    _notificationService.showInactivityAlert(45);
    SecureDatabaseService.instance
        .logAlert(DateTime.now().toIso8601String(), 45, false);
  }
}
