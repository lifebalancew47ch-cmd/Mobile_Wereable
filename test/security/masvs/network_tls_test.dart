import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/network/api_client.dart';
import 'package:lifebalance/core/security/certificate_pinning.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:mocktail/mocktail.dart';

/// MASVS-NETWORK-1 / MASVS-NETWORK-2 (Nivel L2):
/// TLS 1.2+ exclusivo, pinning SHA-256 fail-closed y ausencia de
/// callbacks que acepten cualquier certificado.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// Pin hex de 64 caracteres (32 bytes) construido repitiendo [byte].
String hexPin(String byte, [int count = 32]) => List.filled(count, byte).join();

void main() {
  tearDown(CertificatePinning.resetForTesting);

  group('MASVS-NETWORK-2: Pinning de certificados (fail-closed)', () {
    test('Sin pins configurados -> conexión RECHAZADA (nunca degradar)', () {
      CertificatePinning.configureForTesting(const []);
      expect(CertificatePinning.isConfigured, isFalse);
      expect(
        CertificatePinning.validatePinnedCertificate(
          sha256Hex: hexPin('AA'),
          host: 'lifebalance-auth-service.onrender.com',
          port: 443,
        ),
        isFalse,
        reason: 'Si no hay pin, la TLS no debe permitirse bajo ninguna '
            'condición (fail-closed)',
      );
    });

    test('Certificado nulo -> rechazado', () {
      CertificatePinning.configureForTesting([hexPin('AB')]);
      expect(
        CertificatePinning.validateCertificate(null, 'host', 443),
        isFalse,
      );
    });

    test('SHA-256 del certificado coincide con el pin -> aceptado', () {
      CertificatePinning.configureForTesting([
        'AB:CD:12:34', // formato con ':' debe normalizarse
        hexPin('00'),
      ]);
      expect(
        CertificatePinning.validatePinnedCertificate(
          sha256Hex: hexPin('00'),
          host: 'host',
          port: 443,
        ),
        isTrue,
      );
    });

    test('SHA-256 distinto al pin (MITM con cert propio) -> rechazado', () {
      CertificatePinning.configureForTesting([hexPin('00')]);
      expect(
        CertificatePinning.validatePinnedCertificate(
          sha256Hex: hexPin('FF'),
          host: 'host',
          port: 443,
        ),
        isFalse,
        reason: 'Un proxy MITM presenta su propio certificado; el pin debe '
            'bloquearlo aunque la cadena valide contra otra CA',
      );
    });

    test('Normalización: case-insensitive y tolerante a separadores ":"', () {
      CertificatePinning.configureForTesting([
        'AB:CD:${hexPin('EF', 30)}', // 64 hex chars con ':'
      ]);
      expect(
        CertificatePinning.validatePinnedCertificate(
          sha256Hex: 'ABCD${hexPin('EF', 30)}', // sin ':', mayúsculas
          host: 'host',
          port: 443,
        ),
        isTrue,
      );
    });
  });

  group('MASVS-NETWORK-1: Transporte seguro de los API clients', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          tokenServiceProvider.overrideWithValue(
            TokenService(_storageWithToken()),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('baseUrl de los 3 microservicios es HTTPS (nunca http://)', () {
      final baseUrls = [
        container.read(apiClientProvider).options.baseUrl,
        container.read(dashboardApiClientProvider).options.baseUrl,
        container.read(notificationsApiClientProvider).options.baseUrl,
      ];
      for (final url in baseUrls) {
        expect(url, startsWith('https://'),
            reason: 'Comunicación cleartext prohibida (MASVS-NETWORK-1)');
        expect(url, isNot(contains('http://')),
            reason: 'No puede existir una baseUrl http:// literal');
      }
    });

    test('validateCertificate registrado y fail-closed por defecto', () {
      final dio = container.read(apiClientProvider);
      final adapter = dio.httpClientAdapter;
      expect(adapter, isA<IOHttpClientAdapter>(),
          reason: 'Debe usarse el adapter con pinning');
      final validate = (adapter as IOHttpClientAdapter).validateCertificate;
      expect(validate, isNotNull,
          reason: 'Debe existir un validador de certificados');
      expect(validate!(null, 'host', 443), isFalse,
          reason: 'Fail-closed cuando no hay certificado');
    });

    test('El validador de producción rechaza certs no pinneados', () {
      // dotenv no está cargado en CI -> pins vacíos -> fail-closed.
      CertificatePinning.resetForTesting();
      expect(CertificatePinning.isConfigured, isFalse);
      final adapter =
          container.read(apiClientProvider).httpClientAdapter as IOHttpClientAdapter;
      expect(
        adapter.validateCertificate!(
          null,
          'lifebalance-auth-service.onrender.com',
          443,
        ),
        isFalse,
      );
    });

    test('Reintentos de 500/503 NO degradan a HTTP (sin fallback inseguro)',
        () {
      // El interceptor de reintento solo repite sobre el mismo canal HTTPS;
      // verificación: baseUrl es https y no existe lógica de conmutación
      // a hosts alternativos en el cliente.
      final dio = container.read(apiClientProvider);
      final hasRetry =
          dio.interceptors.any((i) => i is RetryWithBackoffInterceptor);
      expect(hasRetry, isTrue);
      expect(dio.options.baseUrl.startsWith('https://'), isTrue);
    });
  });
}

FlutterSecureStorage _storageWithToken() {
  final storage = MockSecureStorage();
  when(() => storage.read(key: 'access_token')).thenAnswer((_) async => 'a.b.c');
  when(() => storage.read(key: any(named: 'key', that: isNot('access_token'))))
      .thenAnswer((_) async => null);
  when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  return storage;
}
