import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ml_provider.dart';
import '../../data/ml_api_service.dart';

class MlPredictionScreen extends ConsumerWidget {
  const MlPredictionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionAsync = ref.watch(mlPredictionProvider);
    final trendAsync = ref.watch(mlRiskTrendProvider);
    final recommendationsAsync = ref.watch(mlRecommendationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Predicción de riesgo')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mlPredictionProvider);
          ref.invalidate(mlRiskTrendProvider);
          ref.invalidate(mlRecommendationsProvider);
          try {
            await Future.wait([
              ref.read(mlPredictionProvider.future),
              ref.read(mlRiskTrendProvider.future),
              ref.read(mlRecommendationsProvider.future),
            ]);
          } catch (_) {}
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPredictionCard(context, ref, predictionAsync),
            const SizedBox(height: 16),
            _buildTrendCard(context, ref, trendAsync),
            const SizedBox(height: 16),
            _buildRecommendationsCard(context, ref, recommendationsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard(
      BuildContext context, WidgetRef ref, AsyncValue<PredictionResponse> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorTile(
            message: 'No se pudo ejecutar la predicción.\n$e',
            onRetry: () => ref.invalidate(mlPredictionProvider),
          ),
          data: (prediction) {
            final riskColor = _riskColor(prediction.riskLevel);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Riesgo predictivo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: (prediction.riskScore / 100).clamp(0.0, 1.0),
                            strokeWidth: 9,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(riskColor),
                          ),
                          Text(
                            '${(prediction.riskScore * 100).round()}%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prediction.riskLevel.isEmpty ? 'Sin nivel' : prediction.riskLevel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: riskColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Modelo: ${prediction.modelVersion.isEmpty ? '--' : prediction.modelVersion}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Predicho ${_formatDate(prediction.predictedAtUtc)}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (prediction.recommendedActions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('Acciones recomendadas',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final action in prediction.recommendedActions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrendCard(
      BuildContext context, WidgetRef ref, AsyncValue<RiskTrend> async) {
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
            message: 'No se pudo cargar la tendencia de riesgo.\n$e',
            onRetry: () => ref.invalidate(mlRiskTrendProvider),
          ),
          data: (trend) {
            final color = _riskColor(trend.riskLevel);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tendencia de riesgo',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.trending_up, color: color),
                    const SizedBox(width: 8),
                    Text(
                      'Nivel: ${trend.riskLevel.isEmpty ? '--' : trend.riskLevel}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (trend.sedentaryRiskScore / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                if (trend.recommendedActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final action in trend.recommendedActions.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right, size: 18),
                          Expanded(child: Text(action)),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard(
      BuildContext context, WidgetRef ref, AsyncValue<List<RecommendationDto>> async) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recomendaciones personalizadas',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorTile(
                message: 'No se pudieron cargar las recomendaciones.\n$e',
                onRetry: () => ref.invalidate(mlRecommendationsProvider),
              ),
              data: (recommendations) {
                if (recommendations.isEmpty) {
                  return const Text('Sin recomendaciones por ahora.',
                      style: TextStyle(color: Colors.grey));
                }
                return Column(
                  children: [
                    for (final recommendation in recommendations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Icon(Icons.recommend_outlined,
                                  size: 18, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recommendation.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (recommendation.category.isNotEmpty)
                                    Text(
                                      recommendation.category,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: theme.colorScheme.primary),
                                    ),
                                  const SizedBox(height: 2),
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
                );
              },
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
