import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// OWASP-API-9 / MASVS-CODE-1 / PCI-DSS 10.5:
/// Auditoría estática de logs: prohibido volcar tokens, credenciales o datos
/// de salud (PII) a consolas de producción, Sentry, Crashlytics o logs.
void main() {
  group('PII log audit: lib/', () {
    late List<File> dartFiles;

    setUpAll(() {
      dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    List<String> sensitiveLines(File file) {
      return file
          .readAsLinesSync()
          .asMap()
          .entries
          .where((entry) =>
              entry.value.contains('print(') ||
              entry.value.contains('debugPrint(') ||
              entry.value.contains('log(') ||
              entry.value.contains('dart:developer'))
          .where((entry) =>
              RegExp(
                r'(access[_-]?token|refresh[_-]?token|bearer\s|password|passwd|secret|jwt|authorization|heart[_-]?rate|spo2|credential)',
                caseSensitive: false,
              ).hasMatch(entry.value))
          .map((e) => '  ${file.path}:${e.key + 1} -> ${e.value.trim()}')
          .toList();
    }

    test('Ningún print/debugPrint/log con datos sensibles o PII de salud',
        () {
      final offenders = <String>[];
      for (final file in dartFiles) {
        offenders.addAll(sensitiveLines(file));
      }
      expect(offenders, isEmpty,
          reason: 'Volcado de PII/credenciales a consola:\n'
              '${offenders.join('\n')}');
    });

    test('El interceptor de logs de dio (LogInterceptor) no expone headers',
        () {
      final offenders = <String>[];
      for (final file in dartFiles) {
        final src = file.readAsStringSync();
        if (src.contains('LogInterceptor') &&
            (src.contains('requestHeader') ||
                src.contains('responseBody') ||
                src.contains('requestBody'))) {
          // requestBody/responseBody pueden contener PII de salud.
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'LogInterceptor con bodies/headers habilitados en '
              'producción: $offenders');
    });

    test('Firebase Crashlytics/Sentry no recibe tokens ni credenciales',
        () {
      final offenders = <String>[];
      for (final file in dartFiles) {
        final src = file.readAsStringSync();
        final hasReporter = src.contains('Crashlytics') ||
            src.contains('Sentry') ||
            src.contains('reportError');
        if (hasReporter) {
          for (final (index, line) in src.split('\n').indexed) {
            if (RegExp(r'(token|password|secret)',
                    caseSensitive: false)
                .hasMatch(line)) {
              offenders.add('${file.path}:${index + 1}');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Reportadores de errores con datos sensibles: $offenders');
    });
  });

  group('PII log audit: datos de salud en sincronización', () {
    test('SyncService no loguea vital signs (HR/SpO2) ni credenciales', () {
      final src = File('lib/services/sync_service.dart').readAsStringSync();
      final logLines = src
          .split('\n')
          .where((l) => l.contains('debugPrint') || l.contains('print'))
          .toList();
      for (final line in logLines) {
        expect(line, isNot(contains('heartRate')));
        expect(line, isNot(contains('spo2')));
        expect(line, isNot(contains('token')));
        expect(line, isNot(contains('password')));
      }
    });

    test('BackgroundService/WatchService no loguean datos biométricos', () {
      for (final path in [
        'lib/services/background_service.dart',
        'lib/services/watch_service.dart',
      ]) {
        if (!File(path).existsSync()) continue;
        final src = File(path).readAsStringSync();
        final offenders = src
            .split('\n')
            .where((l) =>
                (l.contains('debugPrint') || l.contains('print')) &&
                RegExp(r'(heart[_-]?rate|spo2|hrv|password|token|email)',
                    caseSensitive: false)
                    .hasMatch(l))
            .toList();
        expect(offenders, isEmpty, reason: '$path: $offenders');
      }
    });
  });

  group('Secretos en configuración y binarios', () {
    test('pubspec.yaml no expone secretos en assets', () {
      final src = File('pubspec.yaml').readAsStringSync();
      final envAssets = RegExp(r'- \.env[^\s]*').allMatches(src).toList();
      expect(envAssets, isNotEmpty,
          reason: 'Los .env se cargan como assets del bundle');
      for (final m in envAssets) {
        expect(m.group(0), anyOf('- .env.development', '- .env.production'),
            reason: 'Evitar variantes locales no previstas en el bundle');
      }
    });

    test('Los archivos .env están en .gitignore (no llegan al repo ni a CI)',
        () async {
      final result = await Process.run(
        'git',
        ['check-ignore', '.env.development', '.env.production'],
      );
      expect(result.exitCode, 0,
          reason: 'git check-ignore debe devolver ambos .env; si falla, '
              'los secretos están trackeados en el repositorio');
    });

    test('CI/scripts: ningún secreto en la raíz del repo (estático)', () {
      final offenders = <String>[];
      for (final path in ['pubspec.yaml', 'android/app/build.gradle.kts']) {
        final src = File(path).readAsStringSync();
        if (RegExp(
          r'''(sk[-_]?live|-----BEGIN|google-services\.json|api[_-]?key\s*[:=]\s*["\'][A-Za-z0-9]{16,})''',
          caseSensitive: false,
        ).hasMatch(src)) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'Secretos detectados en config del repo: $offenders');
    });
  });
}
