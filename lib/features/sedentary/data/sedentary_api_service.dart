import 'package:dio/dio.dart';

/// Respuesta de puntuación sedentaria diaria (Sedentary Score 0-100).
class SedentaryScore {
  final String userId;
  final double score;
  final String riskLevel;
  final DateTime recordedAtUtc;

  SedentaryScore({
    required this.userId,
    required this.score,
    required this.riskLevel,
    required this.recordedAtUtc,
  });

  factory SedentaryScore.fromJson(Map<String, dynamic> json) => SedentaryScore(
        userId: json['userId']?.toString() ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
        riskLevel: json['riskLevel']?.toString() ?? '',
        recordedAtUtc: DateTime.tryParse(json['recordedAtUtc']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Progreso frente a objetivos de actividad diaria.
class SedentaryProgress {
  final int dailySteps;
  final int dailyStepsTarget;
  final double activeMinutes;
  final int activeMinutesTarget;
  final double stepsProgress;
  final double activeProgress;

  SedentaryProgress({
    required this.dailySteps,
    required this.dailyStepsTarget,
    required this.activeMinutes,
    required this.activeMinutesTarget,
    required this.stepsProgress,
    required this.activeProgress,
  });

  factory SedentaryProgress.fromJson(Map<String, dynamic> json) => SedentaryProgress(
        dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 0,
        dailyStepsTarget: (json['dailyStepsTarget'] as num?)?.toInt() ?? 0,
        activeMinutes: (json['activeMinutes'] as num?)?.toDouble() ?? 0,
        activeMinutesTarget: (json['activeMinutesTarget'] as num?)?.toInt() ?? 0,
        stepsProgress: (json['stepsProgress'] as num?)?.toDouble() ?? 0,
        activeProgress: (json['activeProgress'] as num?)?.toDouble() ?? 0,
      );
}

/// Objetivo de actividad diaria configurable (GET/POST /sedentary/goals).
class SedentaryGoal {
  final String id;
  final String userId;
  final int dailyStepsTarget;
  final int activeMinutesTarget;
  final DateTime updatedAtUtc;

  SedentaryGoal({
    required this.id,
    required this.userId,
    required this.dailyStepsTarget,
    required this.activeMinutesTarget,
    required this.updatedAtUtc,
  });

  factory SedentaryGoal.fromJson(Map<String, dynamic> json) => SedentaryGoal(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        dailyStepsTarget: (json['dailyStepsTarget'] as num?)?.toInt() ?? 8000,
        activeMinutesTarget: (json['activeMinutesTarget'] as num?)?.toInt() ?? 30,
        updatedAtUtc:
            DateTime.tryParse(json['updatedAtUtc']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Cliente del Sedentary Engine (score, progreso, registro de actividad).
class SedentaryApiService {
  final Dio _dio;

  SedentaryApiService(this._dio);

  Future<SedentaryScore> getScore() async {
    final response = await _call(() => _dio.get('/sedentary/score'));
    return SedentaryScore.fromJson(_unwrap(response));
  }

  Future<SedentaryProgress> getProgress() async {
    final response = await _call(() => _dio.get('/sedentary/progress'));
    return SedentaryProgress.fromJson(_unwrap(response));
  }

  Future<SedentaryGoal> getGoals() async {
    final response = await _call(() => _dio.get('/sedentary/goals'));
    return SedentaryGoal.fromJson(_unwrap(response));
  }

  Future<void> setGoals({
    required int dailyStepsTarget,
    required int activeMinutesTarget,
  }) async {
    await _call(() => _dio.post('/sedentary/goals', data: {
          'dailyStepsTarget': dailyStepsTarget,
          'activeMinutesTarget': activeMinutesTarget,
        }));
  }

  /// Registra la actividad diaria del usuario en el motor.
  Future<void> recordActivity({
    required int dailySteps,
    required double activeMinutes,
    required double sedentaryHours,
    double caloriesBurned = 0,
    List<int>? hourlyHeatmap,
    String? companyId,
    DateTime? recordedAtUtc,
  }) async {
    await _call(() => _dio.post('/sedentary/activity', data: {
          'dailySteps': dailySteps,
          'activeMinutes': activeMinutes,
          'sedentaryHours': sedentaryHours,
          'caloriesBurned': caloriesBurned,
          if (hourlyHeatmap != null) 'hourlyHeatmap': hourlyHeatmap,
          if (companyId != null) 'companyId': companyId,
          if (recordedAtUtc != null)
            'recordedAtUtc': recordedAtUtc.toUtc().toIso8601String(),
        }));
  }

  Future<dynamic> _call(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final message = e.response?.data?['message'];
      throw Exception(message?.toString() ?? 'Error del Sedentary Engine');
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map) {
      final nested = data['data'];
      if (nested is Map<String, dynamic>) return nested;
      return Map<String, dynamic>.from(data);
    }
    return const {};
  }
}