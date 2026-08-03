import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../features/notifications/data/datasources/notifications_api_service.dart';
import 'device_identity_service.dart';

/// Provee el token FCM del dispositivo, o `null` si Firebase no está
/// configurado.
abstract class FcmTokenProvider {
  Future<String?> getToken();
}

/// Proveedor real de Firebase Messaging.
///
/// Degrada de forma segura a `null` cuando Firebase no está configurado
/// (falta `google-services.json`) o el permiso de notificaciones fue
/// denegado, sin lanzar errores: la app móvil nunca debe colgar por una
/// dependencia de notificaciones remotas.
class FirebaseMessagingFcmTokenProvider implements FcmTokenProvider {
  @override
  Future<String?> getToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('[DeviceRegistration] FCM no disponible: se omite el registro.');
      return null;
    }
  }
}

/// Implementación predictible por defecto: devuelve `null` sin lanzar
/// errores (no-op seguro). Sustituida en producción por
/// [FirebaseMessagingFcmTokenProvider].
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
        _fcmTokenProvider = fcmTokenProvider ?? FirebaseMessagingFcmTokenProvider();

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

  /// Vuelve a registrar el dispositivo cuando Firebase rota el token FCM
  /// (p. ej. reinstalación de la app o expiración del token). Los streams de
  /// Firebase solo existen si el plugin está configurado; en caso contrario
  /// esta operación es un no-op seguro.
  void registerDeviceOnTokenRefresh() {
    if (_registered) return;
    try {
      if (Firebase.apps.isEmpty) return;
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _registered = false;
        unawaited(_registerToken(newToken));
      });
    } catch (_) {
      // Sin Firebase configurado: no hay stream de refresh que escuchar.
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final deviceId = await _deviceIdentity.getDeviceId();
      await _notificationsApi.registerDevice(fcmToken: token, deviceId: deviceId);
      _registered = true;
    } catch (e) {
      debugPrint('[DeviceRegistration] No se pudo re-registrar: $e');
    }
  }
}