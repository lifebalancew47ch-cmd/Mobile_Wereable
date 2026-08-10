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

  /// El backend envuelve la lista en `{userId, recommendations: [...]}`,
  /// no la devuelve como arreglo directo — por eso se usa `_getData` y se
  /// desenvuelve `recommendations` a mano en vez de `_getList`.
  Future<List<DashboardRecommendation>> getIndividualRecommendations() async {
    final data = await _getData('/dashboard/individual/recommendations');
    final list = data['recommendations'] as List? ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(DashboardRecommendation.fromJson)
        .toList();
  }

  /// El backend envuelve el objeto en `{userId, biometrics: {...}}`.
  Future<DashboardBiometrics> getIndividualBiometrics() async {
    final data = await _getData('/dashboard/individual/biometrics');
    final biometrics = data['biometrics'] as Map<String, dynamic>? ?? data;
    return DashboardBiometrics.fromJson(biometrics);
  }

  Future<DashboardStatistics> getIndividualStatistics() async {
    final data = await _getData('/dashboard/individual/statistics');
    return DashboardStatistics.fromJson(data);
  }

  /// El backend envuelve el arreglo en `{userId, hourlyHeatmap: [24 ints]}`.
  Future<List<int>> getIndividualHeatmap() async {
    final data = await _getData('/dashboard/individual/heatmap');
    final list = data['hourlyHeatmap'] as List? ?? const [];
    return list.map((e) => (e as num?)?.toInt() ?? 0).toList();
  }

  /// El backend devuelve un único snapshot diario (`{userId, activity: {...}}`),
  /// no un feed de eventos — de ahí el tipo `DashboardActivitySnapshot?`
  /// en vez de una lista.
  Future<DashboardActivitySnapshot?> getIndividualActivity() async {
    final data = await _getData('/dashboard/individual/activity');
    final activity = data['activity'] as Map<String, dynamic>?;
    if (activity == null) return null;
    return DashboardActivitySnapshot.fromJson(activity);
  }

  /// El backend devuelve una lista de retos (`{userId, goals: [...]}`), no
  /// un target fijo de pasos/minutos.
  Future<List<DashboardChallenge>> getIndividualGoals() async {
    final data = await _getData('/dashboard/individual/goals');
    final list = data['goals'] as List? ?? const [];
    return list.whereType<Map<String, dynamic>>().map(DashboardChallenge.fromJson).toList();
  }

  /// El backend envuelve el objeto en `{userId, rewards: {...}}`.
  Future<DashboardRewards> getIndividualRewards() async {
    final data = await _getData('/dashboard/individual/rewards');
    final rewardsMap = (data['rewards'] as Map?)?.cast<String, dynamic>() ?? data;
    return DashboardRewards.fromJson(rewardsMap);
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
}
