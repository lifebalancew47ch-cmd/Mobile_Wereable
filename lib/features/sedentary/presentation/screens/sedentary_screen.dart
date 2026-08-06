import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/sedentary_api_service.dart';
import '../providers/sedentary_provider.dart';

class SedentaryScreen extends ConsumerStatefulWidget {
  const SedentaryScreen({super.key});

  @override
  ConsumerState<SedentaryScreen> createState() => _SedentaryScreenState();
}

class _SedentaryScreenState extends ConsumerState<SedentaryScreen> {
  late int _stepsTarget;
  late int _activeTarget;
  bool _saving = false;
  bool _goalsInitialized = false;

  @override
  void initState() {
    super.initState();
    _stepsTarget = 8000;
    _activeTarget = 30;
  }

  Future<void> _refresh(WidgetRef ref) async {
    setState(() => _goalsInitialized = false);
    ref.invalidate(sedentaryScoreProvider);
    ref.invalidate(sedentaryProgressProvider);
    ref.invalidate(sedentaryGoalsProvider);
    try {
      await Future.wait([
        ref.read(sedentaryScoreProvider.future),
        ref.read(sedentaryProgressProvider.future),
        ref.read(sedentaryGoalsProvider.future),
      ]);
    } catch (_) {}
  }

  Future<void> _saveGoals() async {
    setState(() => _saving = true);
    try {
      await ref.read(updateSedentaryGoalsProvider((dailyStepsTarget: _stepsTarget, activeMinutesTarget: _activeTarget)).future);
      // Refresca objetivos Y progreso: el progreso trae su propio target
      // (dailyStepsTarget/activeMinutesTarget) que debe reflejar el cambio
      // recién guardado, no solo la tarjeta de "Mis objetivos".
      ref.invalidate(sedentaryGoalsProvider);
      ref.invalidate(sedentaryProgressProvider);
      ref.invalidate(sedentaryScoreProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objetivos actualizados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron guardar los objetivos: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoreAsync = ref.watch(sedentaryScoreProvider);
    final progressAsync = ref.watch(sedentaryProgressProvider);
    final goalsAsync = ref.watch(sedentaryGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riesgo sedentario')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildScoreCard(context, ref, scoreAsync),
            const SizedBox(height: 16),
            _buildProgressCard(context, ref, progressAsync),
            const SizedBox(height: 16),
            _buildGoalsCard(context, ref, goalsAsync),
            const SizedBox(height: 16),
            _buildInfoCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(
      BuildContext context, WidgetRef ref, AsyncValue<SedentaryScore> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorTile(
            message: 'No se pudo cargar el score.\n$e',
            onRetry: () => ref.invalidate(sedentaryScoreProvider),
          ),
          data: (score) {
            final riskColor = _riskColor(score.riskLevel);
            final level = score.riskLevel.isEmpty ? 'Sin datos' : score.riskLevel;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Score de sedentarismo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: (score.score / 100).clamp(0.0, 1.0),
                        strokeWidth: 9,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(riskColor),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.score.toStringAsFixed(0),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                          Text(
                            'Nivel de riesgo: $level',
                            style: TextStyle(color: riskColor, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Actualizado ${_formatDate(score.recordedAtUtc)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressCard(
      BuildContext context, WidgetRef ref, AsyncValue<SedentaryProgress> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorTile(
            message: 'No se pudo cargar el progreso.\n$e',
            onRetry: () => ref.invalidate(sedentaryProgressProvider),
          ),
          data: (p) {
            final stepsProgress = (p.stepsProgress * 100).clamp(0, 100).toDouble();
            final activeProgress = (p.activeProgress * 100).clamp(0, 100).toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Progreso diario',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildProgressBar(
                  label: 'Pasos',
                  value: p.dailySteps,
                  target: p.dailyStepsTarget,
                  progress: stepsProgress,
                  icon: Icons.directions_walk,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildProgressBar(
                  label: 'Activos',
                  value: p.activeMinutes.round(),
                  target: p.activeMinutesTarget,
                  progress: activeProgress,
                  icon: Icons.timer_outlined,
                  color: Colors.blue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required int value,
    required int target,
    required double progress,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text('$label · $value / $target'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsCard(
      BuildContext context, WidgetRef ref, AsyncValue<SedentaryGoal> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mis objetivos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Define la meta de pasos y minutos activos diarios.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorTile(
                message: 'No se pudieron cargar los objetivos.\n$e',
                onRetry: () => ref.invalidate(sedentaryGoalsProvider),
              ),
              data: (goal) {
                if (!_goalsInitialized) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _stepsTarget = goal.dailyStepsTarget;
                        _activeTarget = goal.activeMinutesTarget;
                        _goalsInitialized = true;
                      });
                    }
                  });
                }
                return Column(
                  children: [
                    _buildStepper(
                      label: 'Pasos diarios',
                      value: _stepsTarget,
                      min: 1000,
                      max: 30000,
                      step: 500,
                      onChanged: (v) => setState(() => _stepsTarget = v),
                    ),
                    const SizedBox(height: 12),
                    _buildStepper(
                      label: 'Minutos activos',
                      value: _activeTarget,
                      min: 5,
                      max: 240,
                      step: 5,
                      onChanged: (v) => setState(() => _activeTarget = v),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveGoals,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Guardar objetivos'),
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

  Widget _buildStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 60,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.blueGrey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Este score se calcula en la nube con tus datos de actividad sincronizados. '
                'A menor riesgo de sedentarismo, mejor para tu salud.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(String level) {
    final l = level.toLowerCase();
    if (l.contains('high') || l.contains('alto')) return Colors.red;
    if (l.contains('medium') || l.contains('medio') || l.contains('moderate')) return Colors.orange;
    if (l.contains('low') || l.contains('bajo')) return Colors.green;
    return Colors.blueGrey;
  }

  String _formatDate(DateTime date) {
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
