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
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vital_sign.dart';
import '../data/datasources/secure_database_service.dart';
import 'device_registration_service.dart';
import 'dart:ui';
import '../core/utils/app_log.dart';

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

    // C-01 (fix 07/08/2026): flutter_dotenv eliminado. Las constantes de URL
    // y los pins TLS se compilan en el binario con --dart-define, por lo que
    // están disponibles automáticamente en este isolate de background sin
    // necesidad de cargar ningún archivo en runtime.

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

    // NOTA: El análisis de sedentarismo en background lo maneja NativeFogEngine.kt
    // (en Kotlin) ya que el EventChannel del wearable está registrado en la MainActivity
    // y este aislado de background no tiene acceso a él. Cuando la UI de Flutter está
    // activa, el FogEngine de Dart toma el control y sincroniza el conteo con el nativo.

    // Sincronización Offline-First hacia la nube (Ingestion + Gamification).
    // C-01: se usan las constantes compiladas en lugar de dotenv.
    final ingestionApi = IngestionApiService(buildSecureDio(kIngestionApiUrl));
    final gamificationApi = GamificationApiService(buildSecureDio(kGamificationApiUrl));
    final medicalApi = MedicalApiService(buildSecureDio(kMedicalApiUrl));
    final sedentaryApi = SedentaryApiService(buildSecureDio(kSedentaryApiUrl));
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

    // Poll SharedPreferences for wearable data from Native Android
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('flutter.latest_wear_json');
        if (jsonString != null && jsonString.isNotEmpty) {
          try {
            final List<dynamic> batch = jsonDecode(jsonString);
            if (batch.isNotEmpty) {
              final lastData = batch.last as Map<String, dynamic>;
              final metrics = VitalSign(
                timestamp: DateTime.fromMillisecondsSinceEpoch((lastData['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch),
                heartRate: (lastData['heartRate'] as num?)?.toDouble() ?? 0,
                hrv: (lastData['hrv'] as num?)?.toDouble() ?? 0,
                spo2: (lastData['spo2'] as num?)?.toDouble() ?? 0,
                steps: (lastData['steps'] as num?)?.toInt() ?? 0,
                isSedentaryRisk: false,
              );
              
              // Avoid persisting empty placeholders
              if (metrics.heartRate > 0 || metrics.hrv > 0 || metrics.spo2 > 0 || metrics.steps > 0) {
                await SecureDatabaseService.instance.insertVitalSign(metrics);
                AppLog.d('[BackgroundService] VitalSign persistido → '
                    'hr=${metrics.heartRate} hrv=${metrics.hrv} '
                    'spo2=${metrics.spo2} steps=${metrics.steps}');
              } else {
                debugPrint('[BackgroundService] VitalSign descartado (todos en 0)');
              }
            }
          } catch (e) {
            AppLog.d('[BackgroundService] JSON corrupto en SharedPreferences: $e');
          }
          await prefs.remove('flutter.latest_wear_json');
        }
      } catch (e) {
        AppLog.d('[BackgroundService] Error polling wear data: $e');
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
    deviceRegistration.registerDeviceOnTokenRefresh();
  }

  // C-01: constante compilada desde --dart-define=NOTIFICATIONS_API_URL=...
  static String _defaultNotificationsUrl() => kNotificationsApiUrl;
}
