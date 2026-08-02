/// Configuración de alertas de inactividad persistida localmente.
///
/// Reglas de negocio:
/// - El intervalo se expresa en minutos desde la ventana de alerta real
///   (45 min por defecto, configurable a 30/60/90).
/// - El horario de operación define la ventana diaria en que se emiten alertas.
/// - Los días activos se representan como ISO: 1=Lu ... 7=Do.
class AlertSettings {
  final int intervalMinutes;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final Set<int> activeDays;
  final bool criticalNotifications;
  final bool alertSound;

  const AlertSettings({
    this.intervalMinutes = 45,
    this.startHour = 9,
    this.startMinute = 0,
    this.endHour = 18,
    this.endMinute = 0,
    this.activeDays = const {1, 2, 3, 4, 5},
    this.criticalNotifications = false,
    this.alertSound = true,
  });

  AlertSettings copyWith({
    int? intervalMinutes,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    Set<int>? activeDays,
    bool? criticalNotifications,
    bool? alertSound,
  }) {
    return AlertSettings(
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      activeDays: activeDays ?? this.activeDays,
      criticalNotifications: criticalNotifications ?? this.criticalNotifications,
      alertSound: alertSound ?? this.alertSound,
    );
  }

  AlertSettings copyWithAll(AlertSettings other) {
    return AlertSettings(
      intervalMinutes: other.intervalMinutes,
      startHour: other.startHour,
      startMinute: other.startMinute,
      endHour: other.endHour,
      endMinute: other.endMinute,
      activeDays: other.activeDays,
      criticalNotifications: other.criticalNotifications,
      alertSound: other.alertSound,
    );
  }
}