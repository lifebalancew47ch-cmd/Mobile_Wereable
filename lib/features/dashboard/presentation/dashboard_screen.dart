import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../wearable/presentation/wearable_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final String _pasos = '--';
  final String _corazon = '--';
  final String _sueno = '--';
  final String _calorias = '--';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final wearableState = ref.watch(wearableProvider);
    final String statusReloj = wearableState.isConnected ? 'Reloj conectado' : 'Reloj desconectado';
    final String lastAccel = wearableState.lastData != null ? 
        'x: ${wearableState.lastData!.x.toStringAsFixed(2)}\ny: ${wearableState.lastData!.y.toStringAsFixed(2)}\nz: ${wearableState.lastData!.z.toStringAsFixed(2)}' 
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
              color: wearableState.isConnected ? colorScheme.primaryContainer : colorScheme.surfaceVariant,
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
                      color: wearableState.isConnected ? colorScheme.primary : Colors.grey
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Métricas clave', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _MetricCard(title: 'Pasos', value: _pasos, icon: Icons.directions_walk, color: Colors.blue),
                _MetricCard(title: 'Corazón', value: _corazon, icon: Icons.favorite, color: Colors.red),
                _MetricCard(title: 'Sueño', value: _sueno, icon: Icons.bedtime, color: Colors.deepPurple),
                _MetricCard(title: 'Calorías', value: _calorias, icon: Icons.local_fire_department, color: Colors.orange),
              ],
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

  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

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
