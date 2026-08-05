import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/datasources/secure_database_service.dart';
import '../../../models/fog_state.dart';
import 'providers/fog_providers.dart';

class FogScreen extends ConsumerStatefulWidget {
  const FogScreen({super.key});

  @override
  ConsumerState<FogScreen> createState() => _FogScreenState();
}

class _FogScreenState extends ConsumerState<FogScreen> {
  late final SecureDatabaseService _db;
  int _sessionsToday = 0;
  int _vitalsToday = 0;
  int _alertsToday = 0;
  Map<String, Object?>? _lastSession;

  @override
  void initState() {
    super.initState();
    _db = SecureDatabaseService.instance;
    _loadTodayStats();
  }

  Future<void> _loadTodayStats() async {
    final sessions = await _db.countActivitySessionsToday();
    final vitals = await _db.countVitalSignsToday();
    final alerts = await _db.countAlertsToday();
    final lastSession = await _db.getLastActivitySession();
    if (!mounted) return;
    setState(() {
      _sessionsToday = sessions;
      _vitalsToday = vitals;
      _alertsToday = alerts;
      _lastSession = lastSession;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final engine = ref.watch(fogEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fog Computing Local', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Estado de sincronización en la nube',
            onPressed: () => context.push('/fog/sync'),
            icon: const Icon(Icons.cloud_upload_outlined),
          ),
        ],
      ),
      body: StreamBuilder<FogState>(
        stream: engine.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final isActive = engine.isRunning;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Engine Status Card (estado real del motor)
                Card(
                  color: isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          isActive ? Icons.online_prediction : Icons.offline_bolt_outlined,
                          size: 64,
                          color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isActive ? _statusLabel(state?.status) : 'Motor Inactivo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isActive
                              ? _statusDescription(state?.status, engine.alertThresholdMinutes)
                              : 'El procesamiento en segundo plano está en pausa.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isActive
                                ? colorScheme.onPrimaryContainer.withAlpha(200)
                                : colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Inactivo: ${state?.inactiveMinutes ?? 0} min  |  Último movimiento: ${_formatTime(state?.lastMovement)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            if (engine.isRunning) {
                              engine.pause();
                            } else {
                              engine.resume();
                            }
                            setState(() {});
                          },
                          icon: Icon(isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                          label: Text(isActive ? 'Pausar Procesamiento' : 'Reanudar Procesamiento'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Real-time Engine Metrics
                Text(
                  'Métricas del Motor en Tiempo Real',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.speed, color: Colors.blue),
                        title: const Text('Frecuencia de Lectura'),
                        trailing: const Text('Tiempo real (5s UI)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.sensors, color: Colors.orange),
                        title: const Text('Muestras Procesadas'),
                        trailing: Text(
                          '${engine.samplesProcessed}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.timelapse, color: Colors.purple),
                        title: const Text('Ventanas Analizadas (30s)'),
                        trailing: Text(
                          '${engine.windowsAnalyzed}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notification_important, color: Colors.red),
                        title: const Text('Alertas de Sedentarismo'),
                        trailing: Text(
                          '${engine.alertsTriggered}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Persisted data from today (datos reales de la BD local)
                Text(
                  'Registros de Hoy (Base de Datos Local)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.access_time, color: Colors.teal),
                        title: const Text('Sesiones de Actividad'),
                        trailing: Text('$_sessionsToday', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.redAccent),
                        title: const Text('Signos Vitales'),
                        trailing: Text('$_vitalsToday', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.warning_amber, color: Colors.amber),
                        title: const Text('Alertas Registradas'),
                        trailing: Text('$_alertsToday', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      if (_lastSession != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.history, color: Colors.blueGrey),
                          title: const Text('Última Sesión'),
                          subtitle: Text(
                            '${_lastSession!['type']} — ${_lastSession!['duration_minutes']} min',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(ActivityStatus? status) {
    switch (status) {
      case ActivityStatus.active:
        return 'Algoritmo de Sedentarismo Activo';
      case ActivityStatus.idle:
        return 'Usuario Inactivo';
      case ActivityStatus.alertTriggered:
        return '¡Alerta de Sedentarismo!';
      case null:
        return 'Algoritmo de Sedentarismo Activo';
    }
  }

  String _statusDescription(ActivityStatus? status, int threshold) {
    switch (status) {
      case ActivityStatus.idle:
        return 'Detectado sin movimiento: procesando ventanas de análisis local.';
      case ActivityStatus.alertTriggered:
        return 'Se superó el umbral de $threshold minutos de inactividad. Se ha notificado al usuario.';
      case ActivityStatus.active:
      case null:
        return 'Analizando datos de sensores en tiempo real de manera local.';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '--';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
