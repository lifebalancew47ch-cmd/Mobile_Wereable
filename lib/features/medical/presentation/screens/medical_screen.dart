import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/medical_provider.dart';
import '../../data/medical_api_service.dart';
import '../../../fog/presentation/providers/fog_providers.dart';
import '../../../../models/fog_state.dart';

class MedicalScreen extends ConsumerWidget {
  const MedicalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestAsync = ref.watch(medicalLatestProvider);
    final historyAsync = ref.watch(medicalHistoryProvider);
    final engine = ref.watch(fogEngineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Datos médicos')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(medicalLatestProvider);
          ref.invalidate(medicalHistoryProvider);
          try {
            await Future.wait([
              ref.read(medicalLatestProvider.future),
              ref.read(medicalHistoryProvider.future),
            ]);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            StreamBuilder<FogState>(
              stream: engine.stateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? FogState(
                  status: ActivityStatus.idle,
                  inactiveMinutes: 0,
                  lastMovement: DateTime.now(),
                );
                return _buildClinicalCard(context, state);
              },
            ),
            const SizedBox(height: 16),
            _buildLatestCard(context, ref, latestAsync),
            const SizedBox(height: 16),
            _buildHistoryCard(context, ref, historyAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalCard(BuildContext context, FogState state) {
    String label = 'Trabajo Sedentario';
    Color color = Colors.orange;
    IconData icon = Icons.work;

    if (state.clinicalState == ClinicalState.sleep) {
      label = 'Durmiendo';
      color = Colors.indigo;
      icon = Icons.bedtime;
    } else if (state.clinicalState == ClinicalState.clinicalRest) {
      label = 'Reposo Clínico';
      color = Colors.blue;
      icon = Icons.chair_alt;
    }

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado Clínico en Vivo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
            if (state.reposoVerificado)
              const Icon(Icons.verified, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestCard(
      BuildContext context, WidgetRef ref, AsyncValue<MedicalReadingResponse> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Última lectura clínica',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorTile(
                message: 'No se pudo cargar la lectura.\n$e',
                onRetry: () => ref.invalidate(medicalLatestProvider),
              ),
              data: (reading) => Column(
                children: [
                  Row(
                    children: [
                      _buildMetric(
                        icon: Icons.favorite,
                        color: Colors.red,
                        value: reading.heartRate.toStringAsFixed(0),
                        unit: 'lpm',
                        label: 'Frecuencia',
                      ),
                      _buildMetric(
                        icon: Icons.monitor_heart_outlined,
                        color: Colors.purple,
                        value: reading.hrv.toStringAsFixed(0),
                        unit: 'ms',
                        label: 'HRV',
                      ),
                      _buildMetric(
                        icon: Icons.bloodtype_outlined,
                        color: Colors.blue,
                        value: reading.spo2.toStringAsFixed(0),
                        unit: '%',
                        label: 'SpO2',
                      ),
                      _buildMetric(
                        icon: Icons.directions_walk,
                        color: Colors.green,
                        value: '${reading.steps}',
                        unit: '',
                        label: 'Pasos',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(reading.recordedAtUtc),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(unit, style: const TextStyle(fontSize: 11)),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
      BuildContext context, WidgetRef ref, AsyncValue<List<MedicalReadingResponse>> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorTile(
                message: 'No se pudo cargar el historial.\n$e',
                onRetry: () => ref.invalidate(medicalHistoryProvider),
              ),
              data: (history) {
                if (history.isEmpty) {
                  return const Text('Sin lecturas registradas.',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: [
                    for (final item in history.take(15))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.favorite, color: Colors.red, size: 18),
                        title: Text('${item.heartRate.toStringAsFixed(0)} lpm · '
                            '${item.hrv.toStringAsFixed(0)} ms HRV'),
                        subtitle: Text('SpO2 ${item.spo2.toStringAsFixed(0)}% · '
                            '${item.steps} pasos'),
                        trailing: Text(
                          _shortDate(item.recordedAtUtc),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _shortDate(DateTime date) {
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorTile({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
