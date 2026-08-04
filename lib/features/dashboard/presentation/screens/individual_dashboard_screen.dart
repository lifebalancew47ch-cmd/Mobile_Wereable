import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/dashboard_models.dart';

class IndividualDashboardScreen extends ConsumerWidget {
  const IndividualDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(individualDashboardDataProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Análisis Individual')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(individualDashboardDataProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dataAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorTile(
                message: 'No se pudieron cargar los datos.\n$e',
                onRetry: () => ref.invalidate(individualDashboardDataProvider),
              ),
              data: (data) => Column(
                children: [
                  if (data.progress != null) ...[
                    _buildProgressCard(theme, data.progress!),
                    const SizedBox(height: 16),
                  ],
                  if (data.biometrics != null) ...[
                    _buildBiometricsCard(theme, data.biometrics!),
                    const SizedBox(height: 16),
                  ],
                  if (data.heatmap.isNotEmpty) ...[
                    _buildHeatmapCard(theme, data.heatmap),
                    const SizedBox(height: 16),
                  ],
                  if (data.activity.isNotEmpty) ...[
                    _buildActivityCard(theme, data.activity),
                    const SizedBox(height: 16),
                  ],
                  if (data.statistics != null) ...[
                    _buildStatisticsCard(theme, data.statistics!),
                    const SizedBox(height: 16),
                  ],
                  if (data.recommendations.isNotEmpty) ...[
                    _buildRecommendationsCard(theme, data.recommendations),
                    const SizedBox(height: 16),
                  ],
                  if (data.goals.isNotEmpty) ...[
                    _buildGoalsCard(theme, data.goals),
                    const SizedBox(height: 16),
                  ],
                  if (data.rewards.isNotEmpty) ...[
                    _buildRewardsCard(theme, data.rewards),
                    const SizedBox(height: 16),
                  ],
                  if (!data.hasAnyData &&
                      data.goals.isEmpty &&
                      data.rewards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('Sin datos de la nube para mostrar.',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(ThemeData theme, DashboardProgress progress) {
    return _sectionCard(
      theme,
      title: 'Progreso diario',
      icon: Icons.track_changes,
      child: Column(
        children: [
          _buildBar(theme, 'Pasos', progress.dailySteps,
              progress.dailyStepsTarget, progress.stepsProgress, Colors.green),
          const SizedBox(height: 12),
          _buildBar(theme, 'Activos', progress.activeMinutes.round(),
              progress.activeMinutesTarget, progress.activeProgress, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildBar(ThemeData theme, String label, int value, int target,
      double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('$value / $target'),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (progress).clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricsCard(ThemeData theme, DashboardBiometrics biometrics) {
    return _sectionCard(
      theme,
      title: 'Biometría',
      icon: Icons.monitor_heart_outlined,
      child: Row(
        children: [
          _metric(theme, biometrics.heartRate.toStringAsFixed(0), 'lpm',
              'Frecuencia'),
          _metric(theme, biometrics.bmi.toStringAsFixed(1), '', 'IMC'),
          _metric(theme,
              '${biometrics.systolicBp.toStringAsFixed(0)}/${biometrics.diastolicBp.toStringAsFixed(0)}',
              'mmHg', 'Presión'),
          _metric(theme, biometrics.weight.toStringAsFixed(0), 'kg',
              'Peso'),
        ],
      ),
    );
  }

  Widget _metric(ThemeData theme, String value, String unit, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          Text(unit, style: const TextStyle(fontSize: 11)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(ThemeData theme, DashboardStatistics statistics) {
    return _sectionCard(
      theme,
      title: 'Estadísticas',
      icon: Icons.bar_chart,
      child: Row(
        children: [
          _metric(theme, '${statistics.totalSessions}', '', 'Sesiones'),
          _metric(theme, '${statistics.activeSessions}', '', 'Activas'),
          _metric(theme, '${statistics.alertCount}', '', 'Alertas'),
          _metric(theme, statistics.averageDurationMinutes.toStringAsFixed(0),
              'min', 'Promedio'),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(
      ThemeData theme, List<Map<String, dynamic>> heatmap) {
    final intensities = _parseHourlyHeatmap(heatmap);
    return _sectionCard(
      theme,
      title: 'Mapa de calor',
      icon: Icons.grid_view,
      child: intensities == null
          ? Text(
              'Sin datos de mapa de calor.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHourlyHeatmapGrid(intensities),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0h', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('6h', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('12h', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('18h', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('23h', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
    );
  }

  List<int>? _parseHourlyHeatmap(List<Map<String, dynamic>> heatmap) {
    if (heatmap.isEmpty) return null;
    // Formato A: lista de objetos {hour, intensity}
    if (heatmap.first.containsKey('intensity') ||
        heatmap.first.containsKey('hour')) {
      final hours = List<int>.filled(24, 0);
      for (final item in heatmap) {
        final hour = (item['hour'] as num?)?.toInt() ?? 0;
        final intensity = (item['intensity'] as num?)?.toInt() ?? 0;
        if (hour >= 0 && hour < 24) hours[hour] = intensity;
      }
      return hours;
    }
    // Formato B: lista de 24 valores {value} o {intensity}
    if (heatmap.length == 24) {
      return heatmap
          .map((e) {
            final raw = e['value'] ?? e['intensity'];
            return (raw as num?)?.toInt() ?? 0;
          })
          .toList();
    }
    return null;
  }

  Widget _buildHourlyHeatmapGrid(List<int> intensities) {
    final max = intensities.reduce((a, b) => a > b ? a : b);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: intensities.asMap().entries.map((entry) {
        final hour = entry.key;
        final value = entry.value;
        final intensity = max > 0 ? value / max : 0.0;
        final color = _heatColor(intensity);
        return Tooltip(
          message: '$hour h: $value',
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _heatColor(double intensity) {
    if (intensity <= 0.0) return const Color(0xFFE8EFEA);
    if (intensity < 0.33) return const Color(0xFFD1DCD6);
    if (intensity < 0.66) return const Color(0xFFD68C5E);
    return const Color(0xFF3E6F58);
  }

  Widget _buildActivityCard(
      ThemeData theme, List<Map<String, dynamic>> activity) {
    return _sectionCard(
      theme,
      title: 'Actividad reciente',
      icon: Icons.history,
      child: Column(
        children: [
          for (final item in activity.take(8))
            _buildActivityItem(item),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? item['activityType']?.toString() ?? '';
    final title = item['title']?.toString() ?? _activityTitle(type);
    final duration = (item['durationMinutes'] ?? item['duration']) as num?;
    final steps = (item['steps'] as num?)?.toInt();
    final startRaw = item['startTime']?.toString() ?? item['timestamp']?.toString() ?? '';
    final start = DateTime.tryParse(startRaw);

    final durationLabel = duration != null
        ? '${duration.round()} min'
        : (steps != null && steps > 0 ? '$steps pasos' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_activityIcon(type), color: _activityColor(type), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (start != null)
                  Text(
                    '${start.day}/${start.month} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
          if (durationLabel.isNotEmpty)
            Text(
              durationLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _activityTitle(String type) {
    return switch (type) {
      'active' => 'Sesión activa',
      'alert' => 'Alerta de sedentarismo',
      'idle' => 'Período sedentario',
      _ => 'Actividad',
    };
  }

  IconData _activityIcon(String type) {
    return switch (type) {
      'active' => Icons.directions_run,
      'alert' => Icons.warning_amber_rounded,
      _ => Icons.chair_alt,
    };
  }

  Color _activityColor(String type) {
    return switch (type) {
      'active' => Colors.green.shade600,
      'alert' => Colors.orange.shade700,
      _ => Colors.blueGrey,
    };
  }

  Widget _buildRecommendationsCard(ThemeData theme,
      List<DashboardRecommendation> recommendations) {
    return _sectionCard(
      theme,
      title: 'Recomendaciones',
      icon: Icons.recommend_outlined,
      child: Column(
        children: [
          for (final recommendation in recommendations.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recommendation.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          recommendation.description,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoalsCard(ThemeData theme, Map<String, dynamic> goals) {
    final stepsTarget = goals['dailyStepsTarget'] ?? goals['stepsTarget'];
    final activeTarget = goals['activeMinutesTarget'] ?? goals['minutesTarget'];
    return _sectionCard(
      theme,
      title: 'Metas',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stepsTarget != null)
            Text('Pasos diarios objetivo: $stepsTarget',
                style: const TextStyle(fontSize: 14)),
          if (activeTarget != null)
            Text('Minutos activos objetivo: $activeTarget',
                style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRewardsCard(ThemeData theme, Map<String, dynamic> rewards) {
    final points = rewards['points'] ?? rewards['totalPoints'];
    final level = rewards['level'];
    final badges = rewards['badgesUnlocked'] ?? rewards['badges'];
    return _sectionCard(
      theme,
      title: 'Recompensas',
      icon: Icons.emoji_events,
      child: Row(
        children: [
          if (points != null)
            _metric(theme, '$points', 'pts', 'Puntos'),
          if (level != null) _metric(theme, '$level', '', 'Nivel'),
          if (badges != null) _metric(theme, '$badges', '', 'Medallas'),
        ],
      ),
    );
  }

  Widget _sectionCard(
      ThemeData theme, {
      required String title,
      required IconData icon,
      required Widget child,
    }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
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
