import 'package:dio/dio.dart';
import '../../domain/entities/dashboard_models.dart';

class DashboardApiService {
  final Dio _dio;

  DashboardApiService(this._dio);

  Future<DashboardKpis> getIndividualKpis() async {
    final data = await _getData('/dashboard/individual/kpis');
    return DashboardKpis.fromJson(data);
  }

  Future<DashboardSummary> getIndividualSummary() async {
    final data = await _getData('/dashboard/individual/summary');
    return DashboardSummary.fromJson(data);
  }

  Future<DashboardProgress> getIndividualProgress() async {
    final data = await _getData('/dashboard/individual/progress');
    return DashboardProgress.fromJson(data);
  }

  Future<List<DashboardRecommendation>> getIndividualRecommendations() async {
    final data = await _getList('/dashboard/individual/recommendations');
    return data.map(DashboardRecommendation.fromJson).toList();
  }

  Future<DashboardBiometrics> getIndividualBiometrics() async {
    final data = await _getData('/dashboard/individual/biometrics');
    return DashboardBiometrics.fromJson(data);
  }

  Future<DashboardStatistics> getIndividualStatistics() async {
    final data = await _getData('/dashboard/individual/statistics');
    return DashboardStatistics.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getIndividualHeatmap() async {
    return _getList('/dashboard/individual/heatmap');
  }

  Future<List<Map<String, dynamic>>> getIndividualActivity() async {
    return _getList('/dashboard/individual/activity');
  }

  Future<Map<String, dynamic>> getIndividualGoals() async {
    return _getData('/dashboard/individual/goals');
  }

  Future<Map<String, dynamic>> getIndividualRewards() async {
    return _getData('/dashboard/individual/rewards');
  }

  /// Estado general del sistema (GET /dashboard/system, público).
  Future<Map<String, dynamic>> getSystem() async {
    return _getData('/dashboard/system');
  }

  /// Health check general (GET /dashboard/health, público).
  Future<Map<String, dynamic>> getHealth() async {
    return _getData('/dashboard/health');
  }

  /// Versión del sistema (GET /dashboard/version, público).
  Future<Map<String, dynamic>> getVersion() async {
    return _getData('/dashboard/version');
  }

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _dio.get(path);

      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        if (map['success'] == true && map['data'] is Map<String, dynamic>) {
          return map['data'] as Map<String, dynamic>;
        }
        return map;
      }

      throw Exception('Respuesta inesperada del servidor');
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Error de servidor';
        throw Exception(message);
      }
      throw Exception('Error de conexión');
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    try {
      final response = await _dio.get(path);
      if (response.data is List) {
        return response.data.whereType<Map<String, dynamic>>().toList();
      }
      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        if (map['data'] is List) {
          return (map['data'] as List).whereType<Map<String, dynamic>>().toList();
        }
      }
      return const [];
    } on DioException catch (e) {
      if (e.response != null) {
        final message = e.response?.data['message'] ?? 'Error de servidor';
        throw Exception(message);
      }
      throw Exception('Error de conexión');
    }
  }
}
