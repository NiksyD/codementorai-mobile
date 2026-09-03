class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.type,
    required this.createdAt,
    this.sourceId,
    this.actionUrl,
    this.actionText,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final bool isRead;
  final String type; // 'ai', 'streak', 'report', 'achievement', 'system'
  final DateTime createdAt;
  final String? sourceId;
  final String? actionUrl;
  final String? actionText;

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    bool? isRead,
    String? type,
    DateTime? createdAt,
    String? sourceId,
    String? actionUrl,
    String? actionText,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      sourceId: sourceId ?? this.sourceId,
      actionUrl: actionUrl ?? this.actionUrl,
      actionText: actionText ?? this.actionText,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final String rawType = (json['notif_type'] ?? json['type'] ?? 'system').toString();
    final String normalizedType;
    if (rawType.contains('ai')) {
      normalizedType = 'ai';
    } else if (rawType.contains('streak')) {
      normalizedType = 'streak';
    } else if (rawType.contains('report')) {
      normalizedType = 'report';
    } else if (rawType.contains('achievement') || rawType.contains('unlock')) {
      normalizedType = 'achievement';
    } else {
      normalizedType = 'system';
    }

    final DateTime createdDate;
    if (json['notif_created_at'] != null) {
      createdDate = DateTime.tryParse(json['notif_created_at'].toString()) ?? DateTime.now();
    } else if (json['created_at'] != null) {
      createdDate = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      createdDate = DateTime.now();
    }

    // Determine intuitive action labels & deep link targets if not stored
    String? url = json['action_url'] as String?;
    String? label = json['action_text'] as String?;

    if (url == null || url.isEmpty) {
      switch (normalizedType) {
        case 'ai':
          url = '/learn/activity';
          label = 'View Review';
          break;
        case 'streak':
          url = '/learn/modules';
          label = 'Practice Now';
          break;
        case 'report':
          url = '/learn/modules';
          label = 'View Status';
          break;
        case 'achievement':
          url = '/profile';
          label = 'View Badges';
          break;
        default:
          url = '/learn';
          label = 'Explore';
      }
    }

    return NotificationModel(
      id: (json['notif_id'] ?? json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      title: (json['notif_title'] ?? json['title'] ?? 'Notification').toString(),
      message: (json['notif_message'] ?? json['message'] ?? '').toString(),
      isRead: json['notif_is_read'] == true || json['read'] == true,
      type: normalizedType,
      createdAt: createdDate,
      sourceId: json['notif_source_id']?.toString(),
      actionUrl: url,
      actionText: label,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'notif_id': id,
      'user_id': userId,
      'notif_title': title,
      'notif_message': message,
      'notif_is_read': isRead,
      'notif_type': type,
      'notif_source_id': sourceId,
      'notif_created_at': createdAt.toIso8601String(),
      'action_url': actionUrl,
      'action_text': actionText,
    };
  }

  String get timeAgo {
    final Duration diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.month}/${createdAt.day}';
  }
}
