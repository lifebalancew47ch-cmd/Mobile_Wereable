import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MASVS-RESILIENCE-1..3 (Nivel R): Root/Jailbreak en arranque, empaquetado
/// release sin debuggable, ofuscación R8/ProGuard y datos de depuración
/// excluidos del artefacto. Los checks son regresión estática sobre el
/// build real; los checks dinámicos viven en security/scripts/apk_forensics.
void main() {
  group('MASVS-RESILIENCE-1: Root/Jailbreak bloquea el arranque', () {
    test('main.dart chequea jailbreak ANTES de runApp (fail-closed)', () {
      final src = File('lib/main.dart').readAsStringSync();

      final jailbreakPos = src.indexOf('FlutterJailbreakDetection.jailbroken');
      final runAppPos = src.indexOf('runApp(');

      expect(jailbreakPos, greaterThanOrEqualTo(0),
          reason: 'Debe existir detección de root/jailbreak');
      expect(runAppPos, greaterThan(jailbreakPos),
          reason: 'El chequeo debe ejecutarse antes de arrancar la UI');
    });

    test('El chequeo termina el proceso (exit) en dispositivos comprometidos',
        () {
      final src = File('lib/main.dart').readAsStringSync();
      final block = src.substring(src.indexOf('bool jailbroken'),
          src.indexOf('runApp('));
      expect(block, contains('exit('),
          reason: 'MASVS-R-1: proceso debe terminar, no degradarse');
      expect(block, contains('exit(0)'),
          reason: 'Salida limpia sin ejecutar código de la app');
    });
  });

  group('MASVS-RESILIENCE-2: Build release endurecido', () {
    test('isMinifyEnabled + isShrinkResources activos en release', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      final releaseBlock =
          gradle.substring(gradle.indexOf('buildTypes'), gradle.indexOf('flutter {'));
      expect(releaseBlock, contains('isMinifyEnabled = true'),
          reason: 'R8/ProGuard (minify) obligatorio para release');
      expect(releaseBlock, contains('isShrinkResources = true'),
          reason: 'Eliminar recursos muertos para reducir superficie');
      expect(releaseBlock, contains('proguardFiles('),
          reason: 'Debe referenciar reglas ProGuard');
    });

    test('El APK release NO debe declarar android:debuggable', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, isNot(contains('android:debuggable="true"')));
      expect(manifest, isNot(contains('android:debuggable = "true"')));
    });

    test('android:allowBackup no debe exponer datos de salud', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final applicationTag = manifest.substring(
        manifest.indexOf('<application'),
        manifest.indexOf('</application>'),
      );
      expect(applicationTag, isNot(contains('android:allowBackup="true"')));
    });

    test('Network Security Config activa para prohibir cleartext', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:networkSecurityConfig="@xml/network_security_config"'));
    });
  });

  group('MASVS-RESILIENCE-3: Datos de debug fuera del artefacto final', () {
    test('El artefacto release no puede incluir sentencias print/debugPrint '
        'con datos sensibles (PII audit por CI: semgrep + audit_source)', () {
      // Regresión mínima: ningún print( en lib/ con interpolaciones sensibles.
      final libDir = Directory('lib');
      final offenders = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final (index, line) in entity.readAsLinesSync().indexed) {
          if (line.contains('print(') ||
              (line.contains('debugPrint(') &&
                  RegExp(
                          r'(token|password|secret|jwt|authorization|credential)',
                          caseSensitive: false)
                      .hasMatch(line))) {
            offenders.add('${entity.path}:${index + 1} -> $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Volcado de datos sensibles a consola detectado:\n'
              '${offenders.join('\n')}');
    });
  });

  group('MASVS-CODE-1: Ausencia de secrets hardcodeados en fuentes', () {
    test('Sin API keys / private keys embebidas en lib/ ni assets', () {
      final targets = <Directory>[
        Directory('lib'),
        Directory('android/app/src'),
      ];
      final secretPattern = RegExp(
        r'''(sk[-_]?live|api[-_]?key|secret[-_]?key|private[-_]?key|-----BEGIN (RSA|EC|PRIVATE) KEY-----)'''
        r'''|(?:api[_-]?key|secret|password|token)\s*[:=]\s*["\'][A-Za-z0-9_\-\.]{16,}["\']''',
        caseSensitive: false,
      );
      final offenders = <String>[];
      final binaryExtensions = {'.png', '.webp', '.jpg', '.jpeg', '.gif', '.so'};
      for (final dir in targets) {
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (entity.path.endsWith('.g.dart') || entity.path.endsWith('.lock')) {
            continue;
          }
          if (binaryExtensions.any(entity.path.endsWith)) continue;
          for (final (index, line) in entity.readAsLinesSync().indexed) {
            if (secretPattern.hasMatch(line)) {
              offenders.add('${entity.path}:${index + 1} -> ${line.trim()}');
            }
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'Secretos hardcodeados detectados:\n${offenders.join('\n')}');
    });
  });
}
