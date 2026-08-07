import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/security/encryption_service.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:mocktail/mocktail.dart';

/// MASVS-STORAGE-1 / MASVS-STORAGE-2 (Nivel L2):
/// Credenciales y tokens en flutter_secure_storage (Keychain/Keystore),
/// NUNCA en SharedPreferences. Clave AES-256 de la BD con entropía real.
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('MASVS-STORAGE-1: Tokens JWT en Secure Storage', () {
    late MockSecureStorage storage;
    late TokenService service;

    setUp(() {
      storage = MockSecureStorage();
      service = TokenService(storage);
    });

    test('saveTokens persiste access + refresh en secure storage', () async {
      when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      await service.saveTokens(
        accessToken: 'jwt.access.payload',
        refreshToken: 'jwt.refresh.payload',
      );

      verify(() => storage.write(key: 'access_token', value: 'jwt.access.payload'))
          .called(1);
      verify(() => storage.write(key: 'refresh_token', value: 'jwt.refresh.payload'))
          .called(1);
      // Ninguna escritura debe ocurrir en otro key (p. ej. shared prefs).
      verifyNever(
        () => storage.write(
          key: any(named: 'key', that: isNot(anyOf('access_token', 'refresh_token', 'user_cache'))),
          value: any(named: 'value'),
        ),
      );
    });

    test('clearTokens elimina tokens y caché de perfil', () async {
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});

      await service.clearTokens();

      verify(() => storage.delete(key: 'access_token')).called(1);
      verify(() => storage.delete(key: 'refresh_token')).called(1);
      verify(() => storage.delete(key: 'user_cache')).called(1);
    });

    test('hasValidToken es false tras clearTokens', () async {
      when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);

      expect(await service.hasValidToken(), isFalse);
    });

    test('Tokens JWT se devuelven al vuelo desde secure storage', () async {
      when(() => storage.read(key: 'access_token')).thenAnswer((_) async => 'a.b.c');

      expect(await service.getAccessToken(), 'a.b.c');
      verify(() => storage.read(key: 'access_token')).called(1);
    });
  });

  group('MASVS-STORAGE-2: Clave de cifrado de BD (AES-256)', () {
    test('La clave generada es base64url de EXACTAMENTE 32 bytes (AES-256)', () {
      final key = EncryptionService.generateRandomKey();
      final decoded = base64Url.decode(key);
      expect(decoded.length, 32, reason: 'AES-256 requiere 256 bits (32 bytes)');
      expect(decoded.toSet().where((b) => b != 0).length, greaterThan(16),
          reason: 'La clave no debe ser débil/trivial');
    });

    test('Claves distintas en generaciones sucesivas (Random.secure)', () {
      final a = EncryptionService.generateRandomKey();
      final b = EncryptionService.generateRandomKey();
      expect(a, isNot(equals(b)));
    });

    test('La clave NUNCA se loguea ni se guarda en SharedPreferences (estático)',
        () {
      final source = File('lib/core/security/encryption_service.dart').readAsStringSync();
      expect(source, contains('FlutterSecureStorage'),
          reason: 'La clave debe vivir en Keystore/Keychain');
      expect(source, isNot(contains('shared_preferences')));
      expect(source, isNot(contains('debugPrint')),
          reason: 'Prohibido volcar la clave a consola');
      expect(source, isNot(contains('print(')));
    });
  });

  group('MASVS-STORAGE-1: No hay almacenamiento plano de tokens', () {
    test('token_service.dart usa únicamente flutter_secure_storage', () {
      final source = File('lib/core/security/token_service.dart').readAsStringSync();
      expect(source, contains('flutter_secure_storage'));
      expect(source, isNot(contains('shared_preferences')),
          reason: 'Los JWT jamás deben ir a SharedPreferences');
      expect(source, isNot(contains('getApplicationDocumentsDirectory')));
    });

    test('SharedPreferences no se usa para credenciales en todo lib/ (estático)',
        () {
      final libDir = Directory('lib');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        // Solo es riesgo si el archivo importa el PLUGIN shared_preferences
        // (almacenamiento plano) y además declara literales de credencial;
        // mencionar "SharedPreferences" en comentarios/docs no es un riesgo.
        final usesFlatStorage = src.contains('package:shared_preferences') ||
            src.contains('SharedPreferences.getInstance');
        if (usesFlatStorage &&
            RegExp(
              r'''["\'](access|refresh)?_?(token|password|jwt|secret)["\']''',
              caseSensitive: false,
            ).hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Credenciales detectadas junto a SharedPreferences: $offenders');
    });
  });
}
