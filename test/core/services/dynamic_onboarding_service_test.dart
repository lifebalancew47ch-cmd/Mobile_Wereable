import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/services/dynamic_onboarding_service.dart';

void main() {
  group('DynamicOnboardingService - TimePhase Detection', () {
    test('Detects Madrugada phase (00:00 a 05:59)', () {
      final t1 = DateTime(2026, 8, 4, 0, 0);
      final t2 = DateTime(2026, 8, 4, 3, 30);
      final t3 = DateTime(2026, 8, 4, 5, 59);

      expect(DynamicOnboardingService.getTimePhase(t1), TimePhase.madrugada);
      expect(DynamicOnboardingService.getTimePhase(t2), TimePhase.madrugada);
      expect(DynamicOnboardingService.getTimePhase(t3), TimePhase.madrugada);
    });

    test('Detects Mañana phase (06:00 a 11:59)', () {
      final t1 = DateTime(2026, 8, 4, 6, 0);
      final t2 = DateTime(2026, 8, 4, 9, 15);
      final t3 = DateTime(2026, 8, 4, 11, 59);

      expect(DynamicOnboardingService.getTimePhase(t1), TimePhase.manana);
      expect(DynamicOnboardingService.getTimePhase(t2), TimePhase.manana);
      expect(DynamicOnboardingService.getTimePhase(t3), TimePhase.manana);
    });

    test('Detects Mediodía phase (12:00 a 14:59)', () {
      final t1 = DateTime(2026, 8, 4, 12, 0);
      final t2 = DateTime(2026, 8, 4, 13, 30);
      final t3 = DateTime(2026, 8, 4, 14, 59);

      expect(DynamicOnboardingService.getTimePhase(t1), TimePhase.mediodia);
      expect(DynamicOnboardingService.getTimePhase(t2), TimePhase.mediodia);
      expect(DynamicOnboardingService.getTimePhase(t3), TimePhase.mediodia);
    });

    test('Detects Tarde phase (15:00 a 19:59)', () {
      final t1 = DateTime(2026, 8, 4, 15, 0);
      final t2 = DateTime(2026, 8, 4, 17, 45);
      final t3 = DateTime(2026, 8, 4, 19, 59);

      expect(DynamicOnboardingService.getTimePhase(t1), TimePhase.tarde);
      expect(DynamicOnboardingService.getTimePhase(t2), TimePhase.tarde);
      expect(DynamicOnboardingService.getTimePhase(t3), TimePhase.tarde);
    });

    test('Detects Noche phase (20:00 a 23:59)', () {
      final t1 = DateTime(2026, 8, 4, 20, 0);
      final t2 = DateTime(2026, 8, 4, 22, 10);
      final t3 = DateTime(2026, 8, 4, 23, 59);

      expect(DynamicOnboardingService.getTimePhase(t1), TimePhase.noche);
      expect(DynamicOnboardingService.getTimePhase(t2), TimePhase.noche);
      expect(DynamicOnboardingService.getTimePhase(t3), TimePhase.noche);
    });
  });

  group('DynamicOnboardingService - Phrases Dataset Validation', () {
    test('Contains exactly 10 Login phrases per phase (50 phrases total)', () {
      final loginMap = DynamicOnboardingService.allLoginPhrases;
      expect(loginMap.length, 5);

      int totalCount = 0;
      for (final phase in TimePhase.values) {
        final list = loginMap[phase]!;
        expect(list.length, 10, reason: 'La fase ${phase.name} debe tener exactamente 10 frases de login.');
        totalCount += list.length;
      }
      expect(totalCount, 50);
    });

    test('Contains exactly 10 Welcome phrases per phase (50 phrases total)', () {
      final welcomeMap = DynamicOnboardingService.allWelcomePhrases;
      expect(welcomeMap.length, 5);

      int totalCount = 0;
      for (final phase in TimePhase.values) {
        final list = welcomeMap[phase]!;
        expect(list.length, 10, reason: 'La fase ${phase.name} debe tener exactamente 10 frases de bienvenida.');
        totalCount += list.length;
      }
      expect(totalCount, 50);
    });

    test('Total phrases across Pre-Login and Post-Login equals 100', () {
      int grandTotal = 0;
      for (final list in DynamicOnboardingService.allLoginPhrases.values) {
        grandTotal += list.length;
      }
      for (final list in DynamicOnboardingService.allWelcomePhrases.values) {
        grandTotal += list.length;
      }
      expect(grandTotal, 100);
    });
  });

  group('DynamicOnboardingService - Random Selection and Name Injection', () {
    final service = DynamicOnboardingService();

    test('getRandomLoginPhrase returns non-empty phrase for all phases', () {
      final testTimes = [
        DateTime(2026, 8, 4, 2, 0),  // madrugada
        DateTime(2026, 8, 4, 8, 0),  // mañana
        DateTime(2026, 8, 4, 13, 0), // mediodía
        DateTime(2026, 8, 4, 17, 0), // tarde
        DateTime(2026, 8, 4, 21, 0), // noche
      ];

      for (final time in testTimes) {
        final phrase = service.getRandomLoginPhrase(customTime: time);
        expect(phrase.isNotEmpty, true);
      }
    });

    test('getRandomWelcomePhrase correctly injects user name', () {
      final time = DateTime(2026, 8, 4, 8, 30);
      final phrase = service.getRandomWelcomePhrase('Rodrigo', customTime: time);

      expect(phrase.contains('Rodrigo'), true);
      expect(phrase.contains('[Nombre]'), false);
    });

    test('getRandomWelcomePhrase uses fallback "Usuario" when empty name provided', () {
      final time = DateTime(2026, 8, 4, 15, 0);
      final phrase = service.getRandomWelcomePhrase('   ', customTime: time);

      expect(phrase.contains('Usuario'), true);
      expect(phrase.contains('[Nombre]'), false);
    });
  });
}
