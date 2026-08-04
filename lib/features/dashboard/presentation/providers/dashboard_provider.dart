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
final individualDashboardDataProvider = FutureProvider<IndividualDashboardData>((ref) async {
  final api = ref.watch(dashboardApiServiceProvider);

  DashboardProgress? progress;
  DashboardBiometrics? biometrics;
  DashboardStatistics? statistics;
  var recommendations = <DashboardRecommendation>[];
  var heatmap = <Map<String, dynamic>>[];
  var activity = <Map<String, dynamic>>[];
  var goals = <String, dynamic>{};
  var rewards = <String, dynamic>{};

  try {
    progress = await api.getIndividualProgress();
  } catch (_) {}
  try {
    biometrics = await api.getIndividualBiometrics();
  } catch (_) {}
  try {
    statistics = await api.getIndividualStatistics();
  } catch (_) {}
  try {
    recommendations = await api.getIndividualRecommendations();
  } catch (_) {}
  try {
    heatmap = await api.getIndividualHeatmap();
  } catch (_) {}
  try {
    activity = await api.getIndividualActivity();
  } catch (_) {}
  try {
    goals = await api.getIndividualGoals();
  } catch (_) {}
  try {
    rewards = await api.getIndividualRewards();
  } catch (_) {}

  return IndividualDashboardData(
    progress: progress,
    recommendations: recommendations,
    biometrics: biometrics,
    statistics: statistics,
    heatmap: heatmap,
    activity: activity,
    goals: goals,
    rewards: rewards,
  );
});

