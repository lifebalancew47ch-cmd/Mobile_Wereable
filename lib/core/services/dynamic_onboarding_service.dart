import 'dart:math';

/// Enum que representa las 5 fases horarias estrictas del día.
enum TimePhase {
  madrugada, // 00:00 a 05:59
  manana,    // 06:00 a 11:59
  mediodia,  // 12:00 a 14:59
  tarde,     // 15:00 a 19:59
  noche,     // 20:00 a 23:59
}

/// Servicio que gestiona la lógica del reloj y la selección aleatoria de frases
/// adaptadas al modelo de negocio de LifeBalance (prevención de sedentarismo,
/// pausas activas, balance corporal y salud física).
class DynamicOnboardingService {
  final Random _random;

  DynamicOnboardingService({Random? random}) : _random = random ?? Random();

  /// Determina la fase horaria basada en la hora local o en una fecha provista.
  static TimePhase getTimePhase([DateTime? customTime]) {
    final now = customTime ?? DateTime.now();
    final hour = now.hour;

    if (hour >= 0 && hour < 6) {
      return TimePhase.madrugada;
    } else if (hour >= 6 && hour < 12) {
      return TimePhase.manana;
    } else if (hour >= 12 && hour < 15) {
      return TimePhase.mediodia;
    } else if (hour >= 15 && hour < 20) {
      return TimePhase.tarde;
    } else {
      return TimePhase.noche;
    }
  }

  /// Retorna un título corto representativo para cada fase horaria.
  static String getPhaseTitle(TimePhase phase) {
    switch (phase) {
      case TimePhase.madrugada:
        return 'Madrugada de Cuidado';
      case TimePhase.manana:
        return 'Mañana Activa';
      case TimePhase.mediodia:
        return 'Receso de Mediodía';
      case TimePhase.tarde:
        return 'Energía de la Tarde';
      case TimePhase.noche:
        return 'Cierre & Descanso';
    }
  }

  /// ---------------------------------------------------------------------------
  /// 50 FRASES DE PRE-LOGIN (LOGIN SCREEN) - Sin nombre de usuario
  /// Enfocadas en convencer al usuario de ingresar según la fase del día.
  /// ---------------------------------------------------------------------------
  static const Map<TimePhase, List<String>> _loginPhrases = {
    TimePhase.madrugada: [
      'Monitorea tu actividad 24/7 y mantén el equilibrio físico incluso en horarios nocturnos.',
      'Inicia sesión para registrar tu descanso y asegurar un amanecer lleno de energía.',
      'Salud sin pausa: mantén activas tus alertas de movimiento desde temprano.',
      'Tu bienestar corporal no se detiene. Accede para configurar tus metas de hoy.',
      'Cuidar tu postura y circulación es vital a cualquier hora. ¡Ingresa ahora!',
      'Deja programadas tus pausas activas antes de arrancar tu jornada.',
      'Monitoreo en tiempo real para quienes no se detienen. Conéctate a LifeBalance.',
      'Un gran día de movilidad y salud se planifica desde la madrugada. Accede a tu cuenta.',
      'Evita el sedentarismo desde las primeras horas. Tu cuerpo te lo agradecerá.',
      'Activa la sincronización con tu wearable y protege tu ritmo cardiaco y postura.',
    ],
    TimePhase.manana: [
      'Arranca la mañana en movimiento y vence el sedentarismo desde tus primeras tareas.',
      'Es hora de activar tu cuerpo. Inicia sesión y revisa tus metas de pausas activas.',
      'Una postura correcta en la mañana garantiza energía para el resto del día.',
      'Conéctate a LifeBalance y haz que cada hora de trabajo cuente con movilidad.',
      'Tu salud física es primero: inicia sesión para recibir alertas de inactividad a tiempo.',
      'Planifica tu rutina de ejercicios y estiramientos matutinos en LifeBalance.',
      'Comienza el día cuidando tu corazón y tus articulaciones. ¡Bienvenido!',
      'Mantén el balance entre tu productividad laboral y tu actividad corporal.',
      'Ingresa a tu cuenta para sincronizar tus pasos matutinos con tu wearable.',
      'Dale impulso a tu mañana liberando tensión postural con LifeBalance.',
    ],
    TimePhase.mediodia: [
      'Aprovecha el mediodía para hacer un estiramiento y renovar tu postura.',
      'Mitad de jornada: inicia sesión y verifica tu nivel de inactividad acumulada.',
      'Un descanso activo a mediodía mejora tu circulación y concentración.',
      'Ingresa a LifeBalance y registra tu pausa de movilidad antes de almorzar.',
      'No dejes que el cansancio del mediodía te detenga. ¡Revisa tu progreso!',
      'Relaja la espalda y los hombros: conéctate para seguir tu plan de pausas activas.',
      'El balance perfecto entre nutrición y movimiento lo encuentras aquí.',
      'Inicia sesión para convertir el receso del mediodía en energía renovada.',
      'Sincroniza tus datos de salud y comprueba tus minutos activos de la mañana.',
      'Corta la rutina sedentaria de la mañana con un estiramiento guiado.',
    ],
    TimePhase.tarde: [
      'Vence la fatiga de la tarde con estiramientos y pausas de movimiento.',
      'Evita estar sentado horas seguidas. Inicia sesión para activar tus alertas.',
      'Recupera tu energía vital en esta recta final de la jornada laboral.',
      'Ingresa a LifeBalance y descubre cuántas pausas activas has completado hoy.',
      'Cuida tu columna y mantén una postura erguida durante la tarde.',
      'Unos minutos de movilidad por la tarde marcarán la diferencia en tu salud.',
      'Monitorea tus signos vitales y niveles de actividad vespertina en tiempo real.',
      'Libera el estrés acumulado del día iniciando sesión en tu panel corporativo.',
      'Combate la pesadez de la tarde cumpliendo tu meta de pasos diaria.',
      'Cierra tu jornada con el mejor balance físico. ¡Accede a tu cuenta!',
    ],
    TimePhase.noche: [
      'Revisa tu resumen diario de movilidad y asegúrate de haber roto el sedentarismo.',
      'Prepara tu cuerpo para un descanso reparador analizando tu balance de hoy.',
      'Inicia sesión para evaluar tus alertas superadas y puntos de salud ganados.',
      'Una noche tranquila empieza habiendo mantenido un cuerpo activo en el día.',
      'Conéctate para sincronizar las últimas lecturas de tu reloj inteligente.',
      'Analiza tus métricas físicas de la jornada y planifica tus metas de mañana.',
      'Relaja tus músculos y prepárate para dormir evaluando tu rutina corporal.',
      'Revisa cuántos minutos de inactividad lograste prevenir durante el día.',
      'Tu bienestar no duerme: accede para verificar que tu descanso esté protegido.',
      'Cierra la noche celebrando cada pausa activa cumplida hoy en LifeBalance.',
    ],
  };

  /// ---------------------------------------------------------------------------
  /// 50 FRASES DE POST-LOGIN / BIENVENIDA (DASHBOARD SCREEN) - Con [Nombre]
  /// Inyectan la variable del nombre de usuario de forma natural e inclusiva.
  /// ---------------------------------------------------------------------------
  static const Map<TimePhase, List<String>> _welcomePhrases = {
    TimePhase.madrugada: [
      'Hola [Nombre], apreciamos tu dedicación nocturna. Recuerda cuidar tu descanso y postura.',
      '¡Bienvenido en esta madrugada, [Nombre]! Monitoreamos tu balance para que no te agotes.',
      '[Nombre], si trabajas de noche, recuerda realizar pequeñas pausas para activar la circulación.',
      'Hola [Nombre], tus métricas de salud están activas para protegerte a cualquier hora.',
      '¡Qué gusto verte, [Nombre]! Asegúrate de hidratarte y estirar si estás desvelándote.',
      '[Nombre], estamos vigilando tu nivel de sedentarismo para que tu noche sea saludable.',
      'Hola [Nombre], la constancia es clave. Mantén vigilados tus signos vitales esta madrugada.',
      '¡Hola [Nombre]! Un estiramiento breve ahora te ayudará a mantener la concentración.',
      '[Nombre], tu salud corporal nos importa 24/7. Listos para registrar tus métricas.',
      'Buenas madrugadas, [Nombre]. Revisa tus niveles de reposo y cuida tu bienestar.',
    ],
    TimePhase.manana: [
      '¡Buenos días, [Nombre]! Es el momento perfecto para activar tu cuerpo y superar tus metas.',
      'Hola [Nombre], arranca esta mañana con una excelente postura y energía renovada.',
      '¡Bienvenido a un nuevo día, [Nombre]! Listos para acompañarte en tus pausas activas.',
      '[Nombre], que el sedentarismo no frene tu mañana. ¡A moverse con energía!',
      '¡Hola, [Nombre]! Revisa tu plan de movilidad matutino y mantén tu corazón fuerte.',
      'Buenos días, [Nombre]. Hoy es una nueva oportunidad para cuidar tu salud corporal.',
      '[Nombre], tus alertas de inactividad están listas para guiarte durante toda la mañana.',
      '¡Excelente inicio de mañana, [Nombre]! Logremos juntos tu meta de pasos de hoy.',
      'Hola [Nombre], una pausa de estiramiento temprano impulsará tu productividad.',
      '¡Bienvenido, [Nombre]! Tu wearable está sincronizado para medir tu ritmo matutino.',
    ],
    TimePhase.mediodia: [
      '¡Hola, [Nombre]! Mitad de jornada superada. Hora de almorzar y hacer una pausa activa.',
      'Buenas tardes, [Nombre]. Aprovecha este mediodía para relajar hombros y columna.',
      '[Nombre], es momento de levantarte de la silla y reactivar la circulación de tus piernas.',
      '¡Hola [Nombre]! Has tenido una mañana productiva, dale ahora un respiro a tu cuerpo.',
      'Bienvenido a tu receso de mediodía, [Nombre]. Revisa tu resumen de movimiento hasta ahora.',
      '[Nombre], una caminata breve después de comer te llenará de vitalidad.',
      '¡Hola, [Nombre]! Mantén el equilibrio físico aprovechando este espacio del mediodía.',
      '[Nombre], tus articulaciones agradecerán unos minutos de estiramiento justo ahora.',
      'Buenas tardes, [Nombre]. Estás a mitad de camino de tus metas saludables de hoy.',
      '¡Gusto en verte, [Nombre]! Recuerda registrar tu rutina activa del mediodía.',
    ],
    TimePhase.tarde: [
      '¡Buenas tardes, [Nombre]! Vence la pesadez de la tarde con una pausa de movimiento.',
      'Hola [Nombre], no dejes que el cansancio modifique tu buena postura.',
      '¡Ánimo en este tramo de la tarde, [Nombre]! Unos pasos te devolverán el enfoque.',
      '[Nombre], estás haciendo un trabajo increíble protegiendo tu salud física hoy.',
      '¡Bienvenido, [Nombre]! Revisa cuántas alertas de sedentarismo has evitado esta tarde.',
      'Hola [Nombre], libera la tensión acumulada en el cuello con nuestra guía de estiramientos.',
      '[Nombre], mantente activo para cerrar tu jornada laboral sintiéndote ligero y con energía.',
      '¡Hola, [Nombre]! Recuerda levantarte al cumplir tu tiempo personalizado para cuidar tu circulación.',
      'Buenas tardes, [Nombre]. Cada pausa activa que cumples suma puntos para tu bienestar.',
      '[Nombre], estás a muy poco de completar tus metas de movilidad de este día.',
    ],
    TimePhase.noche: [
      '¡Buenas noches, [Nombre]! Excelente momento para revisar tu balance diario de actividad.',
      'Hola [Nombre], felicidades por cuidar de tu cuerpo y romper el sedentarismo hoy.',
      '[Nombre], tómate unos minutos para relajarte y preparar un sueño verdaderamente reparador.',
      '¡Bienvenido al cierre del día, [Nombre]! Revisa tus medallas y logros de salud alcanzados.',
      'Hola [Nombre], tu espalda y tus músculos te agradecen las pausas activas de hoy.',
      '[Nombre], analiza tus métricas de frecuencia cardíaca y descanso de esta noche.',
      '¡Buenas noches, [Nombre]! Dejemos programadas tus metas y alertas para el día de mañana.',
      '[Nombre], desconéctate del trabajo y regálale a tu cuerpo una noche de tranquilidad.',
      'Hola [Nombre], el balance de hoy fue positivo. ¡Sigue cuidando tu salud física!',
      '¡Que tengas un feliz descanso, [Nombre]! LifeBalance velará por tu reposo nocturno.',
    ],
  };

  /// Devuelve una frase aleatoria de Pre-Login para la fase horaria actual.
  String getRandomLoginPhrase({DateTime? customTime}) {
    final phase = getTimePhase(customTime);
    final phrases = _loginPhrases[phase]!;
    final index = _random.nextInt(phrases.length);
    return phrases[index];
  }

  /// Devuelve una frase aleatoria de Post-Login / Bienvenida inyectando el nombre del usuario.
  String getRandomWelcomePhrase(String userName, {DateTime? customTime}) {
    final phase = getTimePhase(customTime);
    final phrases = _welcomePhrases[phase]!;
    final index = _random.nextInt(phrases.length);
    final rawPhrase = phrases[index];
    final cleanName = userName.trim().isEmpty ? 'Usuario' : userName.trim();
    return rawPhrase.replaceAll('[Nombre]', cleanName);
  }

  /// Devuelve todas las frases registradas (para verificación o inspección de datos).
  static Map<TimePhase, List<String>> get allLoginPhrases => _loginPhrases;
  static Map<TimePhase, List<String>> get allWelcomePhrases => _welcomePhrases;
}
