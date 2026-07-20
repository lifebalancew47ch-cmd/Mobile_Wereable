import '../models/vital_sign.dart';

/// Capa de Fog Computing para procesamiento local de datos (Sección 15.4).
/// Realiza el análisis de métricas sin depender de la nube.
abstract class IFogEngine {
  /// Analiza si los signos vitales indican un riesgo de sedentarismo.
  /// Lógica: HR < 60 bpm + 0 pasos (Sección 15.4).
  bool analyzeSedentaryRisk(double heartRate, int steps);

  /// Procesa un lote de datos para detectar anomalías en los signos vitales.
  Future<void> processLocalInference(VitalSign sign);
}

class FogEngine implements IFogEngine {
  @override
  bool analyzeSedentaryRisk(double heartRate, int steps) => false;

  @override
  Future<void> processLocalInference(VitalSign sign) async {}
}
