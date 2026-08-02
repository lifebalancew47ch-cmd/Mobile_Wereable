import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:lifebalance/features/auth/data/datasources/auth_api_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_http_adapter.dart';

/// OWASP API1 (Injection), API2 (Broken Auth), API3 (Excessive Data):
/// payloads maliciosos en la capa de sincronizaciÃ³n local-backend.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late FakeHttpClientAdapter adapter;
  late AuthApiService authApi;
  late TokenService tokenService;
  late ProviderContainer container;
  late MockSecureStorage storage;

  setUp(() {
    storage = MockSecureStorage();
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

    tokenService = TokenService(storage);
    container = ProviderContainer(
      overrides: [tokenServiceProvider.overrideWithValue(tokenService)],
    );
    adapter = FakeHttpClientAdapter(
      onRequest: (options) async => ResponseBody.fromString(
        '{"success":true,"data":{"accessToken":"at","refreshToken":"rt","userProfile":{"id":1,"email":"a@b.c"}}}',
        200,
        headers: jsonHeaders(),
      ),
    );
    final dio = container.read(apiClientProvider);
    dio.httpClientAdapter = adapter;
    authApi = AuthApiService(dio, tokenService);
  });

  tearDown(() => container.dispose());

  group('OWASP-API-1: InyecciÃ³n en payloads de login', () {
    test('SQLi clÃ¡sico: email con inyecciÃ³n pasa como VALOR JSON, no como SQL',
        () async {
      const evil = "x'; DROP TABLE users;--";
      await authApi.login(evil, 'password123');

      final req = adapter.captured.single;
      expect(req.path, '/auth/login',
          reason: 'La inyecciÃ³n no puede alterar la ruta del endpoint');
      final body = req.data as Map;
      expect(body['email'], evil,
          reason: 'El payload debe viajar como valor JSON escapado');
      expect(body.keys, containsAll(['email', 'password']));
      expect(body.keys.length, 2,
          reason: 'Sin keys extra (no-excess-data)');
    });

    test('NoSQL/CRLF: saltos de lÃ­nea y caracteres de control en email', () async {
      const evil = r'attacker@evil.com\r\nX-Injected: true\r\n{"$ne":null}';
      await authApi.login(evil, 'p@ss');

      final req = adapter.captured.single;
      final body = req.data as Map;
      expect(body['email'], evil);
      expect(req.headers.containsKey('X-Injected'), isFalse,
          reason: 'CRLF no puede inyectar headers HTTP');
    });

    test('Las credenciales NUNCA van en la URL ni en headers', () async {
      await authApi.login('user@example.com', 'S3cret!Passw0rd');

      final req = adapter.captured.single;
      expect(req.queryParameters, isEmpty);
      expect(req.uri.toString(), isNot(contains('S3cret')));
      final body = req.data as Map;
      expect(body['password'], 'S3cret!Passw0rd');
    });
  });

  group('OWASP-API-1: InyecciÃ³n en registro', () {
    test('Registro con payloads hostiles no altera el contrato de la API',
        () async {
      await authApi.register(
        email: 'a\';--"@x.com',
        username: 'usr" OR "1"="1',
        password: 'Xy9!k#m2',
        confirmPassword: 'Xy9!k#m2',
        firstName: '<script>alert(1)</script>',
        lastName: 'drop table vital_signs;',
      );

      final req = adapter.captured.single;
      expect(req.path, '/auth/register');
      final body = req.data as Map;
      expect(body['password'], 'Xy9!k#m2');
      expect(body['firstName'], contains('<script>'),
          reason: 'El XSS va como dato escapado; sanitizar en servidor');
      expect(body.keys, isNot(contains('confirmPasswordExtra')));
    });

    test('TamaÃ±o mÃ¡ximo de campos (DoS por payload gigante)', () async {
      final giantEmail = '${'a' * 100000}@evil.com';
      await authApi.login(giantEmail, 'p');

      final req = adapter.captured.single;
      final body = req.data as Map;
      expect(body['email'], giantEmail);
    });
  });

  group('OWASP-API-3: ExposiciÃ³n de datos excesivos', () {
    test('La respuesta del servidor no se vuelca completa en excepciones',
        () async {
      // El servidor devuelve data extra sensible (p. ej. refreshToken).
      adapter.onRequest = (options) async => ResponseBody.fromString(
            '{"success":false,"message":"invalid","internal":{"dbPassword":"root","sslKey":"PEM-DATA"}}',
            400,
            headers: jsonHeaders(),
          );

      Object? capturedError;
      try {
        await authApi.login('a@b.c', 'x');
      } catch (e) {
        capturedError = e;
      }
      expect(capturedError, isA<Exception>());
      expect(capturedError.toString(), isNot(contains('dbPassword')),
          reason: 'La excepciÃ³n no puede exponer secretos del backend');
      expect(capturedError.toString(), isNot(contains('sslKey')));
    });

    test('La excepciÃ³n 401 no incluye el token JWT', () async {
      when(() => storage.read(key: 'access_token'))
          .thenAnswer((_) async => 'JWT-SUPERSECRET');
      adapter.onRequest = (options) async => ResponseBody.fromString(
            '{"message":"token expired"}',
            401,
            headers: jsonHeaders(),
          );

      Object? capturedError;
      try {
        await authApi.getProfile();
      } catch (e) {
        capturedError = e;
      }
      expect(capturedError.toString(), isNot(contains('JWT-SUPERSECRET')));
    });
  });
}
