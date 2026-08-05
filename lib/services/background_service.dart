import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';
import '../core/network/api_client.dart';
import '../features/gamification/data/gamification_api_service.dart';
import '../features/ingestion/data/ingestion_api_service.dart';
import '../features/medical/data/medical_api_service.dart';
import '../features/sedentary/data/sedentary_api_service.dart';
import '../features/notifications/data/datasources/notifications_api_service.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
import 'connectivity_monitor.dart';
import 'device_registration_service.dart';
import 'dart:ui';

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Create the notification channel BEFORE starting the service,
    // so the foreground notification can be posted immediately.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'inactivity_alert_channel',
      'Inactivity Alerts',
      description: 'Alerts you when you have been inactive for too long',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'inactivity_alert_channel',
        initialNotificationTitle: 'LifeBalance',
        initialNotificationContent: 'Monitoreo de actividad en segundo plano',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    await service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });
      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    final notificationService = NotificationService();
    await notificationService.init();

    // NOTA: el FogEngine NO se instancia aquí. El aislado de segundo plano usa
    // un FlutterEngine propio (flutter_background_service) y el EventChannel
    // del wearable solo está registrado en el engine de la MainActivity, por lo
    // que un FogEngine aquí NUNCA recibiría datos del reloj. El motor real
    // corre en el aislado de la UI (arrancado de forma eager en main.dart),
    // que sigue vivo mientras este servicio mantiene el proceso en foreground.

    // Sincronización Offline-First hacia la nube (Ingestion + Gamification).
    final ingestionApi = IngestionApiService(
      buildSecureDio(_urlFromEnv('https://ingestion-service-fouo.onrender.com/api/v1')),
    );
    final gamificationApi = GamificationApiService(
      buildSecureDio(_urlFromEnv('https://gamification-service-9o3z.onrender.com/api/v1')),
    );
    final medicalApi = MedicalApiService(
      buildSecureDio(_urlFromEnv('https://medical-service-hb0v.onrender.com/api/v1')),
    );
    final sedentaryApi = SedentaryApiService(
      buildSecureDio(_urlFromEnv('https://sedentary-engine-service.onrender.com/api/v1')),
    );
    final offlineSync = OfflineSyncService(
      ingestionApi: ingestionApi,
      gamificationApi: gamificationApi,
      medicalApi: medicalApi,
      sedentaryApi: sedentaryApi,
    );
    final connectivity = ConnectivityMonitor();
    // Sincroniza cada 15 minutos y de inmediato al recuperar conexión.
    offlineSync.startPeriodicSync(
      interval: const Duration(minutes: 15),
      connectivityStream: connectivity.onlineStream,
    );

    // Registro del dispositivo (push remoto FCM), no-bloqueante.
    final notificationsApi = NotificationsApiService(
      buildSecureDio(_defaultNotificationsUrl()),
    );
    final deviceRegistration = DeviceRegistrationService(
      notificationsApi: notificationsApi,
    );
    deviceRegistration.registerDevice();
    deviceRegistration.registerDeviceOnTokenRefresh();
  }

  static String _defaultNotificationsUrl() =>
      _urlFromEnv('https://lifebalance-notifications-api.onrender.com/api/v1');

  /// El aislado de segundo plano no tiene acceso a `dotenv` (cargado en el
  /// aislado principal), por lo que usa las URLs desplegadas por defecto.
  static String _urlFromEnv(String fallback) => fallback;
}
