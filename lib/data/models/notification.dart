import 'user.dart';

/// Notification types
enum NotificationType {
  like,
  comment,
  follow,
  locationPost;

  static NotificationType fromString(String value) {
    switch (value) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'location_post':
        return NotificationType.locationPost;
      default:
        return NotificationType.like;
    }
  }

  String toJson() {
    switch (this) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
      case NotificationType.locationPost:
        return 'location_post';
    }
  }
}

/// Target type for notifications
enum TargetType {
  post,
  comment,
  user;

  static TargetType fromString(String value) {
    switch (value) {
      case 'post':
        return TargetType.post;
      case 'comment':
        return TargetType.comment;
      case 'user':
        return TargetType.user;
      default:
        return TargetType.post;
    }
  }

  String toJson() {
    switch (this) {
      case TargetType.post:
        return 'post';
      case TargetType.comment:
        return 'comment';
      case TargetType.user:
        return 'user';
    }
  }
}

/// App notification model
class AppNotification {
  final String id;
  final NotificationType type;
  final String actorId;
  final TargetType targetType;
  final String targetId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final User? actor;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorId,
    required this.targetType,
    required this.targetId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.actor,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      actorId: json['actor_id'] as String,
      targetType: TargetType.fromString(json['target_type'] as String),
      targetId: json['target_id'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      actor: json['actor'] != null
          ? User.fromJson(json['actor'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toJson(),
      'actor_id': actorId,
      'target_type': targetType.toJson(),
      'target_id': targetId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'actor': actor?.toJson(),
    };
  }

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? actorId,
    TargetType? targetType,
    String? targetId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    User? actor,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actorId: actorId ?? this.actorId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actor: actor ?? this.actor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
