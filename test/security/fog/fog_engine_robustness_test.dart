import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/fog_engine.dart';
import 'package:lifebalance/services/notification_service.dart';
import 'package:lifebalance/services/wearable_communication_service.dart';
import 'package:mocktail/mocktail.dart';

/// OWASP API1 / MASVS-CODE-1 aplicado al motor edge (FogEngine):
/// el sensor/reloj es una superficie de entrada no confiable; valores
/// NaN/±Infinity inyectados NO deben romper la detección (alerta silenciosa).
class MockWearableCommunicationService extends Mock
    implements WearableCommunicationService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  group('FogEngine robustness: entrada de sensor hostil', () {
    late FogEngine engine;
    late StreamController<AccelerometerData> controller;

    setUp(() {
      final wearable = MockWearableCommunicationService();
      final notifications = MockNotificationService();
      controller = StreamController<AccelerometerData>.broadcast();
      when(() => wearable.accelerometerStream)
          .thenAnswer((_) => controller.stream);
      engine = FogEngine(wearable, notifications);
    });

    tearDown(() {
      engine.stop();
      controller.close();
    });

    test('NaN en un eje es descartado: no envenena la varianza', () async {
      engine.start();

      controller.add(AccelerometerData(double.nan, 0, 9.8, 0));
      controller.add(AccelerometerData(double.infinity, 0, 0, 0));
      controller.add(AccelerometerData(0, double.negativeInfinity, 0, 0));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.samplesProcessed, 0,
          reason: 'Muestras no finitas deben descartarse (fail-safe)');
      expect(engine.isRunning, isTrue,
          reason: 'El motor no debe colapsar ante entrada maliciosa');
    });

    test('Muestras válidas tras valores NaN siguen procesándose', () async {
      engine.start();

      controller.add(AccelerometerData(double.nan, 0, 9.8, 0));
      controller.add(AccelerometerData(1.0, 1.0, 9.8, 1000));
      controller.add(AccelerometerData(1.5, 2.0, 9.8, 2000));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.samplesProcessed, 2);
    });

    test('Magnitud con overflow numérico (1e308) no rompe la varianza',
        () async {
      engine.start();

      controller.add(AccelerometerData(1e308, 1e308, 1e308, 0));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.samplesProcessed, 0,
          reason: 'x²+y²+z² = inf -> debe descartarse, no generar NaN');
    });

    test('Ráfaga de muestras legítimas mantiene estado idle consistente',
        () async {
      engine.start();

      // Magnitudes prácticamente constantes -> ventana idle.
      for (var i = 0; i < 50; i++) {
        controller.add(AccelerometerData(0.1, 0.1, 9.81 + (i % 3) * 0.001, i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.samplesProcessed, 50);
      expect(engine.windowsAnalyzed, 0); // la ventana de 30s aún no cierra
    });

    test('Sin muestras en una ventana (sensor silenciado) no crashea', () async {
      engine.start();
      // No se emite nada; forzar análisis interno no debe lanzar.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(engine.isRunning, isTrue);
    });
  });

  group('FogEngine: integridad del estado ante flujos rápidos', () {
    test('Datos interleaved (válidos + maliciosos) no alteran contadores',
        () async {
      final wearable = MockWearableCommunicationService();
      final notifications = MockNotificationService();
      final controller = StreamController<AccelerometerData>.broadcast();
      when(() => wearable.accelerometerStream)
          .thenAnswer((_) => controller.stream);
      final engine = FogEngine(wearable, notifications);
      engine.start();

      final payloads = <AccelerometerData>[
        AccelerometerData(0, 0, 9.8, 0),
        AccelerometerData(double.nan, double.nan, double.nan, 0),
        AccelerometerData(1, 1, 9.8, 0),
        AccelerometerData(double.maxFinite, double.maxFinite, 0, 0),
        AccelerometerData(2, 2, 9.8, 0),
      ];
      for (final p in payloads) {
        controller.add(p);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(engine.samplesProcessed, 3);
      expect(engine.alertsTriggered, 0);
      engine.stop();
      await controller.close();
    });
  });
}
