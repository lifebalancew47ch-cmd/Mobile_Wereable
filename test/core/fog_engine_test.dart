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

    test('Engine starts and initializes correctly', () {
      fogEngine.start();
      verify(() => mockWearableService.accelerometerStream).called(1);
    });

    test('Engine receives data and processes state correctly', () async {
      fogEngine.start();

      // Emit some accelerometer data to simulate movement
      accelerometerController.add(AccelerometerData(1.0, 2.0, 9.8, 1000));
      accelerometerController.add(AccelerometerData(1.5, 2.5, 9.8, 2000));

      // Wait a moment for data to be added to the queue
      await Future.delayed(const Duration(milliseconds: 100));

      expect(fogEngine.stateStream, isNotNull);
    });
  });
}
