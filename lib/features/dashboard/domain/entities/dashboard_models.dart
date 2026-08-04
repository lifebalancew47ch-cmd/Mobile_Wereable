class DashboardKpis {
  final String userId;
  final double bmi;
  final double heartRate;
  final int dailySteps;
  final double caloriesBurned;

  DashboardKpis({
    required this.userId,
    required this.bmi,
    required this.heartRate,
    required this.dailySteps,
    required this.caloriesBurned,
  });

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    return DashboardKpis(
      userId: json['userId']?.toString() ?? '',
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
      heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
      dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DashboardSummary {
  final String userId;
  final String fullName;
  final int dailySteps;
  final double activeMinutes;
  final int points;
  final int streakDays;

  DashboardSummary({
    required this.userId,
    required this.fullName,
    required this.dailySteps,
    required this.activeMinutes,
    required this.points,
    required this.streakDays,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] ?? '',
      dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 0,
      activeMinutes: (json['activeMinutes'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Progreso individual frente a objetivos (GET /dashboard/individual/progress).
class DashboardProgress {
  final int dailySteps;
  final int dailyStepsTarget;
  final double activeMinutes;
  final int activeMinutesTarget;
  final double stepsProgress;
  final double activeProgress;

  DashboardProgress({
    required this.dailySteps,
    required this.dailyStepsTarget,
    required this.activeMinutes,
    required this.activeMinutesTarget,
    required this.stepsProgress,
    required this.activeProgress,
  });

  factory DashboardProgress.fromJson(Map<String, dynamic> json) => DashboardProgress(
        dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 0,
        dailyStepsTarget: (json['dailyStepsTarget'] as num?)?.toInt() ?? 0,
        activeMinutes: (json['activeMinutes'] as num?)?.toDouble() ?? 0,
        activeMinutesTarget: (json['activeMinutesTarget'] as num?)?.toInt() ?? 0,
        stepsProgress: (json['stepsProgress'] as num?)?.toDouble() ?? 0,
        activeProgress: (json['activeProgress'] as num?)?.toDouble() ?? 0,
      );
}

/// Recomendaciones individuales (GET /dashboard/individual/recommendations).
class DashboardRecommendation {
  final String id;
  final String title;
  final String description;
  final String category;
  final int priority;

  DashboardRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
  });

  factory DashboardRecommendation.fromJson(Map<String, dynamic> json) =>
      DashboardRecommendation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

/// Biometría individual (GET /dashboard/individual/biometrics).
class DashboardBiometrics {
  final double bmi;
  final double heartRate;
  final double systolicBp;
  final double diastolicBp;
  final double weight;
  final double height;

  DashboardBiometrics({
    required this.bmi,
    required this.heartRate,
    required this.systolicBp,
    required this.diastolicBp,
    required this.weight,
    required this.height,
  });

  factory DashboardBiometrics.fromJson(Map<String, dynamic> json) =>
      DashboardBiometrics(
        bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
        heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
        systolicBp: (json['systolicBp'] as num?)?.toDouble() ?? 0,
        diastolicBp: (json['diastolicBp'] as num?)?.toDouble() ?? 0,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
      );
}

/// Estadísticas individuales (GET /dashboard/individual/statistics).
class DashboardStatistics {
  final int totalSessions;
  final int activeSessions;
  final int alertCount;
  final double averageDurationMinutes;
  final String streakLabel;

  DashboardStatistics({
    required this.totalSessions,
    required this.activeSessions,
    required this.alertCount,
    required this.averageDurationMinutes,
    required this.streakLabel,
  });

  factory DashboardStatistics.fromJson(Map<String, dynamic> json) =>
      DashboardStatistics(
        totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
        activeSessions: (json['activeSessions'] as num?)?.toInt() ?? 0,
        alertCount: (json['alertCount'] as num?)?.toInt() ?? 0,
        averageDurationMinutes:
            (json['averageDurationMinutes'] as num?)?.toDouble() ?? 0,
        streakLabel: json['streakLabel']?.toString() ?? '',
      );
}

