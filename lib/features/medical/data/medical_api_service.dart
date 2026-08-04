import 'package:dio/dio.dart';

/// Lectura médica/fisiológica enviada a `POST /api/v1/medical/readings`.
class MedicalReading {
  final double heartRate;
  final double hrv;
  final double spo2;
  final int steps;
  final double? latitude;
  final double? longitude;
  final double? accelerometerX, accelerometerY, accelerometerZ;
  final double? gyroscopeX, gyroscopeY, gyroscopeZ;
  final double systolicBp;
  final double diastolicBp;
  final double weight;
  final double height;
  final String deviceId;
  final DateTime recordedAtUtc;

  MedicalReading({
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.steps,
    this.latitude,
    this.longitude,
    this.accelerometerX,
    this.accelerometerY,
    this.accelerometerZ,
    this.gyroscopeX,
    this.gyroscopeY,
    this.gyroscopeZ,
    this.systolicBp = 0,
    this.diastolicBp = 0,
    this.weight = 0,
    this.height = 0,
    this.deviceId = 'unknown',
    required this.recordedAtUtc,
  });

  Map<String, dynamic> toJson() => {
        'heartRate': heartRate,
        'hrv': hrv,
        'spo2': spo2,
        'steps': steps,
        'latitude': latitude,
        'longitude': longitude,
        'accelerometerX': accelerometerX,
        'accelerometerY': accelerometerY,
        'accelerometerZ': accelerometerZ,
        'gyroscopeX': gyroscopeX,
        'gyroscopeY': gyroscopeY,
        'gyroscopeZ': gyroscopeZ,
        'systolicBp': systolicBp,
        'diastolicBp': diastolicBp,
        'weight': weight,
        'height': height,
        'deviceId': deviceId,
        'recordedAtUtc': recordedAtUtc.toUtc().toIso8601String(),
      };
}

/// Última lectura médica del usuario.
class MedicalReadingResponse {
  final String id;
  final String userId;
  final double heartRate;
  final double hrv;
  final double spo2;
  final int steps;
  final DateTime recordedAtUtc;

  MedicalReadingResponse({
    required this.id,
    required this.userId,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.steps,
    required this.recordedAtUtc,
  });

  factory MedicalReadingResponse.fromJson(Map<String, dynamic> json) =>
      MedicalReadingResponse(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0,
        hrv: (json['hrv'] as num?)?.toDouble() ?? 0,
        spo2: (json['spo2'] as num?)?.toDouble() ?? 0,
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        recordedAtUtc:
            DateTime.tryParse(json['recordedAtUtc']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Cliente del Medical Data Service (lecturas clínicas, GPS, biometría).
class MedicalApiService {
  final Dio _dio;

  MedicalApiService(this._dio);

  Future<MedicalReadingResponse> addReading(MedicalReading reading) async {
    final response = await _call(() async {
      final r = await _dio.post('/medical/readings', data: reading.toJson());
      final data = r.data;
      return data is Map && data['data'] is Map
          ? (data['data'] as Map)
          : (data is Map ? data : const {});
    });
    return MedicalReadingResponse.fromJson(_asMap(response));
  }

  /// Envío batch de lecturas médicas (sincronización masiva).
  Future<void> addReadingsBatch(List<MedicalReading> readings) async {
    await _call(() => _dio.post(
          '/medical/readings/batch',
          data: readings.map((e) => e.toJson()).toList(),
        ));
  }

  Future<MedicalReadingResponse> getLatest() async {
    final response = await _call(
      () => _dio.get('/medical/latest'),
    );
    final data = response is Map && response['data'] is Map
        ? response['data'] as Map
        : (response is Map ? response : const {});
    return MedicalReadingResponse.fromJson(_asMap(data));
  }

  /// Historial de lecturas médicas (GET /medical/history).
  Future<List<MedicalReadingResponse>> getHistory({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _call(() => _dio.get('/medical/history', queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          'page': page,
          'pageSize': pageSize,
        }));
    if (response is List) {
      return response
          .whereType<Map<String, dynamic>>()
          .map(MedicalReadingResponse.fromJson)
          .toList();
    }
    if (response is Map && response['data'] is List) {
      return (response['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map(MedicalReadingResponse.fromJson)
          .toList();
    }
    return const [];
  }

  Future<dynamic> _call(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final message = e.response?.data?['message'];
      throw Exception(message?.toString() ?? 'Error del Medical Data Service');
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }
}