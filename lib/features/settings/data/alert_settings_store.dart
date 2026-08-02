import 'package:shared_preferences/shared_preferences.dart';

import '../domain/alert_settings.dart';

/// Persistencia de [AlertSettings] en SharedPreferences.
/// Almacena la configuración local de alertas que aplica el FogEngine.
class AlertSettingsStore {
  static const _kInterval = 'alert_interval_minutes';
  static const _kStartHour = 'alert_start_hour';
  static const _kStartMinute = 'alert_start_minute';
  static const _kEndHour = 'alert_end_hour';
  static const _kEndMinute = 'alert_end_minute';
  static const _kCritical = 'alert_critical';
  static const _kSound = 'alert_sound';

  Future<AlertSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AlertSettings(
      intervalMinutes: prefs.getInt(_kInterval) ?? 45,
      startHour: prefs.getInt(_kStartHour) ?? 9,
      startMinute: prefs.getInt(_kStartMinute) ?? 0,
      endHour: prefs.getInt(_kEndHour) ?? 18,
      endMinute: prefs.getInt(_kEndMinute) ?? 0,
      criticalNotifications: prefs.getBool(_kCritical) ?? false,
      alertSound: prefs.getBool(_kSound) ?? true,
    );
  }

  Future<void> save(AlertSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kInterval, settings.intervalMinutes);
    await prefs.setInt(_kStartHour, settings.startHour);
    await prefs.setInt(_kStartMinute, settings.startMinute);
    await prefs.setInt(_kEndHour, settings.endHour);
    await prefs.setInt(_kEndMinute, settings.endMinute);
    await prefs.setBool(_kCritical, settings.criticalNotifications);
    await prefs.setBool(_kSound, settings.alertSound);
  }
}