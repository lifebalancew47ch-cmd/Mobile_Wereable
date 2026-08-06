import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';
import '../../data/datasources/notifications_api_service.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/alert_item.dart';

final notificationsApiServiceProvider = Provider((ref) {
  final dio = ref.watch(notificationsApiClientProvider);
  return NotificationsApiService(dio);
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final api = ref.watch(notificationsApiServiceProvider);
  return await api.getUserNotifications(limit: 20);
});

/// Alertas de sedentarismo (GET /alerts) fusionadas con las alertas locales
/// registradas por el FogEngine en la BD segura.
///
/// Las dos fuentes se resuelven de forma independiente: si el backend de
/// alertas falla o no responde, las alertas locales (críticas para el
/// monitoreo de sedentarismo) igual deben mostrarse.
final alertsProvider = FutureProvider<List<AlertItem>>((ref) async {
  final api = ref.watch(notificationsApiServiceProvider);
  final results = await Future.wait([
    _loadCloudAlerts(api),
    _loadLocalAlerts(),
  ]);
  final combined = [...results[0], ...results[1]];
  combined.sort((a, b) => b.createdAtUtc.compareTo(a.createdAtUtc));
  return combined;
});

Future<List<AlertItem>> _loadCloudAlerts(NotificationsApiService api) async {
  try {
    return await api.getAlerts();
  } catch (_) {
    return const [];
  }
}

Future<List<AlertItem>> _loadLocalAlerts() async {
  try {
    final db = SecureDatabaseService.instance;
    final rows = await db.getAlertsToday();
    return rows.map((row) {
      final type = row['type']?.toString() ?? 'sedentario';
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      return AlertItem(
        id: 'local-${row['id']}',
        title: 'Alerta de sedentarismo',
        body: 'Llevabas ${row['duration_minutes'] ?? 45} minutos inactivo.',
        source: 'FogEngine local',
        priority: type.toLowerCase().contains('critical') ? 'high' : 'medium',
        createdAtUtc: timestamp?.toLocal() ?? DateTime.now(),
        read: row['acknowledged'] == true || row['acknowledged'] == 1,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

/// Preferencias de notificación (GET /preferences).
final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final api = ref.watch(notificationsApiServiceProvider);
  return await api.getPreferences();
});
