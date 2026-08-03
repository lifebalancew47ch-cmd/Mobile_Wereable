import 'package:flutter/foundation.dart';
import '../features/notifications/data/datasources/notifications_api_service.dart';
import 'device_identity_service.dart';

/// Provee el token FCM del dispositivo, o `null` si Firebase no está
/// configurado. Permite conmutar en el futuro a `firebase_messaging` sin
/// romper la integración actual.
abstract class FcmTokenProvider {
  Future<String?> getToken();
}

/// Implementación predictible por defecto: devuelve `null` cuando Firebase
/// Messaging no está inicializado, sin lanzar errores (no-op seguro).
class DefaultFcmTokenProvider implements FcmTokenProvider {
  @override
  Future<String?> getToken() async => null;
}

/// Registra el dispositivo en el Notifications & Alerts Service (push remoto).
///
/// Si no hay token FCM disponible (Firebase sin configurar), la operación se
/// omite silenciosamente: la app móvil nunca debe colgar por una dependencia
/// de notificaciones remotas.
class DeviceRegistrationService {
  final NotificationsApiService _notificationsApi;
  final DeviceIdentityService _deviceIdentity;
  final FcmTokenProvider _fcmTokenProvider;

  bool _registered = false;

  DeviceRegistrationService({
    required NotificationsApiService notificationsApi,
    DeviceIdentityService? deviceIdentity,
    FcmTokenProvider? fcmTokenProvider,
  })  : _notificationsApi = notificationsApi,
        _deviceIdentity = deviceIdentity ?? DeviceIdentityService(),
        _fcmTokenProvider = fcmTokenProvider ?? DefaultFcmTokenProvider();

  /// Intenta registrar el token FCM actual en la nube. No lanza: cualquier
  /// fallo (sin Firebase, sin red, backend caído) se trata como no-op.
  Future<void> registerDevice() async {
    if (_registered) return;
    try {
      final token = await _fcmTokenProvider.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[DeviceRegistration] FCM no disponible: se omite el registro.');
        return;
      }
      final deviceId = await _deviceIdentity.getDeviceId();
      await _notificationsApi.registerDevice(fcmToken: token, deviceId: deviceId);
      _registered = true;
    } catch (e) {
      debugPrint('[DeviceRegistration] No se pudo registrar: $e');
    }
  }
}