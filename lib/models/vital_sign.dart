/// Modelo de datos para Signos Vitales basado en la Sección 12 del documento técnico.
/// Representa la estructura de la tabla 'vital_signs' en SQLite.
class VitalSign {
  final int? id;
  final DateTime timestamp;
  final double heartRate;      // Sección 6.1: Latidos por minuto (bpm)
  final double hrv;            // Sección 6.1: Variabilidad de frecuencia cardíaca (ms)
  final double spo2;           // Sección 6.1: Saturación de oxígeno (%)
  final int steps;             // Sección 6.1: Pasos acumulados
  final bool isSedentaryRisk;  // Sección 15.4: Resultado del análisis Fog

  VitalSign({
    this.id,
    required this.timestamp,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.steps,
    required this.isSedentaryRisk,
  });

  // Estructura para persistencia en SQLite (Sección 7)
  Map<String, dynamic> toMap() => {};
  factory VitalSign.fromMap(Map<String, dynamic> map) => VitalSign(
    timestamp: DateTime.now(),
    heartRate: 0,
    hrv: 0,
    spo2: 0,
    steps: 0,
    isSedentaryRisk: false,
  );
}
