import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }
  }

  Future<void> showInactivityAlert(
    int minutes, {
    bool enableSound = true,
    bool critical = false,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'inactivity_alert_channel',
      'Inactivity Alerts',
      channelDescription: 'Alerts you when you have been inactive for too long',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'LifeBalance Alert',
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      playSound: enableSound,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      '¡Hora de moverse!',
      'Has estado inactivo por $minutes minutos. Te sugerimos realizar una pausa activa.',
      platformChannelSpecifics,
    );
  }

  /// Muestra una notificación local a partir de un push remoto (FCM) recibido
  /// mientras la app está en primer plano. Android/iOS solo muestran solos
  /// los mensajes `notification` cuando la app está en background/cerrada;
  /// en foreground hay que mostrarlos manualmente, si no el usuario nunca se
  /// entera de que llegó algo del backend (gamificación, reportes, alertas
  /// médicas, etc.) mientras tiene la app abierta.
  Future<void> showRemoteNotification({
    required String title,
    required String body,
    int id = 2001,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'remote_push_channel',
      'Avisos del servidor',
      channelDescription: 'Notificaciones y alertas enviadas desde el backend de LifeBalance',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id,
      title.isEmpty ? 'LifeBalance' : title,
      body,
      platformChannelSpecifics,
    );
  }

  /// Programa una notificación de recordatorio a la hora indicada.
  Future<void> scheduleReminder({
    required int hour,
    required int minute,
    int id = 1001,
    String title = 'Recordatorio de actividad',
    String body = 'Es momento de una pausa activa. ¡Muévete 5 minutos!',
  }) async {
    final now = DateTime.now();
    var scheduledAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduledAt.isAfter(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'activity_reminder_channel',
      'Activity Reminders',
      channelDescription: 'Scheduled activity reminders',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancela un recordatorio programado.
  Future<void> cancelReminder({int id = 1001}) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
