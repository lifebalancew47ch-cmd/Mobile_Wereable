import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/notifications_provider.dart';
import '../domain/entities/alert_item.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Alertas')),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No tienes alertas', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(alertsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _AlertCard(alert: alerts[index]),
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
                  'No se pudieron cargar las alertas.\n$error',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(alertsProvider.future),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final AlertItem alert;

  const _AlertCard({required this.alert});

  Color get _priorityColor {
    final priority = alert.priority.toLowerCase();
    if (priority.contains('high') || priority.contains('critical')) return Colors.red;
    if (priority.contains('medium') || priority.contains('warning')) return Colors.orange;
    if (priority.contains('low')) return Colors.green;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _priorityColor.withAlpha(40),
          child: Icon(Icons.warning_amber_rounded, color: _priorityColor),
        ),
        title: Text(
          alert.title,
          style: TextStyle(
            fontWeight: alert.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(alert.body),
            const SizedBox(height: 4),
            Text(
              '${alert.source.isEmpty ? 'Sistema' : alert.source} · '
              '${alert.priority.isEmpty ? 'normal' : alert.priority}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            final api = ref.read(notificationsApiServiceProvider);
            if (value == 'read') {
              await api.markAlertRead(alert.id);
            } else if (value == 'dismiss') {
              await api.dismissAlert(alert.id);
            }
            ref.invalidate(alertsProvider);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'read', child: Text('Marcar como leída')),
            PopupMenuItem(value: 'dismiss', child: Text('Descartar')),
          ],
        ),
      ),
    );
  }
}
