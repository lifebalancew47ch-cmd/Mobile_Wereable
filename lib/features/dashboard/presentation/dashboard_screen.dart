import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wearable/presentation/wearable_provider.dart';
import '../presentation/providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final wearableState = ref.watch(wearableProvider);
    final dashboardAsync = ref.watch(dashboardDataProvider);

    final String statusReloj =
        wearableState.isConnected ? 'Reloj conectado' : 'Reloj desconectado';
    final String lastAccel = wearableState.lastData != null
        ? 'x: ${wearableState.lastData!.x.toStringAsFixed(2)}\ny: ${wearableState.lastData!.y.toStringAsFixed(2)}\nz: ${wearableState.lastData!.z.toStringAsFixed(2)}'
        : 'Cargando datos...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/dashboard/notifications'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: wearableState.isConnected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusReloj,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Movimiento actual:\n$lastAccel',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      wearableState.isConnected ? Icons.watch : Icons.watch_off,
                      size: 48,
                      color: wearableState.isConnected
                          ? colorScheme.primary
                          : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            dashboardAsync.when(
              data: (dashboard) {
                if (dashboard.hasError && dashboard.kpis == null) {
                  return _ErrorCard(
                    message: dashboard.error!,
                    onRetry: () => ref.refresh(dashboardDataProvider.future),
                  );
                }
                return _MetricsSection(dashboard: dashboard);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _ErrorCard(
                message: error.toString(),
                onRetry: () => ref.refresh(dashboardDataProvider.future),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsSection extends StatelessWidget {
  final DashboardData dashboard;

  const _MetricsSection({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kpis = dashboard.kpis;
    final summary = dashboard.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[
          Text(
            summary.fullName.isNotEmpty
                ? 'Hola, ${summary.fullName}'
                : 'Resumen Diario',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.dailySteps} pasos · ${summary.activeMinutes.toStringAsFixed(0)} min activos',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
        ],
        Text('Métricas clave', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _MetricCard(
              title: 'Pasos',
              value: kpis != null
                  ? '${kpis.dailySteps}'
                  : (summary?.dailySteps.toString() ?? '--'),
              icon: Icons.directions_walk,
              color: Colors.blue,
            ),
            _MetricCard(
              title: 'Corazón',
              value: kpis != null
                  ? '${kpis.heartRate.toStringAsFixed(0)} bpm'
                  : '--',
              icon: Icons.favorite,
              color: Colors.red,
            ),
            _MetricCard(
              title: 'IMC',
              value: kpis != null ? kpis.bmi.toStringAsFixed(1) : '--',
              icon: Icons.monitor_weight_outlined,
              color: Colors.deepPurple,
            ),
            _MetricCard(
              title: 'Calorías',
              value: kpis != null
                  ? '${kpis.caloriesBurned.toStringAsFixed(0)} kcal'
                  : '--',
              icon: Icons.local_fire_department,
              color: Colors.orange,
            ),
          ],
        ),
        if (dashboard.hasError) ...[
          const SizedBox(height: 16),
          Text(
            'Algunas métricas no están disponibles: ${dashboard.error}',
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el dashboard',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
