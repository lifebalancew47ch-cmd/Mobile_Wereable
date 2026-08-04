import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gamification_api_service.dart';
import '../../../fog/presentation/providers/fog_providers.dart';

/// Perfil de gamificación desde la nube (GET /gamification/profile).
final gamificationProfileProvider = FutureProvider<GamificationProfile>((ref) async {
  final api = ref.watch(gamificationApiServiceProvider);
  return await api.getProfile();
});

/// Leaderboard global (GET /gamification/leaderboard).
final gamificationLeaderboardProvider = FutureProvider<List<LeaderboardItem>>((ref) async {
  final api = ref.watch(gamificationApiServiceProvider);
  return await api.getLeaderboard(take: 20);
});
