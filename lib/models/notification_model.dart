// models/notification_model.dart

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime sentAt;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.sentAt,
    this.isRead = false,
  });

  // ✅ FROM JSON - Convert JSON to NotificationItem
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      type: json['notification_type'] ?? json['type'] ?? 'general',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'])
          : (json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now()),
      isRead: json['is_read'] ?? false,
    );
  }

  // ✅ TO JSON - Convert NotificationItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notification_type': type,
      'title': title,
      'body': body,
      'sent_at': sentAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  // ✅ COPY WITH - Create a copy with updated fields
  NotificationItem copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }
}