enum ActivityStatus { active, idle, alertTriggered }

/// Estado clínico de inactividad informado por el [Filtro Clínico].
enum ClinicalState { sedentaryWork, clinicalRest, sleep }

class FogState {
  final ActivityStatus status;
  final int inactiveMinutes;
  final DateTime lastMovement;

  /// Estado clínico del Filtro de Falsos Positivos (Sección 2.B).
  final ClinicalState clinicalState;

  /// `true` cuando el reposo clínico fue verificado (steady-state).
  final bool reposoVerificado;

  /// Minutos acumulados de reposo clínico (si aplica).
  final int restMinutes;

  FogState({
    required this.status,
    required this.inactiveMinutes,
    required this.lastMovement,
    this.clinicalState = ClinicalState.sedentaryWork,
    this.reposoVerificado = false,
    this.restMinutes = 0,
  });

  FogState copyWith({
    ActivityStatus? status,
    int? inactiveMinutes,
    DateTime? lastMovement,
    ClinicalState? clinicalState,
    bool? reposoVerificado,
    int? restMinutes,
  }) {
    return FogState(
      status: status ?? this.status,
      inactiveMinutes: inactiveMinutes ?? this.inactiveMinutes,
      lastMovement: lastMovement ?? this.lastMovement,
      clinicalState: clinicalState ?? this.clinicalState,
      reposoVerificado: reposoVerificado ?? this.reposoVerificado,
      restMinutes: restMinutes ?? this.restMinutes,
    );
  }
}