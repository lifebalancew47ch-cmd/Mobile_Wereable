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

  NotificationPreferences({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.wearEnabled,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        pushEnabled: json['pushEnabled'] == true || json['push'] == true,
        emailEnabled: json['emailEnabled'] == true || json['email'] == true,
        wearEnabled: json['wearEnabled'] == true || json['wear'] == true,
      );
}
