/// Pausa activa registrada localmente (Módulo de Gamificación, Sección 2.C).
class ActiveBreak {
  final int? id;
  final DateTime timestamp;
  final String type; // 'stretch' | 'walk'
  final int durationMinutes;
  final int stepsTaken;
  final int points;
  final bool completed;

  ActiveBreak({
    this.id,
    required this.timestamp,
    required this.type,
    required this.durationMinutes,
    required this.stepsTaken,
    required this.points,
    required this.completed,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'duration_minutes': durationMinutes,
      'steps_taken': stepsTaken,
      'points': points,
      'completed': completed ? 1 : 0,
      'synced_to_cloud': 0,
    };
  }

  factory ActiveBreak.fromMap(Map<String, dynamic> map) {
    return ActiveBreak(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      type: map['type'],
      durationMinutes: (map['duration_minutes'] as num?)?.toInt() ?? 0,
      stepsTaken: (map['steps_taken'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
      completed: (map['completed'] as num? ?? 0) == 1,
    );
  }
}