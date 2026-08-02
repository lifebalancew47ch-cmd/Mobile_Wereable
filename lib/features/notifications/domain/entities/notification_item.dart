class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String severity;
  final DateTime createdAtUtc;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAtUtc,
    required this.read,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? json['body'] ?? '',
      severity: json['severity'] ?? json['type']?.toString() ?? '',
      createdAtUtc: DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      read: json['read'] == true || json['isRead'] == true,
    );
  }
}
