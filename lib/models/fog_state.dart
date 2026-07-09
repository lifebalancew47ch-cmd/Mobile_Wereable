enum ActivityStatus { active, idle, alertTriggered }

class FogState {
  final ActivityStatus status;
  final int inactiveMinutes;
  final DateTime lastMovement;

  FogState({
    required this.status,
    required this.inactiveMinutes,
    required this.lastMovement,
  });

  FogState copyWith({
    ActivityStatus? status,
    int? inactiveMinutes,
    DateTime? lastMovement,
  }) {
    return FogState(
      status: status ?? this.status,
      inactiveMinutes: inactiveMinutes ?? this.inactiveMinutes,
      lastMovement: lastMovement ?? this.lastMovement,
    );
  }
}
