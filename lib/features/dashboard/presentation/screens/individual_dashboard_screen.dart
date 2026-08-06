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
                  if (data.activity != null) ...[
                    _buildActivityCard(theme, data.activity!),
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
                  if (!data.hasAnyData)
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
    // Contrato real del backend: progreso semanal de metas + días activos,
    // no barras de pasos/minutos (esas viven ahora en "Metas").
    final pct = (progress.weeklyGoalCompletionPercentage / 100).clamp(0.0, 1.0);
    return _sectionCard(
      theme,
      title: 'Progreso semanal',
      icon: Icons.track_changes,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Metas completadas', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${progress.weeklyGoalCompletionPercentage.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 9,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            ),
          ),
          const SizedBox(height: 12),
          Text('Días activo esta semana: ${progress.daysActive}',
              style: const TextStyle(fontSize: 13)),
        ],
      ),
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
      title: 'Estadísticas de la semana',
      icon: Icons.bar_chart,
      child: Row(
        children: [
          _metric(theme, statistics.activeHoursThisWeek.toStringAsFixed(1),
              'h', 'Activo'),
          _metric(theme, statistics.sedentaryHoursThisWeek.toStringAsFixed(1),
              'h', 'Sedentario'),
          _metric(theme, statistics.averageHeartRate.toStringAsFixed(0),
              'lpm', 'FC promedio'),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard(ThemeData theme, List<int> heatmap) {
    final intensities = heatmap.length == 24 ? heatmap : null;
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

  // El backend devuelve un único snapshot agregado del día (no un feed de
  // eventos individuales), así que se muestra como métricas, no como lista.
  Widget _buildActivityCard(ThemeData theme, DashboardActivitySnapshot activity) {
    return _sectionCard(
      theme,
      title: 'Actividad de hoy',
      icon: Icons.history,
      child: Row(
        children: [
          _metric(theme, '${activity.dailySteps}', '', 'Pasos'),
          _metric(theme, activity.activeMinutes.round().toString(), 'min', 'Activo'),
          _metric(theme, activity.sedentaryHours.toStringAsFixed(1), 'h', 'Sedentario'),
          _metric(theme, activity.caloriesBurned.toStringAsFixed(0), 'kcal', 'Calorías'),
        ],
      ),
    );
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

  // El backend devuelve una lista de retos de gamificación (challengeId,
  // title, progressPercentage, completed), no un target fijo de pasos/minutos.
  Widget _buildGoalsCard(ThemeData theme, List<DashboardChallenge> goals) {
    return _sectionCard(
      theme,
      title: 'Metas',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final challenge in goals.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(challenge.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (challenge.completed)
                        const Icon(Icons.check_circle, color: Colors.green, size: 18)
                      else
                        Text('${challenge.progressPercentage.toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (challenge.progressPercentage / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        challenge.completed ? Colors.green : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Campos reales de UserRewardsResponseDto: points, badgesUnlocked,
  // currentStreakDays, recentRewards (no "level"/"totalPoints"/"badges").
  Widget _buildRewardsCard(ThemeData theme, Map<String, dynamic> rewards) {
    final points = rewards['points'];
    final badges = rewards['badgesUnlocked'];
    final streak = rewards['currentStreakDays'];
    return _sectionCard(
      theme,
      title: 'Recompensas',
      icon: Icons.emoji_events,
      child: Row(
        children: [
          if (points != null)
            _metric(theme, '$points', 'pts', 'Puntos'),
          if (badges != null) _metric(theme, '$badges', '', 'Medallas'),
          if (streak != null) _metric(theme, '$streak', 'días', 'Racha'),
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
