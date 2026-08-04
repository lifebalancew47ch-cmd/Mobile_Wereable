import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';
import '../../data/ml_api_service.dart';
import '../../../auth/presentation/providers/profile_provider.dart';

final mlApiServiceProvider = Provider<MlApiService>((ref) {
  final dio = ref.watch(mlApiClientProvider);
  return MlApiService(dio);
});

/// Tendencia de riesgo (GET /ml/risk-trend/{userId}).
final mlRiskTrendProvider = FutureProvider<RiskTrend>((ref) async {
  final api = ref.watch(mlApiServiceProvider);
  final user = await ref.watch(profileProvider.future);
  return await api.getRiskTrend(user.id);
});

/// Recomendaciones del modelo (GET /ml/recommendations/{userId}).
final mlRecommendationsProvider = FutureProvider<List<RecommendationDto>>((ref) async {
  final api = ref.watch(mlApiServiceProvider);
  final user = await ref.watch(profileProvider.future);
  return await api.getRecommendations(user.id);
});

/// Ejecuta una predicción (POST /ml/predict) alimentada con la última
/// lectura local + datos del wearable en vivo.
final mlPredictionProvider = FutureProvider<PredictionResponse>((ref) async {
  final api = ref.watch(mlApiServiceProvider);
  final db = SecureDatabaseService.instance;

  var heartRate = 0.0;
  var hrv = 0.0;
  var spo2 = 0.0;
  var steps = 0;

  final database = await db.database;
  final rows = await database.query('vital_signs', orderBy: 'timestamp DESC', limit: 1);
  if (rows.isNotEmpty) {
    final row = rows.first;
    heartRate = (row['heart_rate'] as num?)?.toDouble() ?? 0;
    hrv = (row['hrv'] as num?)?.toDouble() ?? 0;
    spo2 = (row['spo2'] as num?)?.toDouble() ?? 0;
    steps = (row['steps'] as num?)?.toInt() ?? 0;
  }

  final inactiveMinutes = await _inactiveMinutes(db);

  return await api.predict(
    heartRate: heartRate,
    hrv: hrv,
    spo2: spo2,
    steps: steps,
    sedentaryMinutes: inactiveMinutes.toDouble(),
  );
});

Future<int> _inactiveMinutes(SecureDatabaseService db) async {
  try {
    final today = await db.getActivitySessionsForDay(DateTime.now());
    var idle = 0;
    for (final session in today) {
      final type = session['type'] as String?;
      if (type == 'idle' || type == 'alert') {
        idle += (session['duration_minutes'] as int?) ?? 0;
      }
    }
    return idle;
  } catch (_) {
    return 0;
  }
}
