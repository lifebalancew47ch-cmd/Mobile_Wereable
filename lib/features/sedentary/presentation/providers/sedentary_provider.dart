import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import '../../data/sedentary_api_service.dart';

final sedentaryApiServiceProvider = Provider<SedentaryApiService>((ref) {
  final dio = ref.watch(sedentaryApiClientProvider);
  return SedentaryApiService(dio);
});

/// Puntuación sedentaria diaria (GET /sedentary/score).
final sedentaryScoreProvider = FutureProvider<SedentaryScore>((ref) async {
  final api = ref.watch(sedentaryApiServiceProvider);
  return await api.getScore();
});

/// Progreso frente a objetivos diarios (GET /sedentary/progress).
final sedentaryProgressProvider = FutureProvider<SedentaryProgress>((ref) async {
  final api = ref.watch(sedentaryApiServiceProvider);
  return await api.getProgress();
});

/// Objetivos de actividad diaria (GET /sedentary/goals).
final sedentaryGoalsProvider = FutureProvider<SedentaryGoal>((ref) async {
  final api = ref.watch(sedentaryApiServiceProvider);
  return await api.getGoals();
});

/// Actualiza los objetivos de actividad (POST /sedentary/goals).
final updateSedentaryGoalsProvider = FutureProvider.family<void, ({int dailyStepsTarget, int activeMinutesTarget})>((ref, goals) async {
  final api = ref.watch(sedentaryApiServiceProvider);
  await api.setGoals(
    dailyStepsTarget: goals.dailyStepsTarget,
    activeMinutesTarget: goals.activeMinutesTarget,
  );
});
