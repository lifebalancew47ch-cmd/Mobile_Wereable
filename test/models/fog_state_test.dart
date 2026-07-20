import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/models/fog_state.dart';

void main() {
  group('FogState Tests', () {
    test('Should create FogState correctly', () {
      final now = DateTime.now();
      final state = FogState(
        status: ActivityStatus.active,
        inactiveMinutes: 0,
        lastMovement: now,
      );

      expect(state.status, ActivityStatus.active);
      expect(state.inactiveMinutes, 0);
      expect(state.lastMovement, now);
    });

    test('copyWith should update specified fields', () {
      final now = DateTime.now();
      final originalState = FogState(
        status: ActivityStatus.idle,
        inactiveMinutes: 10,
        lastMovement: now,
      );

      final updatedState = originalState.copyWith(
        status: ActivityStatus.alertTriggered,
        inactiveMinutes: 45,
      );

      expect(updatedState.status, ActivityStatus.alertTriggered);
      expect(updatedState.inactiveMinutes, 45);
      expect(updatedState.lastMovement, now); // Should remain the same
    });

    test('copyWith should retain original fields if no new values provided', () {
      final now = DateTime.now();
      final originalState = FogState(
        status: ActivityStatus.idle,
        inactiveMinutes: 10,
        lastMovement: now,
      );

      final updatedState = originalState.copyWith();

      expect(updatedState.status, ActivityStatus.idle);
      expect(updatedState.inactiveMinutes, 10);
      expect(updatedState.lastMovement, now);
    });
  });
}
