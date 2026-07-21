import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/fog_engine.dart';
import '../../models/fog_state.dart';
import '../../services/watch_service.dart';
import '../../services/wearable_communication_service.dart';
import '../../services/notification_service.dart';
import '../../models/vital_sign.dart';

// Providers para inyección de dependencias (Sección 13: Integración Clean Arch)
final wearableCommunicationServiceProvider = Provider((ref) => WearableCommunicationService());
final notificationServiceProvider = Provider((ref) => NotificationService());

final fogEngineProvider = Provider((ref) {
  final wearable = ref.watch(wearableCommunicationServiceProvider);
  final notification = ref.watch(notificationServiceProvider);
  final engine = FogEngine(wearable, notification);
  // El ciclo de vida del motor se ata al provider
  engine.start();
  ref.onDispose(() => engine.stop());
  return engine;
});

final watchServiceProvider = Provider<IWatchService>((ref) => WatchService());

/// Pantalla optimizada para Wear OS basada en la Sección 13 del documento técnico.
/// Muestra el estado del FogEngine y métricas de salud en tiempo real.
class WatchDashboardScreen extends ConsumerWidget {
  const WatchDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fogEngine = ref.watch(fogEngineProvider);
    final watchService = ref.watch(watchServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // Negro puro para ahorro de batería (Sección 13)
      body: Center(
        child: StreamBuilder<FogState>(
          stream: fogEngine.stateStream,
          builder: (context, snapshot) {
            final state = snapshot.data ?? FogState(
              status: ActivityStatus.active,
              inactiveMinutes: 0,
              lastMovement: DateTime.now(),
            );

            return Stack(
              alignment: Alignment.center,
              children: [
                // 1. Indicador visual circular de estado (Sección 13.1)
                _buildStatusRing(state.status),

                // 2. Contenido Central: Minutos Inactivos
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'MINUTOS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      '${state.inactiveMinutes}',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStatusLabel(state.status),
                  ],
                ),

                // 3. Métricas Vitales en los bordes (Sección 6.1)
                Positioned(
                  bottom: 20,
                  child: FutureBuilder<VitalSign?>(
                    future: watchService.getLatestMetrics(),
                    builder: (context, vitalsSnapshot) {
                      final vitals = vitalsSnapshot.data;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetricWidget(
                            icon: Icons.favorite,
                            value: vitals != null ? '${vitals.heartRate.toInt()}' : '--',
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 16),
                          _MetricWidget(
                            icon: Icons.directions_walk,
                            value: vitals != null ? '${vitals.steps}' : '--',
                            color: Colors.blueAccent,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusRing(ActivityStatus status) {
    Color color;
    bool isBlinking = false;

    switch (status) {
      case ActivityStatus.active:
        color = Colors.greenAccent;
        break;
      case ActivityStatus.idle:
        color = Colors.amberAccent;
        break;
      case ActivityStatus.alertTriggered:
        color = Colors.redAccent;
        isBlinking = true;
        break;
    }

    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: isBlinking ? 0.8 : 0.3),
          width: 8,
        ),
      ),
    );
  }

  Widget _buildStatusLabel(ActivityStatus status) {
    String text;
    Color color;

    switch (status) {
      case ActivityStatus.active:
        text = 'ACTIVO';
        color = Colors.greenAccent;
        break;
      case ActivityStatus.idle:
        text = 'QUIETO';
        color = Colors.amberAccent;
        break;
      case ActivityStatus.alertTriggered:
        text = '¡MUÉVETE!';
        color = Colors.redAccent;
        break;
    }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
}

class _MetricWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _MetricWidget({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
