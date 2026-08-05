import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import '../../data/datasources/dashboard_api_service.dart';
import '../../domain/entities/dashboard_models.dart';

final dashboardApiServiceProvider = Provider((ref) {
  final dio = ref.watch(dashboardApiClientProvider);
  return DashboardApiService(dio);
});

class DashboardData {
  final DashboardSummary? summary;
  final DashboardKpis? kpis;
  final String? error;

  DashboardData({this.summary, this.kpis, this.error});

  bool get hasError => error != null;
}

final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final api = ref.watch(dashboardApiServiceProvider);

  DashboardSummary? summary;
  DashboardKpis? kpis;
  String? error;

  try {
    summary = await api.getIndividualSummary();
  } catch (e) {
    error = e.toString().replaceAll('Exception: ', '');
  }

  try {
    kpis = await api.getIndividualKpis();
  } catch (e) {
    error ??= e.toString().replaceAll('Exception: ', '');
  }

  if (summary == null && kpis == null) {
    error ??= 'No se pudo cargar el dashboard';
  }

  return DashboardData(summary: summary, kpis: kpis, error: error);
});

class IndividualDashboardData {
  final DashboardProgress? progress;
  final List<DashboardRecommendation> recommendations;
  final DashboardBiometrics? biometrics;
  final DashboardStatistics? statistics;
  final List<Map<String, dynamic>> heatmap;
  final List<Map<String, dynamic>> activity;
  final Map<String, dynamic> goals;
  final Map<String, dynamic> rewards;

  const IndividualDashboardData({
    this.progress,
    this.recommendations = const [],
    this.biometrics,
    this.statistics,
    this.heatmap = const [],
    this.activity = const [],
    this.goals = const {},
    this.rewards = const {},
  });

  bool get hasAnyData =>
      progress != null ||
      biometrics != null ||
      statistics != null ||
      recommendations.isNotEmpty;
}

/// Datos extendidos del dashboard individual (progreso, recomendaciones,
/// biometría, estadísticas, heatmap, actividad, metas y recompensas).
/// Todas las llamadas se ejecutan en paralelo para minimizar el tiempo de carga.
final individualDashboardDataProvider = FutureProvider<IndividualDashboardData>((ref) async {
  final api = ref.watch(dashboardApiServiceProvider);

  // Ejecutar todas las llamadas en paralelo — el tiempo total queda acotado
  // al de la llamada más lenta, en lugar de la suma de las 8.
  final results = await Future.wait([
    api.getIndividualProgress().then<Object?>((v) => v).catchError((_) => null),
    api.getIndividualBiometrics().then<Object?>((v) => v).catchError((_) => null),
    api.getIndividualStatistics().then<Object?>((v) => v).catchError((_) => null),
    api.getIndividualRecommendations().then<Object?>((v) => v).catchError((_) => <DashboardRecommendation>[]),
    api.getIndividualHeatmap().then<Object?>((v) => v).catchError((_) => <Map<String, dynamic>>[]),
    api.getIndividualActivity().then<Object?>((v) => v).catchError((_) => <Map<String, dynamic>>[]),
    api.getIndividualGoals().then<Object?>((v) => v).catchError((_) => <String, dynamic>{}),
    api.getIndividualRewards().then<Object?>((v) => v).catchError((_) => <String, dynamic>{}),
  ]);

  return IndividualDashboardData(
    progress: results[0] as DashboardProgress?,
    biometrics: results[1] as DashboardBiometrics?,
    statistics: results[2] as DashboardStatistics?,
    recommendations: (results[3] as List?)?.cast<DashboardRecommendation>() ?? [],
    heatmap: (results[4] as List?)?.cast<Map<String, dynamic>>() ?? [],
    activity: (results[5] as List?)?.cast<Map<String, dynamic>>() ?? [],
    goals: (results[6] as Map?)?.cast<String, dynamic>() ?? {},
    rewards: (results[7] as Map?)?.cast<String, dynamic>() ?? {},
  );
});

