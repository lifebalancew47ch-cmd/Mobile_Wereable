import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  group('NotificationService Tests', () {
    late NotificationService notificationService;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      notificationService = NotificationService();
    });

    test('Should be a singleton', () {
      final instance1 = NotificationService();
      final instance2 = NotificationService();
      expect(identical(instance1, instance2), true);
    });
  });
}
