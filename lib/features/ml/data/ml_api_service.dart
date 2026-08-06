import 'package:dio/dio.dart';

/// Predicción de riesgo de la ML en la nube.
class PredictionResponse {
  final String userId;
  final double riskScore;
  final String riskLevel;
  final List<String> recommendedActions;
  final String modelVersion;
  final DateTime predictedAtUtc;

  PredictionResponse({
    required this.userId,
    required this.riskScore,
    required this.riskLevel,
    required this.recommendedActions,
    required this.modelVersion,
    required this.predictedAtUtc,
  });

  factory PredictionResponse.fromJson(Map<String, dynamic> json) =>
      PredictionResponse(
        userId: json['userId']?.toString() ?? '',
        riskScore: (json['riskScore'] as num?)?.toDouble() ?? 0,
        riskLevel: json['riskLevel']?.toString() ?? '',
        recommendedActions:
            (json['recommendedActions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        modelVersion: json['modelVersion']?.toString() ?? '',
        predictedAtUtc:
            DateTime.tryParse(json['predictedAtUtc']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Tendencia de riesgo sedentario.
class RiskTrend {
  final String userId;
  final String riskLevel;
  final double sedentaryRiskScore;
  final List<String> recommendedActions;

  RiskTrend({
    required this.userId,
    required this.riskLevel,
    required this.sedentaryRiskScore,
    required this.recommendedActions,
  });

  factory RiskTrend.fromJson(Map<String, dynamic> json) => RiskTrend(
        userId: json['userId']?.toString() ?? '',
        riskLevel: json['riskLevel']?.toString() ?? '',
        sedentaryRiskScore: (json['sedentaryRiskScore'] as num?)?.toDouble() ?? 0,
        recommendedActions:
            (json['recommendedActions'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

/// Recomendación generada por el modelo (GET /ml/recommendations/{userId}).
class RecommendationDto {
  final String id;
  final String category;
  final String title;
  final String description;
  final double priorityScore;

  RecommendationDto({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.priorityScore,
  });

  factory RecommendationDto.fromJson(Map<String, dynamic> json) => RecommendationDto(
        id: json['id']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        priorityScore: (json['priorityScore'] as num?)?.toDouble() ?? 0,
      );
}

/// Cliente de la ML Prediction Service (riesgo de sedentarismo predictivo).
class MlApiService {
  final Dio _dio;

  MlApiService(this._dio);

  Future<PredictionResponse> predict({
    required double heartRate,
    required double hrv,
    required double spo2,
    required int steps,
    required double sedentaryMinutes,
    double sleepHours = 0,
  }) async {
    final response = await _call(() => _dio.post('/ml/predict', data: {
          'heartRate': heartRate,
          'hrv': hrv,
          'spo2': spo2,
          'steps': steps,
          'sedentaryMinutes': sedentaryMinutes,
          'sleepHours': sleepHours,
        }));
    return PredictionResponse.fromJson(_unwrap(response));
  }

  Future<RiskTrend> getRiskTrend(String userId) async {
    final response = await _call(() => _dio.get('/ml/risk-trend/$userId'));
    return RiskTrend.fromJson(_unwrap(response));
  }

  Future<List<RecommendationDto>> getRecommendations(String userId) async {
    final response = await _call(() => _dio.get('/ml/recommendations/$userId'));
    return _unwrapList(response)
        .map(RecommendationDto.fromJson)
        .toList();
  }

  Future<dynamic> _call(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final message = e.response?.data?['message'];
      throw Exception(message?.toString() ?? 'Error de la ML Prediction Service');
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    final payload = data is Response ? data.data : data;
    if (payload is Map) {
      final nested = payload['data'];
      if (nested is Map<String, dynamic>) return nested;
      return Map<String, dynamic>.from(payload);
    }
    return const {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic data) {
    final payload = data is Response ? data.data : data;
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map && payload['data'] is List) {
      return (payload['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}