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

  /// Crea una alerta real en el backend (POST /alerts), en vez de dejarla
  /// solo en el registro local del dispositivo. Así queda visible en el
  /// dashboard web/admin y sincronizada entre dispositivos del usuario.
  ///
  /// ⚠️ `priority` (`AlertPriority`) es un enum entero (0-8) cuyos nombres no
  /// están confirmados en el spec de OpenAPI del backend (`docs/...` lo marca
  /// como "sin nombres confirmados"). Se manda además como string legible por
  /// si el backend lo acepta así; si el backend espera otro entero específico
  /// para "alta/media/baja", hay que ajustar [priority] con el equipo backend.
  Future<void> createAlert({
    required String userId,
    required String title,
    required String body,
    required String source,
    int priority = 1,
    String priorityLabel = 'medium',
  }) async {
    try {
      await _dio.post('/alerts', data: {
        'userId': userId,
        'title': title,
        'body': body,
        'source': source,
        'priority': priority,
        'priorityLabel': priorityLabel,
      });
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e.response?.data, 'Error al crear la alerta'));
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

  /// Marca una notificación como leída (PATCH /notifications/{id}/read).
  ///
  /// Nota: este endpoint es conocido por devolver `200 OK` con
  /// `{"success": false, ...}` aunque la operación sí se aplica (bug del
  /// backend de Notifications, confirmado comparando el estado antes/después).
  /// No afecta a este cliente porque `_patch` no inspecciona el flag
  /// `success`, solo el status HTTP.
  Future<void> markNotificationRead(String id) async {
    await _patch('/notifications/$id/read');
  }

  /// Archiva una notificación, es decir la "descarta" de la bandeja
  /// (PATCH /notifications/{id}/archive). Mismo aviso de `success` que arriba.
  Future<void> archiveNotification(String id) async {
    await _patch('/notifications/$id/archive');
  }

  /// Obtiene las preferencias de notificación (GET /preferences).
  ///
  /// [fallback] se usa para las claves que el backend no devuelva, de modo
  /// que una respuesta parcial no apague opciones que el usuario tenía
  /// activadas.
  Future<NotificationPreferences> getPreferences({
    NotificationPreferences fallback = NotificationPreferences.defaults,
  }) async {
    try {
      final response = await _dio.get('/preferences');
      return NotificationPreferences.fromJson(
        _extractMap(response.data),
        fallback: fallback,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(_extractErrorMessage(e.response?.data, 'Error al cargar preferencias'));
      }
      throw Exception('Error de conexión');
    }
  }

  /// Actualiza las preferencias de notificación (PUT /preferences).
  ///
  /// Devuelve las preferencias tal y como quedaron según la respuesta del
  /// servidor; si la respuesta viene vacía se asume que se guardó lo enviado.
  /// Lanza si el servidor responde con error, para que la UI pueda avisar.
  Future<NotificationPreferences> updatePreferences({
    required bool pushEnabled,
    required bool emailEnabled,
    required bool wearEnabled,
  }) async {
    final sent = NotificationPreferences(
      pushEnabled: pushEnabled,
      emailEnabled: emailEnabled,
      wearEnabled: wearEnabled,
    );
    try {
      final response = await _dio.put('/preferences', data: sent.toJson());
      final body = _extractMap(response.data);
      if (body.isEmpty) return sent;
      return NotificationPreferences.fromJson(body, fallback: sent);
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(
          _extractErrorMessage(e.response?.data, 'Error al actualizar preferencias'),
        );
      }
      throw Exception('Error de conexión');
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

  /// Normaliza respuestas que pueden venir planas (`{...}`) o envueltas
  /// (`{"data": {...}}`, `{"preferences": {...}}`).
  Map<String, dynamic> _extractMap(dynamic data) {
    if (data is! Map) return <String, dynamic>{};
    for (final key in const ['data', 'preferences', 'result']) {
      final nested = data[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return Map<String, dynamic>.from(data);
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
