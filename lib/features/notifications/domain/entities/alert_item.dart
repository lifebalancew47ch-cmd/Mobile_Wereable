class AlertItem {
  final String id;
  final String title;
  final String body;
  final String source;
  final String priority;
  final DateTime createdAtUtc;
  final bool read;

  AlertItem({
    required this.id,
    required this.title,
    required this.body,
    required this.source,
    required this.priority,
    required this.createdAtUtc,
    required this.read,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        priority: json['priority']?.toString() ?? '',
        createdAtUtc:
            DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
        read: json['read'] == true || json['isRead'] == true,
      );
}

class NotificationPreferences {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool wearEnabled;

  const NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.wearEnabled,
  });

  /// Valores por defecto cuando no hay nada guardado ni en local ni en la nube.
  static const defaults = NotificationPreferences(
    pushEnabled: true,
    emailEnabled: true,
    wearEnabled: true,
  );

  NotificationPreferences copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? wearEnabled,
  }) =>
      NotificationPreferences(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        emailEnabled: emailEnabled ?? this.emailEnabled,
        wearEnabled: wearEnabled ?? this.wearEnabled,
      );

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        'emailEnabled': emailEnabled,
        'wearEnabled': wearEnabled,
      };

  /// Acepta las distintas convenciones que devuelve el backend
  /// (`pushEnabled` / `push` / `push_enabled`) y valores no booleanos
  /// (`1`, `"true"`, `"1"`). Si la clave no viene, se conserva el valor
  /// por defecto en lugar de asumir `false`.
  factory NotificationPreferences.fromJson(
    Map<String, dynamic> json, {
    NotificationPreferences fallback = defaults,
  }) =>
      NotificationPreferences(
        pushEnabled: _readBool(json, const ['pushEnabled', 'push', 'push_enabled']) ??
            fallback.pushEnabled,
        emailEnabled: _readBool(json, const ['emailEnabled', 'email', 'email_enabled']) ??
            fallback.emailEnabled,
        wearEnabled: _readBool(
              json,
              const ['wearEnabled', 'wear', 'wear_enabled', 'wearableEnabled'],
            ) ??
            fallback.wearEnabled,
      );

  static bool? _readBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      final parsed = _asBool(json[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
      if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
    }
    return null;
  }
}
