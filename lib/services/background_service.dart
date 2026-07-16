import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import '../core/fog_engine.dart';
import 'wearable_communication_service.dart';
import 'notification_service.dart';
import 'watch_service.dart';
import 'dart:ui';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
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

    final watchService = WatchService();
    watchService.startPeriodicSync();
  }
}
