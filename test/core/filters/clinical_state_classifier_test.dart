import 'package:flutter_test/flutter_test.dart';
import 'package:lifebalance/core/filters/clinical_state_classifier.dart';

void main() {
  group('inferBodyOrientation', () {
    test('gravedad dominante en un eje -> upright', () {
      expect(inferBodyOrientation(0, 0, 9.81), BodyOrientation.upright);
    });

    test('gravedad repartida -> reclined', () {
      expect(inferBodyOrientation(6, 6, 4), BodyOrientation.reclined);
    });

    test('vector nulo -> unknown', () {
      expect(inferBodyOrientation(0, 0, 0), BodyOrientation.unknown);
    });
  });

  group('ClinicalStateClassifier', () {
    // Configuración corta: steady-state en pocas ventanas de 30s.
    late ClinicalStateClassifier c;

    setUp(() {
      c = ClinicalStateClassifier(
        seatedRestMinutes: 1, // 2 ventanas
        reclinedRestMinutes: 2, // 4 ventanas
        sleepMinutes: 1, // 2 ventanas
        sleepHrvMin: 30,
        restingHrMin: 60,
        restingHrMax: 100,
        sleepHrMax: 60,
      );
    });

    void feedImmobile({
      double? hr = 70,
      double? hrv = 0,
      BodyOrientation orientation = BodyOrientation.upright,
    }) {
      c.feed(immobile: true, orientation: orientation, heartRate: hr, hrv: hrv);
    }

    test('trabajo sentado: FC normal sin steady-state -> computa alerta', () {
      feedImmobile();
      expect(c.state, SedentaryState.sedentaryWork);
      expect(c.reposoVerificado, isFalse);
    });

    test('reposo clínico verificado tras steady-state sentado', () {
      feedImmobile();
      feedImmobile(); // seatedRestMinutes=1 -> 2 ventanas
      expect(c.state, SedentaryState.clinicalRest);
      expect(c.reposoVerificado, isTrue);
    });

    test('reposo recostado exige más ventanas (reclinedRestMinutes=2)', () {
      feedImmobile(orientation: BodyOrientation.reclined);
      feedImmobile(orientation: BodyOrientation.reclined);
      expect(c.state, SedentaryState.sedentaryWork);
      expect(c.reposoVerificado, isFalse);

      feedImmobile(orientation: BodyOrientation.reclined);
      feedImmobile(orientation: BodyOrientation.reclined);
      expect(c.state, SedentaryState.clinicalRest);
      expect(c.reposoVerificado, isTrue);
    });

    test('el movimiento reinicia el steady-state de reposo', () {
      feedImmobile();
      c.feed(immobile: false, orientation: BodyOrientation.upright, heartRate: 80, hrv: 0);
      feedImmobile();
      expect(c.state, SedentaryState.sedentaryWork);
      expect(c.reposoVerificado, isFalse);
    });

    test('sueño: FC baja + HRV alto + horizontal -> congela temporizador', () {
      c.feed(
          immobile: true,
          orientation: BodyOrientation.reclined,
          heartRate: 50,
          hrv: 60);
      c.feed(
          immobile: true,
          orientation: BodyOrientation.reclined,
          heartRate: 49,
          hrv: 62);
      expect(c.state, SedentaryState.sleep);
    });

    test('FC fuera de rango (trabajo activo) no clasifica como reposo', () {
      feedImmobile(hr: 130);
      feedImmobile(hr: 131);
      expect(c.state, SedentaryState.sedentaryWork);
      expect(c.reposoVerificado, isFalse);
    });

    test('sin señal de FC no se puede verificar reposo (seguro por defecto)', () {
      feedImmobile(hr: null, hrv: null);
      feedImmobile(hr: null, hrv: null);
      expect(c.state, SedentaryState.sedentaryWork);
      expect(c.reposoVerificado, isFalse);
    });
  });
}