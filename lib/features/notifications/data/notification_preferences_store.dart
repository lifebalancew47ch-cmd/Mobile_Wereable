import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/alert_item.dart';

/// Persistencia local de [NotificationPreferences] en SharedPreferences.
///
/// Actúa como caché y como fuente de verdad offline: las preferencias se
/// guardan aquí SIEMPRE, aunque la sincronización con el backend
/// (`PUT /preferences`) falle. Así no se pierde la elección del usuario
/// cuando el servicio de notificaciones no responde.
///
/// No almacena credenciales ni tokens (esos viven en flutter_secure_storage).
class NotificationPreferencesStore {
  static const _kPush = 'notif_pref_push_enabled';
  static const _kEmail = 'notif_pref_email_enabled';
  static const _kWear = 'notif_pref_wear_enabled';
  static const _kPendingSync = 'notif_pref_pending_sync';

  /// Devuelve las preferencias guardadas, o `null` si el usuario nunca ha
  /// guardado nada (para poder distinguir "sin configurar" de "todo apagado").
  Future<NotificationPreferences?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_kPush) &&
        !prefs.containsKey(_kEmail) &&
        !prefs.containsKey(_kWear)) {
      return null;
    }
    return NotificationPreferences(
      pushEnabled: prefs.getBool(_kPush) ?? NotificationPreferences.defaults.pushEnabled,
      emailEnabled: prefs.getBool(_kEmail) ?? NotificationPreferences.defaults.emailEnabled,
      wearEnabled: prefs.getBool(_kWear) ?? NotificationPreferences.defaults.wearEnabled,
    );
  }

  Future<void> save(
    NotificationPreferences preferences, {
    bool pendingSync = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPush, preferences.pushEnabled);
    await prefs.setBool(_kEmail, preferences.emailEnabled);
    await prefs.setBool(_kWear, preferences.wearEnabled);
    await prefs.setBool(_kPendingSync, pendingSync);
  }

  /// `true` si el último guardado no llegó a sincronizarse con el backend.
  Future<bool> hasPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPendingSync) ?? false;
  }

  Future<void> clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPendingSync, false);
  }
}
