import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:lifebalance/features/ingestion/data/ingestion_api_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../security/helpers/fake_http_adapter.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('IngestionApiService (contrato real backapi-main)', () {
    late Dio dio;
    late FakeHttpClientAdapter adapter;
    late IngestionApiService api;

    setUp(() {
      final storage = MockSecureStorage();
      final tokenService = TokenService(storage);
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);

      dio = buildSecureDio('https://ingestion.example.com/api/v1',
          authService: tokenService);
      adapter = FakeHttpClientAdapter();
      dio.httpClientAdapter = adapter;
      api = IngestionApiService(dio);
    });

    test('POST /ingestion/sync envía el lote Offline-First correcto', () async {
      adapter.onRequest = (options) async => ResponseBody.fromString(
            '{"clientBatchId":"abc-123","status":"Completed",'
            '"acceptedItems":3,"rejectedItems":0,'
            '"completedAtUtc":"2026-08-03T10:00:00Z"}',
            200,
            headers: jsonHeaders(),
          );

      final result = await api.sync(SyncBatchRequest(
        clientBatchId: 'abc-123',
        deviceId: 'dev-1',
        vitalSigns: [
          VitalSignSyncItem(
            timestamp: DateTime.utc(2026, 8, 3, 10),
            heartRate: 72,
            hrv: 42.0,
            spo2: 98.0,
            steps: 1200,
          ),
        ],
      ));

      final req = adapter.captured.single;
      expect(req.path, '/ingestion/sync');
      expect(req.method, 'POST');

      final body = req.data as Map<String, dynamic>;
      expect(body['clientBatchId'], 'abc-123');
      expect(body['deviceId'], 'dev-1');
      final vitals = body['vitalSigns'] as List;
      expect(vitals.single['heartRate'], 72);
      expect(vitals.single['spo2'], 98.0);
      expect(vitals.single['steps'], 1200);

      expect(result.status, 'Completed');
      expect(result.acceptedItems, 3);
    });

    test('500 transitorio se reintenta con el interceptor compartido', () async {
      var calls = 0;
      adapter.onRequest = (options) async {
        calls++;
        if (calls < 2) {
          return ResponseBody.fromString('{"message":"boom"}', 500,
              headers: jsonHeaders());
        }
        return ResponseBody.fromString(
          '{"clientBatchId":"x","status":"Completed","acceptedItems":0,'
          '"rejectedItems":0,"completedAtUtc":"2026-08-03T10:00:00Z"}',
          200,
          headers: jsonHeaders(),
        );
      };

      final result = await api.sync(SyncBatchRequest(clientBatchId: 'x', deviceId: 'd'));
      expect(calls, greaterThanOrEqualTo(2));
      expect(result.status, 'Completed');
    });
  });
}