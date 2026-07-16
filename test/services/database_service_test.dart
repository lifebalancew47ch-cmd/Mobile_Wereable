import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/services/database_service.dart';

void main() {
  group('DatabaseService Tests', () {
    test('Should have a singleton instance', () {
      final instance1 = DatabaseService.instance;
      final instance2 = DatabaseService.instance;

      expect(identical(instance1, instance2), true);
    });
  });
}
