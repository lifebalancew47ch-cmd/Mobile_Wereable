import 'package:dio/dio.dart';

/// Perfil de gamificación del usuario (puntos, nivel, racha).
class GamificationProfile {
  final String userId;
  final int points;
  final int level;
  final int badgesUnlocked;
  final int currentStreakDays;
  final List<String> recentRewards;

  GamificationProfile({
    required this.userId,
    required this.points,
    required this.level,
    required this.badgesUnlocked,
    required this.currentStreakDays,
    required this.recentRewards,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) =>
      GamificationProfile(
        userId: json['userId']?.toString() ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 0,
        badgesUnlocked: (json['badgesUnlocked'] as num?)?.toInt() ?? 0,
        currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
        recentRewards: (json['recentRewards'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Elemento del leaderboard (retos amistosos familiares/empresariales).
class LeaderboardItem {
  final String userId;
  final int points;
  final int level;
  final int position;

  LeaderboardItem({
    required this.userId,
    required this.points,
    required this.level,
    required this.position,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) => LeaderboardItem(
        userId: json['userId']?.toString() ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        level: (json['level'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt() ?? 0,
      );
}

/// Cliente del Gamification Service (pausas activas, logros, leaderboard).
class GamificationApiService {
  final Dio _dio;

  GamificationApiService(this._dio);

  Future<GamificationProfile> getProfile() async {
    final response = await _request(
      () => _dio.get('/gamification/profile'),
    );
    return GamificationProfile.fromJson(_unwrap(response));
  }

  /// Registra un evento de gamificación (p. ej. pausa activa completada).
  Future<void> sendEvent({
    required String eventType,
    required int points,
    String? rewardName,
    String? familyId,
    String? tenantId,
  }) async {
    await _request(() => _dio.post('/gamification/events', data: {
          'eventType': eventType,
          'points': points,
          if (rewardName != null) 'rewardName': rewardName,
          if (familyId != null) 'familyId': familyId,
          if (tenantId != null) 'tenantId': tenantId,
        }));
  }

  Future<List<LeaderboardItem>> getLeaderboard({int take = 20}) async {
    final response = await _request(
      () => _dio.get('/gamification/leaderboard', queryParameters: {'take': take}),
    );
    final items = response is List
        ? response.whereType<Map<String, dynamic>>().toList()
        : (response is Map && response['data'] is List)
            ? (response['data'] as List).whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
    return items.map(LeaderboardItem.fromJson).toList();
  }

  Future<GamificationProfile> getRewards(String userId) async {
    final response = await _request(
      () => _dio.get('/gamification/user/$userId/rewards'),
    );
    return GamificationProfile.fromJson(_unwrap(response));
  }

  Future<dynamic> _request(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final message = e.response?.data?['message'];
      throw Exception(message?.toString() ?? 'Error de gamificación');
    }
  }

  /// Extrae el objeto útil cuando la respuesta llega envuelta o directa.
  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) {
        return data['data'] as Map<String, dynamic>;
      }
      return data;
    }
    if (data is Map && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return const {};
  }
}