import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/fog_engine.dart';
import 'package:lifebalance/services/notification_service.dart';
import 'package:lifebalance/services/wearable_communication_service.dart';
import 'package:mocktail/mocktail.dart';

class MockWearableCommunicationService extends Mock
    implements WearableCommunicationService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('FogEngine Tests', () {
    late FogEngine fogEngine;
    late MockWearableCommunicationService mockWearableService;
    late MockNotificationService mockNotificationService;
    late StreamController<AccelerometerData> accelerometerController;

    setUp(() {
      mockWearableService = MockWearableCommunicationService();
      mockNotificationService = MockNotificationService();
      accelerometerController = StreamController<AccelerometerData>.broadcast();

      when(() => mockWearableService.accelerometerStream)
          .thenAnswer((_) => accelerometerController.stream);

      fogEngine = FogEngine(mockWearableService, mockNotificationService);
    });

    tearDown(() {
      fogEngine.stop();
      accelerometerController.close();
    });

    test('Engine starts and initializes correctly', () async {
      await fogEngine.start();
      verify(() => mockWearableService.accelerometerStream).called(1);
      expect(fogEngine.isRunning, isTrue);
    });

    test('Engine receives data and processes state correctly', () async {
      await fogEngine.start();

      // Emit some accelerometer data to simulate movement
      accelerometerController.add(AccelerometerData(1.0, 2.0, 9.8, 1000));
      accelerometerController.add(AccelerometerData(1.5, 2.5, 9.8, 2000));

      // Wait a moment for data to be added to the queue
      await Future.delayed(const Duration(milliseconds: 100));

      expect(fogEngine.stateStream, isNotNull);
      expect(fogEngine.samplesProcessed, greaterThanOrEqualTo(2));
    });

    test('Pause stops processing and resume restarts it', () async {
      await fogEngine.start();
      expect(fogEngine.isRunning, isTrue);

      fogEngine.pause();
      expect(fogEngine.isRunning, isFalse);

      accelerometerController.add(AccelerometerData(1.0, 2.0, 9.8, 1000));
      await Future.delayed(const Duration(milliseconds: 50));

      final pausedSamples = fogEngine.samplesProcessed;

      fogEngine.resume();
      expect(fogEngine.isRunning, isTrue);

      accelerometerController.add(AccelerometerData(2.0, 2.0, 9.8, 2000));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fogEngine.samplesProcessed, greaterThan(pausedSamples));
    });

    test('Stop releases resources and marks engine as stopped', () async {
      await fogEngine.start();
      accelerometerController.add(AccelerometerData(1.0, 2.0, 9.8, 1000));
      await Future.delayed(const Duration(milliseconds: 50));

      fogEngine.stop();
      expect(fogEngine.isRunning, isFalse);
      expect(fogEngine.samplesProcessed, greaterThanOrEqualTo(1));
    });
  });
}
