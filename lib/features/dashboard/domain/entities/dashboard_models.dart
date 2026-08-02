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
