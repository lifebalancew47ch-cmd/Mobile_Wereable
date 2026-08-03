import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/fog_engine.dart';
import '../core/network/api_client.dart';
import '../models/fog_state.dart';
import '../features/gamification/data/gamification_api_service.dart';
import '../features/ingestion/data/ingestion_api_service.dart';
import '../features/notifications/data/datasources/notifications_api_service.dart';
import 'wearable_communication_service.dart';
import 'notification_service.dart';
import 'watch_service.dart';
import 'offline_sync_service.dart';
import 'connectivity_monitor.dart';
import 'device_registration_service.dart';
import 'device_identity_service.dart';
import 'location_service.dart';
import 'dart:ui';
import 'dart:async';

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

    final wearableService = WearableCommunicationService();
    final fogEngine = FogEngine(wearableService, notificationService);

    fogEngine.start();

    // Alimenta el Filtro Clínico con FC/HRV del wearable, si están presentes.
    wearableService.sensorStream.listen((sample) {
      fogEngine.feedClinicalSample(
        heartRate: sample.heartRate > 0 ? sample.heartRate : null,
        hrv: sample.hrv > 0 ? sample.hrv : null,
      );
    });

    // Sincronización Offline-First hacia la nube (Ingestion + Gamification).
    final ingestionApi = IngestionApiService(
      buildSecureDio(_urlFromEnv('https://ingestion-service-fouo.onrender.com/api/v1')),
    );
    final gamificationApi = GamificationApiService(
      buildSecureDio(_urlFromEnv('https://gamification-service-9o3z.onrender.com/api/v1')),
    );
    final offlineSync = OfflineSyncService(
      ingestionApi: ingestionApi,
      gamificationApi: gamificationApi,
    );
    final connectivity = ConnectivityMonitor();
    // Sincroniza cada 15 minutos y de inmediato al recuperar conexión.
    offlineSync.startPeriodicSync(
      interval: const Duration(minutes: 15),
      connectivityStream: connectivity.onlineStream,
    );

    // GPS solo ante cambios drásticos de estado (alerta de sedentarismo).
    fogEngine.stateStream.listen((state) {
      if (state.status == ActivityStatus.alertTriggered) {
        unawaited(_captureGpsAndSend(ingestionApi));
      }
    });

    // Registro del dispositivo (push remoto FCM), no-bloqueante.
    final notificationsApi = NotificationsApiService(
      buildSecureDio(_defaultNotificationsUrl()),
    );
    final deviceRegistration = DeviceRegistrationService(
      notificationsApi: notificationsApi,
    );
    deviceRegistration.registerDevice();

    final watchService = WatchService();
    watchService.startPeriodicSync();
    
    // Si la pantalla está apagada y no hay datos en 30 minutos, reducir el polling
    var lastDataTime = DateTime.now();
    wearableService.accelerometerStream.listen((_) {
      lastDataTime = DateTime.now();
    });

    Timer.periodic(const Duration(minutes: 30), (timer) {
      if (DateTime.now().difference(lastDataTime).inMinutes >= 30) {
        watchService.startPeriodicSync(interval: const Duration(minutes: 30));
      } else {
        watchService.startPeriodicSync(interval: const Duration(minutes: 5));
      }
    });
  }

  static String _defaultNotificationsUrl() =>
      _urlFromEnv('https://lifebalance-notifications-api.onrender.com/api/v1');

  /// Captura GPS bajo demanda (solo en alertas) y lo envía al Ingestion
  /// Service como evento asíncrono. No bloquea ni interrumpe el motor.
  static Future<void> _captureGpsAndSend(IngestionApiService ingestionApi) async {
    final gps = await LocationService().capture();
    if (gps == null) return;
    try {
      await ingestionApi.postEvent(
        deviceId: await DeviceIdentityService().getDeviceId(),
        eventType: 'GPS_COORDINATE',
        source: 'Mobile',
        occurredAtUtc: gps.capturedAt,
        payload: {'latitude': gps.latitude, 'longitude': gps.longitude},
        idempotencyKey: 'gps-${gps.capturedAt.millisecondsSinceEpoch}',
      );
    } catch (e) {
      debugPrint('[GPS] Envío diferido (cola local).');
    }
  }

  /// El aislado de segundo plano no tiene acceso a `dotenv` (cargado en el
  /// aislado principal), por lo que usa las URLs desplegadas por defecto.
  static String _urlFromEnv(String fallback) => fallback;
}
