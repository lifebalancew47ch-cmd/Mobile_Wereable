class VitalSign {
  final DateTime timestamp;
  final double heartRate;
  final double hrv;
  final double spo2;
  final int steps;

  VitalSign({
    required this.timestamp,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.steps,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'heart_rate': heartRate,
      'hrv': hrv,
      'spo2': spo2,
      'steps': steps,
    };
  }

  factory VitalSign.fromMap(Map<String, dynamic> map) {
    return VitalSign(
      timestamp: DateTime.parse(map['timestamp']),
      heartRate: map['heart_rate'],
      hrv: map['hrv'],
      spo2: map['spo2'],
      steps: map['steps'],
    );
  }
}
