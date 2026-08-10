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

/// Progreso individual semanal (GET /dashboard/individual/progress).
/// Contrato real del backend: `IndividualProgressResponse(UserId,
/// WeeklyGoalCompletionPercentage, DaysActive)` — no son metas de
/// pasos/minutos (esas viven en /dashboard/individual/goals como retos).
class DashboardProgress {
  final double weeklyGoalCompletionPercentage;
  final int daysActive;

  DashboardProgress({
    required this.weeklyGoalCompletionPercentage,
    required this.daysActive,
  });

  factory DashboardProgress.fromJson(Map<String, dynamic> json) => DashboardProgress(
        weeklyGoalCompletionPercentage:
            (json['weeklyGoalCompletionPercentage'] as num?)?.toDouble() ?? 0,
        daysActive: (json['daysActive'] as num?)?.toInt() ?? 0,
      );
}

/// Snapshot diario de actividad (GET /dashboard/individual/activity).
/// El backend devuelve un único objeto agregado del día, no un feed de
/// eventos: `IndividualActivityResponse(UserId, SedentaryActivityResponseDto)`.
class DashboardActivitySnapshot {
  final int dailySteps;
  final double activeMinutes;
  final double sedentaryHours;
  final double caloriesBurned;
  final List<int> hourlyHeatmap;

  DashboardActivitySnapshot({
    required this.dailySteps,
    required this.activeMinutes,
    required this.sedentaryHours,
    required this.caloriesBurned,
    required this.hourlyHeatmap,
  });

  factory DashboardActivitySnapshot.fromJson(Map<String, dynamic> json) =>
      DashboardActivitySnapshot(
        dailySteps: (json['dailySteps'] as num?)?.toInt() ?? 0,
        activeMinutes: (json['activeMinutes'] as num?)?.toDouble() ?? 0,
        sedentaryHours: (json['sedentaryHours'] as num?)?.toDouble() ?? 0,
        caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0,
        hourlyHeatmap: (json['hourlyHeatmap'] as List?)
                ?.map((e) => (e as num?)?.toInt() ?? 0)
                .toList() ??
            const [],
      );
}

/// Reto/meta individual (GET /dashboard/individual/goals).
/// Contrato real: `ChallengeProgressDto(ChallengeId, Title,
/// ProgressPercentage, Completed)` — una lista de retos, no un target fijo
/// de pasos/minutos.
class DashboardChallenge {
  final String challengeId;
  final String title;
  final double progressPercentage;
  final bool completed;

  DashboardChallenge({
    required this.challengeId,
    required this.title,
    required this.progressPercentage,
    required this.completed,
  });

  factory DashboardChallenge.fromJson(Map<String, dynamic> json) => DashboardChallenge(
        challengeId: json['challengeId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        progressPercentage: (json['progressPercentage'] as num?)?.toDouble() ?? 0,
        completed: json['completed'] as bool? ?? false,
      );
}

/// Recomendaciones individuales (GET /dashboard/individual/recommendations).
class DashboardRecommendation {
  final String id;
  final String title;
  final String description;
  final String category;
  final double priorityScore;

  DashboardRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priorityScore,
  });

  factory DashboardRecommendation.fromJson(Map<String, dynamic> json) =>
      DashboardRecommendation(
        // El swagger real del Dashboard Service serializa el campo como
        // "recommendationId" (record RecommendationDto(RecommendationId, ...)),
        // igual que en MLPredictionService — no "id". Igual "priorityScore"
        // (double), no "priority" (int).
        id: json['recommendationId']?.toString() ?? json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        priorityScore: (json['priorityScore'] as num?)?.toDouble() ?? 0,
      );
}

/// Biometría individual (GET /dashboard/individual/biometrics).
class DashboardBiometrics {
  final double bmi;
  final double heartRate;
  final int steps;
  final double systolicBp;
  final double diastolicBp;
  final double weight;
  final double height;

  DashboardBiometrics({
    required this.bmi,
    required this.heartRate,
    this.steps = 0,
    required this.systolicBp,
    required this.diastolicBp,
    required this.weight,
    required this.height,
  });

  factory DashboardBiometrics.fromJson(Map<String, dynamic> json) =>
      DashboardBiometrics(
        bmi: (json['bmi'] as num?)?.toDouble() ?? 0,
        heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        systolicBp: (json['systolicBp'] as num?)?.toDouble() ?? 0,
        diastolicBp: (json['diastolicBp'] as num?)?.toDouble() ?? 0,
        weight: (json['weight'] as num?)?.toDouble() ?? 0,
        height: (json['height'] as num?)?.toDouble() ?? 0,
      );
}

/// Estadísticas individuales (GET /dashboard/individual/statistics).
/// Contrato real: `IndividualStatisticsResponse(UserId, ActiveHoursThisWeek,
/// SedentaryHoursThisWeek, AverageHeartRate)`.
class DashboardStatistics {
  final double activeHoursThisWeek;
  final double sedentaryHoursThisWeek;
  final double averageHeartRate;

  DashboardStatistics({
    required this.activeHoursThisWeek,
    required this.sedentaryHoursThisWeek,
    required this.averageHeartRate,
  });

  factory DashboardStatistics.fromJson(Map<String, dynamic> json) =>
      DashboardStatistics(
        activeHoursThisWeek: (json['activeHoursThisWeek'] as num?)?.toDouble() ?? 0,
        sedentaryHoursThisWeek:
            (json['sedentaryHoursThisWeek'] as num?)?.toDouble() ?? 0,
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble() ?? 0,
      );
}

/// Recompensas y Racha individual (GET /dashboard/individual/rewards).
class DashboardRewards {
  final int points;
  final int currentStreakDays;
  final int badgesUnlocked;

  DashboardRewards({
    required this.points,
    required this.currentStreakDays,
    required this.badgesUnlocked,
  });

  factory DashboardRewards.fromJson(Map<String, dynamic> json) =>
      DashboardRewards(
        points: (json['points'] as num?)?.toInt() ?? 0,
        currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ??
            (json['streakDays'] as num?)?.toInt() ??
            0,
        badgesUnlocked: (json['badgesUnlocked'] as num?)?.toInt() ??
            (json['badgesUnlockedCount'] as num?)?.toInt() ??
            0,
      );
}


