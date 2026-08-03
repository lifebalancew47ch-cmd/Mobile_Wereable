import '../../../data/datasources/secure_database_service.dart';
import '../../../models/active_break.dart';

/// Resultado de una pausa activa completada.
class ActiveBreakResult {
  final ActiveBreak activeBreak;
  final int pointsAwarded;

  ActiveBreakResult(this.activeBreak, this.pointsAwarded);
}

/// Módulo de Gamificación y Pausas Activas (Sección 2.C).
///
/// Al dispararse la Alerta Inteligente se ofrecen micro-rutinas:
/// * **Tipo A (Estiramiento)**: rutina guiada en pantalla de 2 minutos.
/// * **Tipo B (Pasos):** caminar 200 pasos consecutivos, verificado con el
///   podómetro.
///
/// Al completarse, se registra localmente la pausa activa con sus puntos; la
/// sincronización con la nube la realiza el [OfflineSyncService].
class ActiveBreakService {
  static const int stretchPoints = 50;
  static const int walkPoints = 100;
  static const int stretchMinutes = 2;
  static const int walkRequiredSteps = 200;

  final SecureDatabaseService _db;

  ActiveBreakService([SecureDatabaseService? db])
      : _db = db ?? SecureDatabaseService.instance;

  /// Rutina Tipo A (estiramiento, 2 minutos), con objetivo de pasos 0.
  Future<ActiveBreakResult> completeStretch({int minutes = stretchMinutes}) async {
    final points = stretchPoints;
    final break_ = ActiveBreak(
      timestamp: DateTime.now(),
      type: 'stretch',
      durationMinutes: minutes,
      stepsTaken: 0,
      points: points,
      completed: true,
    );
    await _db.insertActiveBreak(break_);
    return ActiveBreakResult(break_, points);
  }

  /// Rutina Tipo B (caminar [steps] pasos, mínimo 200). Si no se alcanza el
  /// objetivo no se registra como pausa completada ni se otorgan puntos.
  Future<ActiveBreakResult?> completeWalk({
    required int steps,
    int durationMinutes = 5,
  }) async {
    if (steps < walkRequiredSteps) return null;
    final break_ = ActiveBreak(
      timestamp: DateTime.now(),
      type: 'walk',
      durationMinutes: durationMinutes,
      stepsTaken: steps,
      points: walkPoints,
      completed: true,
    );
    await _db.insertActiveBreak(break_);
    return ActiveBreakResult(break_, walkPoints);
  }

  Future<List<ActiveBreak>> recentBreaks({int limit = 20}) =>
      _db.getActiveBreaks(limit: limit);
}