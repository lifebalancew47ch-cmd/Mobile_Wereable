import 'package:health/health.dart';
import '../models/vital_sign.dart';

/// Interfaz para el servicio de integración con Health Connect (Sección 6.1).
/// Responsable de la comunicación con Samsung Health / Health Connect API.
abstract class IWatchService {
  /// Solicita los 4 permisos específicos de health.READ_... (Sección 10).
  Future<bool> requestPermissions();

  /// Verifica la disponibilidad de Health Connect en el dispositivo Android 13+.
  Future<bool> isApiAvailable();

  /// Realiza la sincronización de métricas cada 5 minutos (Sección 15.2).
  /// Retorna un objeto [VitalSign] con la data consolidada del wearable.
  Future<VitalSign?> getLatestMetrics();
}

class WatchService implements IWatchService {
  // Implementación de la interfaz mediante el paquete health ^10.2.0
  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool> isApiAvailable() async => false;

  @override
  Future<VitalSign?> getLatestMetrics() async => null;
}
