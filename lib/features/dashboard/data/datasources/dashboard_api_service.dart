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

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _dio.get(path);

      if (response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        if (map['success'] == true && map['data'] is Map<String, dynamic>) {
          return map['data'] as Map<String, dynamic>;
        }
        // La respuesta puede ser el objeto directamente sin wrapper.
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
