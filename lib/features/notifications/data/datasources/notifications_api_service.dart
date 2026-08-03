import 'package:dio/dio.dart';
import '../../domain/entities/notification_item.dart';

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
        final message = e.response?.data['message'] ?? 'Error al cargar notificaciones';
        throw Exception(message);
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
      final message = e.response?.data?['message'];
      throw Exception(message?.toString() ?? 'Error al registrar el dispositivo');
    }
  }
}
