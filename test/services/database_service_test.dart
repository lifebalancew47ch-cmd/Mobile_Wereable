import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/data/datasources/secure_database_service.dart';

void main() {
  group('SecureDatabaseService Tests', () {
    test('Should have a singleton instance', () {
      final instance1 = SecureDatabaseService.instance;
      final instance2 = SecureDatabaseService.instance;

      expect(identical(instance1, instance2), true);
    });
  });
}
