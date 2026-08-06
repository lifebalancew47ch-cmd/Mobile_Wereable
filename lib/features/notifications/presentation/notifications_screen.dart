import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/notifications_provider.dart';
import '../domain/entities/notification_item.dart';
import 'alerts_screen.dart';
import 'notification_preferences_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Centro de notificaciones'),
          actions: [
            IconButton(
              tooltip: 'Preferencias',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationPreferencesScreen(),
                ),
              ),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Notificaciones'),
              Tab(text: 'Alertas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _NotificationsList(),
            AlertsScreen(),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tienes notificaciones', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _NotificationCard(notification: notifications[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'No se pudieron cargar las notificaciones.\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(notificationsProvider.future),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
  }
}

class _NotificationCard extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationCard({required this.notification});

  IconData get _icon {
    final severity = notification.severity.toLowerCase();
    if (severity.contains('alert') || severity.contains('warning') || severity.contains('danger')) {
      return Icons.warning_amber_rounded;
    }
    if (severity.contains('success')) {
      return Icons.check_circle_outline;
    }
    if (severity.contains('info')) {
      return Icons.info_outline;
    }
    return Icons.notifications_outlined;
  }

  Color get _iconColor {
    final severity = notification.severity.toLowerCase();
    if (severity.contains('alert') || severity.contains('warning') || severity.contains('danger')) {
      return Colors.orange;
    }
    if (severity.contains('success')) {
      return Colors.green;
    }
    return Colors.blueGrey;
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String value) async {
    final api = ref.read(notificationsApiServiceProvider);
    try {
      if (value == 'read') {
        await api.markNotificationRead(notification.id);
      } else if (value == 'dismiss') {
        await api.archiveNotification(notification.id);
      }
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la notificación: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(_icon, color: _iconColor),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(notification.message),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _relativeTime(notification.createdAtUtc),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleAction(context, ref, value),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'read', child: Text('Marcar como leída')),
                PopupMenuItem(value: 'dismiss', child: Text('Descartar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
