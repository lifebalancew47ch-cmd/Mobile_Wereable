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
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': heartRate,
      'hrv': hrv,
      'spo2': spo2,
      'steps': steps,
      'synced_to_cloud': 0, // Default for new records
    };
  }

  factory VitalSign.fromMap(Map<String, dynamic> map) {
    return VitalSign(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      heartRate: map['heart_rate']?.toDouble() ?? 0.0,
      hrv: map['hrv']?.toDouble() ?? 0.0,
      spo2: map['spo2']?.toDouble() ?? 0.0,
      steps: map['steps']?.toInt() ?? 0,
      isSedentaryRisk: false, // Default or map['is_sedentary_risk'] == 1
    );
  }
}
