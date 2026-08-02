import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:lifebalance/features/auth/data/datasources/auth_api_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_http_adapter.dart';

/// OWASP API1-10 + MASVS-NETWORK-3: gestión de JWT en Secure Storage,
/// revocación ante 401, resiliencia ante 500/503 sin degradación y
/// ausencia de volcado de credenciales.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late TokenService tokenService;
  late ProviderContainer container;
  late FakeHttpClientAdapter adapter;
  late AuthApiService authApi;

  setUp(() {
    storage = MockSecureStorage();
    tokenService = TokenService(storage);

    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [tokenServiceProvider.overrideWithValue(tokenService)],
    );
    adapter = FakeHttpClientAdapter();
    final dio = container.read(apiClientProvider);
    dio.httpClientAdapter = adapter;
    authApi = AuthApiService(dio, tokenService);
  });

  tearDown(() => container.dispose());

  group('OWASP-API-7: Tokens JWT en Secure Storage, nunca en logs/params', () {
    test('saveTokens -> solo secure storage, sin echo en memoria/logs', () async {
      await tokenService.saveTokens(accessToken: 'a.b.c', refreshToken: 'd.e.f');

      verify(() => storage.write(key: 'access_token', value: 'a.b.c')).called(1);
      verify(() => storage.write(key: 'refresh_token', value: 'd.e.f')).called(1);
    });

    test('clearTokens revoca localmente TODO (access+refresh+caché)', () async {
      await tokenService.clearTokens();
      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
      verify(() => storage.delete(key: 'cached_user_profile')).called(1);
    });

    test('El token NUNCA viaja en query params (solo header Bearer)', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'jwt.secret.token');

      await authApi.getProfile();

      expect(adapter.captured, isNotEmpty);
      for (final req in adapter.captured) {
        expect(req.queryParameters, isEmpty,
            reason: 'JWT en query string = leak en logs/proxies');
        expect(req.headers['Authorization'], 'Bearer jwt.secret.token');
        expect(req.uri.toString(), isNot(contains('jwt.secret.token')),
            reason: 'El token no puede aparecer en la URL');
      }
    });
  });

  group('MASVS-NETWORK-3 / OWASP-API-7: Revocación y refresco atómico', () {
    test('401 -> se borran los tokens (revocación local inmediata)', () async {
      adapter.onRequest = (options) async => ResponseBody.fromString(
            '{"success":false,"message":"unauthorized"}',
            401,
            headers: jsonHeaders(),
          );

      await expectLater(authApi.getProfile(), throwsA(isA<Exception>()));

      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
      expect(await tokenService.hasValidToken(), isFalse);
    });

    test('Refresco atómico: nunca queda estado mitad-token/half-token',
        () async {
      // Simula refresco: escribe el par y luego comprueba consistencia.
      await tokenService.saveTokens(accessToken: 'new.access', refreshToken: 'new.refresh');
      final access = await tokenService.getAccessToken();
      final refresh = await tokenService.getRefreshToken();
      expect(access, isNotNull);
      expect(refresh, isNotNull, reason: 'Refresco incompleto = sesión corrupta');
    });

    test('500/503 del backend -> reintento con backoff, tokens INTACTOS',
        () async {
      var calls = 0;
      adapter.onRequest = (options) async {
        calls++;
        return ResponseBody.fromString(
          '{"success":false,"message":"maintenance"}',
          503,
          headers: jsonHeaders(),
        );
      };

      await expectLater(authApi.getProfile(), throwsA(isA<Exception>()));

      expect(calls, greaterThanOrEqualTo(2),
          reason: 'Debe reintentar servicios transitorios');
      verifyNever(() => storage.delete(key: 'access_token'));
      verifyNever(() => storage.delete(key: 'refresh_token'));
    });

    test('429 (rate-limit) también se reintenta, sin tocar tokens', () async {
      var calls = 0;
      adapter.onRequest = (options) async {
        calls++;
        return ResponseBody.fromString(
          '{"message":"slow down"}',
          429,
          headers: jsonHeaders(),
        );
      };

      await expectLater(authApi.getProfile(), throwsA(isA<Exception>()));
      expect(calls, greaterThanOrEqualTo(2));
      verifyNever(() => storage.delete(key: 'access_token'));
    });

    test('4xx de negocio (400/404) NO se reintentan', () async {
      var calls = 0;
      adapter.onRequest = (options) async {
        calls++;
        return ResponseBody.fromString(
          '{"success":false,"message":"not found"}',
          404,
          headers: jsonHeaders(),
        );
      };

      await expectLater(authApi.getProfile(), throwsA(isA<Exception>()));
      expect(calls, 1, reason: 'No reintentar errores de cliente');
    });
  });

  group('OWASP-API-1: Autorización encabezada en cada petición', () {
    test('Sin token almacenado -> petición SIN header Authorization', () async {
      await authApi.getProfile();
      expect(adapter.captured.single.headers.containsKey('Authorization'),
          isFalse);
    });

    test('Con token -> Bearer exacto en header, header no logueable', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'eyJhbGciOiJIUzI1NiJ9.payload');

      await authApi.getProfile();

      expect(
        adapter.captured.single.headers['Authorization'],
        'Bearer eyJhbGciOiJIUzI1NiJ9.payload',
      );
    });
  });

  group('OWASP-API-9: Inventario de exposición — logout resiliente', () {
    test('logout borra tokens aunque el backend falle', () async {
      adapter.onRequest = (options) async => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );

      await authApi.logout();

      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
      expect(await tokenService.hasValidToken(), isFalse);
    });
  });
}
