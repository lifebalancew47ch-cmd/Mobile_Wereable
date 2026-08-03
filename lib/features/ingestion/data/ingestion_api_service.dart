import 'package:dio/dio.dart';

/// Elemento de signo vital del lote de sincronización (contrato Ingestion).
class VitalSignSyncItem {
  final DateTime timestamp;
  final int heartRate;
  final double hrv;
  final double spo2;
  final int steps;

  VitalSignSyncItem({
    required this.timestamp,
    required this.heartRate,
    required this.hrv,
    required this.spo2,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'heartRate': heartRate,
        'hrv': hrv,
        'spo2': spo2,
        'steps': steps,
      };
}

/// Elemento de sesión de actividad del lote de sincronización.
class ActivitySessionSyncItem {
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final int durationMinutes;

  ActivitySessionSyncItem({
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.durationMinutes,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toUtc().toIso8601String(),
        'endTime': endTime.toUtc().toIso8601String(),
        'type': type,
        'durationMinutes': durationMinutes,
      };
}

/// Elemento de alerta de sedentarismo del lote de sincronización.
class AlertSyncItem {
  final DateTime timestamp;
  final String type;
  final int durationMinutes;
  final bool acknowledged;

  AlertSyncItem({
    required this.timestamp,
    required this.type,
    required this.durationMinutes,
    required this.acknowledged,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'type': type,
        'durationMinutes': durationMinutes,
        'acknowledged': acknowledged,
      };
}

/// Lote de sincronización (Offline-First) -> `POST /api/v1/ingestion/sync`.
class SyncBatchRequest {
  final String clientBatchId;
  final String deviceId;
  final List<VitalSignSyncItem>? vitalSigns;
  final List<ActivitySessionSyncItem>? activitySessions;
  final List<AlertSyncItem>? alerts;

  SyncBatchRequest({
    required this.clientBatchId,
    required this.deviceId,
    this.vitalSigns,
    this.activitySessions,
    this.alerts,
  });

  Map<String, dynamic> toJson() => {
        'clientBatchId': clientBatchId,
        'deviceId': deviceId,
        if (vitalSigns != null)
          'vitalSigns': vitalSigns!.map((e) => e.toJson()).toList(),
        if (activitySessions != null)
          'activitySessions':
              activitySessions!.map((e) => e.toJson()).toList(),
        if (alerts != null) 'alerts': alerts!.map((e) => e.toJson()).toList(),
      };
}

/// Respuesta del Ingestion Service a un `SyncBatchRequest`.
class SyncBatchResponse {
  final String clientBatchId;
  final String status;
  final int acceptedItems;
  final int rejectedItems;
  final DateTime completedAtUtc;

  SyncBatchResponse({
    required this.clientBatchId,
    required this.status,
    required this.acceptedItems,
    required this.rejectedItems,
    required this.completedAtUtc,
  });

  factory SyncBatchResponse.fromJson(Map<String, dynamic> json) => SyncBatchResponse(
        clientBatchId: json['clientBatchId']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        acceptedItems: (json['acceptedItems'] as num?)?.toInt() ?? 0,
        rejectedItems: (json['rejectedItems'] as num?)?.toInt() ?? 0,
        completedAtUtc:
            DateTime.tryParse(json['completedAtUtc']?.toString() ?? '') ?? DateTime.now(),
      );
}

/// Cliente del Ingestion Service.
///
/// Sincronización batch (Offline-First) y registro de eventos. La resiliencia
/// (retry con backoff, nunca degradar TLS) la aporta el interceptor compartido
/// de [core/network/api_client.dart].
class IngestionApiService {
  final Dio _dio;

  IngestionApiService(this._dio);

  /// Envía un lote de sincronización de datos fisiológicos y eventos de
  /// inactividad almacenados localmente.
  Future<SyncBatchResponse> sync(SyncBatchRequest request) async {
    try {
      final response = await _dio.post('/ingestion/sync', data: request.toJson());
      final data = response.data;
      if (data is Map<String, dynamic>) return SyncBatchResponse.fromJson(data);
      if (data is Map && data['data'] is Map<String, dynamic>) {
        return SyncBatchResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw Exception('Respuesta inesperada del Ingestion Service.');
    } on DioException catch (e) {
      throw _mapError(e, 'Error al sincronizar');
    }
  }

  /// Registra un evento fisiológico/inactividad en el Ingestion Service.
  Future<void> postEvent({
    required String deviceId,
    required String eventType,
    required String source,
    required DateTime occurredAtUtc,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    try {
      await _dio.post('/ingestion/events', data: {
        'deviceId': deviceId,
        'eventType': eventType,
        'source': source,
        'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
        'payload': payload,
        if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
      });
    } on DioException catch (e) {
      throw _mapError(e, 'Error al registrar evento');
    }
  }

  Exception _mapError(DioException e, String fallback) {
    if (e.response != null) {
      final message = e.response?.data?['message'];
      return Exception(message?.toString() ?? fallback);
    }
    return Exception(fallback);
  }
}