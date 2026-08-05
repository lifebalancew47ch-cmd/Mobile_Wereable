import 'package:dio/dio.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/alert_item.dart';

class NotificationsApiService {
  final Dio _dio;

  NotificationsApiService(this._dio);

  Future<List<NotificationItem>> getUserNotifications({int limit = 20}) async {
    try {
      final response = await _dio.get('/notifications/user', queryParameters: {'limit': limit});

      if (response.data is List) {
        final items = response.data as List;
        return items
            .whereType<Map<String, dynamic>>()
            .map((json) => NotificationItem.fromJson(json))
            .toList();
      }

      final data = response.data['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((json) => NotificationItem.fromJson(json))
            .toList();
      }

      return const [];
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(_extractErrorMessage(e.response?.data, 'Error al cargar notificaciones'));
      }
      throw Exception('Error de conexión');
    }
  }

  /// Registra el token FCM del dispositivo para recibir alertas preventivas
  /// basadas en los modelos de ML en la nube.
  Future<void> registerDevice({
    required String fcmToken,
    required String deviceId,
  }) async {
    try {
      await _dio.post('/notifications/register-device', data: {
        'deviceId': deviceId,
        'token': fcmToken,
        'platform': 'android',
      });
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data, 'Error al registrar el dispositivo'));
    }
  }

  /// Lista de alertas de sedentarismo (GET /alerts).
  Future<List<AlertItem>> getAlerts() async {
    try {
      final response = await _dio.get('/alerts');
      final items = _extractList(response.data);
      return items.map(AlertItem.fromJson).toList();
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(_extractErrorMessage(e.response?.data, 'Error al cargar alertas'));
      }
      throw Exception('Error de conexión');
    }
  }

  /// Marca una alerta como leída (PATCH /alerts/{id}/read).
  Future<void> markAlertRead(String id) async {
    await _patch('/alerts/$id/read');
  }

  /// Descarta una alerta (PATCH /alerts/{id}/dismiss).
  Future<void> dismissAlert(String id) async {
    await _patch('/alerts/$id/dismiss');
  }

  /// Obtiene las preferencias de notificación (GET /preferences).
  Future<NotificationPreferences> getPreferences() async {
    try {
      final response = await _dio.get('/preferences');
      final data = response.data is Map && response.data['data'] is Map
          ? response.data['data'] as Map<String, dynamic>
          : (response.data is Map ? response.data as Map<String, dynamic> : <String, dynamic>{});
      return NotificationPreferences.fromJson(data);
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(_extractErrorMessage(e.response?.data, 'Error al cargar preferencias'));
      }
      throw Exception('Error de conexión');
    }
  }

  /// Actualiza las preferencias de notificación (PUT /preferences).
  Future<void> updatePreferences({
    required bool pushEnabled,
    required bool emailEnabled,
    required bool wearEnabled,
  }) async {
    try {
      await _dio.put('/preferences', data: {
        'pushEnabled': pushEnabled,
        'emailEnabled': emailEnabled,
        'wearEnabled': wearEnabled,
      });
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data, 'Error al actualizar preferencias'));
    }
  }

  Future<void> _patch(String path) async {
    try {
      await _dio.patch(path);
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data, 'Error del servidor'));
    }
  }

  String _extractErrorMessage(dynamic data, String fallback) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    if (data is String && data.isNotEmpty && !data.contains('<!DOCTYPE')) {
      return data;
    }
    return fallback;
  }

  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
