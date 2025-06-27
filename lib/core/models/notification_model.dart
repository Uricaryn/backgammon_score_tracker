class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      imageUrl: map['imageUrl'],
      data: map['data'],
      timestamp: (map['timestamp'] as dynamic).toDate(),
      isRead: map['isRead'] ?? false,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == 'NotificationType.${map['type']}',
        orElse: () => NotificationType.general,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'data': data,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.toString().split('.').last,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}

enum NotificationType {
  newGame,
  statistics,
  reminder,
  social,
  general,
}

class NotificationPreferences {
  final bool enabled;
  final bool newGameNotifications;
  final bool statisticsNotifications;
  final bool reminderNotifications;
  final bool socialNotifications;
  final String? fcmToken;

  NotificationPreferences({
    this.enabled = true,
    this.newGameNotifications = true,
    this.statisticsNotifications = true,
    this.reminderNotifications = true,
    this.socialNotifications = true,
    this.fcmToken,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      enabled: map['enabled'] ?? true,
      newGameNotifications: map['newGameNotifications'] ?? true,
      statisticsNotifications: map['statisticsNotifications'] ?? true,
      reminderNotifications: map['reminderNotifications'] ?? true,
      socialNotifications: map['socialNotifications'] ?? true,
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'newGameNotifications': newGameNotifications,
      'statisticsNotifications': statisticsNotifications,
      'reminderNotifications': reminderNotifications,
      'socialNotifications': socialNotifications,
      'fcmToken': fcmToken,
    };
  }

  NotificationPreferences copyWith({
    bool? enabled,
    bool? newGameNotifications,
    bool? statisticsNotifications,
    bool? reminderNotifications,
    bool? socialNotifications,
    String? fcmToken,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      newGameNotifications: newGameNotifications ?? this.newGameNotifications,
      statisticsNotifications:
          statisticsNotifications ?? this.statisticsNotifications,
      reminderNotifications:
          reminderNotifications ?? this.reminderNotifications,
      socialNotifications: socialNotifications ?? this.socialNotifications,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
