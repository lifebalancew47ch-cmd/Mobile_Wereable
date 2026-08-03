import 'dart:math' as math;

/// Estado clínico de inactividad del usuario.
///
/// El Filtro Clínico de Falsos Positivos distingue tres estados para no
/// penalizar reposos legítimos ni sueño como sedentarismo:
///
/// * [SedentaryState.sedentaryWork]: trabajo sentado/activo en vigilia.
///   SÍ computa para la alerta de sedentarismo.
/// * [SedentaryState.clinicalRest]: reposo clínico / descanso legítimo
///   (FC en rango de reposo 60-100 lpm con steady-state cumplido). Marca
///   `reposoVerificado = true` y pausa el temporizador de sedentarismo.
/// * [SedentaryState.sleep]: sueño/siesta (FC baja, HRV parasimpático alto,
///   orientación horizontal prolongada). Congela el temporizador.
enum SedentaryState { sedentaryWork, clinicalRest, sleep }

/// Orientación corporal inferida (heurística a partir del vector gravedad).
enum BodyOrientation { unknown, upright, reclined }

/// Infiere la orientación corporal a partir del vector de gravedad promedio
/// del acelerómetro en la ventana. Heurística: si un eje domina la dirección
/// de la gravedad (proporción alta sobre un único eje) se trata de una
/// postura bien asentada/vertical; si la gravedad queda repartida entre los
/// ejes horizontales, la postura se interpreta como recostada.
BodyOrientation inferBodyOrientation(double ax, double ay, double az) {
  final mag = math.sqrt(ax * ax + ay * ay + az * az);
  if (!mag.isFinite || mag < 1e-6) return BodyOrientation.unknown;

  final dominant = [
    (ax / mag).abs(),
    (ay / mag).abs(),
    (az / mag).abs(),
  ].reduce(math.max);

  // Postura vertical bien anclada a un eje del reloj -> sentado/de pie.
  if (dominant >= 0.75) return BodyOrientation.upright;
  // Gravedad repartida/rotada -> recostado.
  if (dominant >= 0.40) return BodyOrientation.reclined;
  return BodyOrientation.unknown;
}

/// Observación de una ventana de análisis (30 s) para el clasificador.
class ClinicalWindowSample {
  final BodyOrientation orientation;
  final double? heartRate; // lpm
  final double? hrv; // ms

  const ClinicalWindowSample({
    required this.orientation,
    required this.heartRate,
    required this.hrv,
  });
}

/// Filtro Clínico de Falsos Positivos (Sección 2.B del desglose).
///
/// Reglas:
/// 1. Trabajo sentado: FC en rangos normales de vigila, giroscopio
///    vertical/estático -> SÍ computa para la alerta de sedentarismo.
/// 2. Reposo clínico / descanso legítimo: FC estrictamente en 60-100 lpm,
///    inmóvil y en steady-state durante N minutos (5-10 sentado, 20-30
///    recostado según la orientación). Al verificar -> `reposoVerificado=true`
///    y se pausa el temporizador de sedentarismo.
/// 3. Sueño/siesta: FC baja, HRV con alta actividad parasimpática y
///    orientación horizontal prolongada -> se congela el temporizador.
class ClinicalStateClassifier {
  static const int _windowsPerMinute = 2; // 1 ventana = 30 s

  final double restingHrMin; // 60
  final double restingHrMax; // 100
  final double sleepHrMax; // FC baja por debajo
  final double sleepHrvMin; // HRV parasimpático alto (ms)
  final int seatedRestMinutes; // 5..10
  final int reclinedRestMinutes; // 20..30
  final int sleepMinutes; // minutos continuos horizontales para sueño

  int _restWindows = 0;
  int _sleepWindows = 0;
  BodyOrientation _restOrientation = BodyOrientation.unknown;
  bool _reposoVerificado = false;
  SedentaryState _state = SedentaryState.sedentaryWork;

  ClinicalStateClassifier({
    this.restingHrMin = 60,
    this.restingHrMax = 100,
    this.sleepHrMax = 60,
    this.sleepHrvMin = 30,
    this.seatedRestMinutes = 5,
    this.reclinedRestMinutes = 20,
    this.sleepMinutes = 20,
  }) {
    if (sleepHrMax > restingHrMax) {
      throw ArgumentError('sleepHrMax no puede superar restingHrMax.');
    }
  }

  /// Estado clínico actual para la ventana más reciente.
  SedentaryState get state => _state;

  /// `true` cuando el reposo clínico ha sido verificado (steady-state).
  bool get reposoVerificado => _reposoVerificado;

  /// Minutos continuos de reposo clínico acumulados (solo en steady-state).
  int get restMinutes => _restWindows ~/ _windowsPerMinute;

  /// Minutos continuos como candidato a sueño.
  int get sleepMinutesAccumulated => _sleepWindows ~/ _windowsPerMinute;

  /// Procesa una ventana de análisis.
  ///
  /// [immobile] indica si la ventana fue Reportada como inactiva por varianza.
  /// Cuando el usuario se mueve, se reinicia todo acumulado de steady-state.
  void feed({
    required bool immobile,
    required BodyOrientation orientation,
    required double? heartRate,
    required double? hrv,
  }) {
    if (!immobile) {
      _restWindows = 0;
      _sleepWindows = 0;
      _reposoVerificado = false;
      _state = SedentaryState.sedentaryWork;
      return;
    }

    final hrKnown = heartRate != null && heartRate.isFinite && heartRate > 0;
    final hrvKnown = hrv != null && hrv.isFinite && hrv >= 0;
    final hr = heartRate ?? 0;
    final h = hrv ?? 0;

    // Sueño/siesta: FC baja + HRV parasimpático alto + horizontal prolongado.
    final sleepCandidate =
        hrKnown && hr < sleepHrMax && hrvKnown && h >= sleepHrvMin;
    if (sleepCandidate &&
        (orientation == BodyOrientation.reclined ||
            orientation == BodyOrientation.unknown)) {
      _sleepWindows++;
      _restWindows = 0;
      _reposoVerificado = false;
      _state = _sleepWindows >= sleepMinutes * _windowsPerMinute
          ? SedentaryState.sleep
          : SedentaryState.sedentaryWork;
      return;
    }

    // Reposo clínico: FC en [restingHrMin, restingHrMax] inmóvil.
    if (hrKnown && hr >= restingHrMin && hr <= restingHrMax) {
      _sleepWindows = 0;
      _restWindows++;
      if (_restWindows == 1) {
        _restOrientation = orientation;
      }
      final requiredWindows = (_restOrientation == BodyOrientation.reclined
              ? reclinedRestMinutes
              : seatedRestMinutes) *
          _windowsPerMinute;
      if (_restWindows >= requiredWindows) {
        _reposoVerificado = true;
        _state = SedentaryState.clinicalRest;
      } else {
        _reposoVerificado = false;
        _state = SedentaryState.sedentaryWork;
      }
      return;
    }

    // Trabajo sentado / estado no clasificable: computa para la alerta.
    _restWindows = 0;
    _sleepWindows = 0;
    _reposoVerificado = false;
    _state = SedentaryState.sedentaryWork;
  }

  /// Reinicia el acumulado clínico.
  void reset() {
    _restWindows = 0;
    _sleepWindows = 0;
    _reposoVerificado = false;
    _state = SedentaryState.sedentaryWork;
  }
}