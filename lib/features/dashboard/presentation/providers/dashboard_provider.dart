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
