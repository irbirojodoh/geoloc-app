class DmConversation {
  final String conversationId;
  final String otherUserId;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final String? lastMessagePreview;
  final int unreadCount;

  const DmConversation({
    required this.conversationId,
    required this.otherUserId,
    required this.lastMessageAt,
    required this.createdAt,
    this.lastMessagePreview,
    this.unreadCount = 0,
  });

  factory DmConversation.fromJson(Map<String, dynamic> json) {
    return DmConversation(
      conversationId: json['conversation_id'] as String,
      otherUserId: json['other_user_id'] as String,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'other_user_id': otherUserId,
      'last_message_at': lastMessageAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'last_message_preview': lastMessagePreview,
      'unread_count': unreadCount,
    };
  }

  factory DmConversation.fromLocalJson(Map<String, dynamic> json) {
    return DmConversation(
      conversationId: json['conversation_id'] as String,
      otherUserId: json['other_user_id'] as String,
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessagePreview: json['last_message_preview'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  DmConversation copyWith({
    String? conversationId,
    String? otherUserId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    String? lastMessagePreview,
    bool clearLastMessagePreview = false,
    int? unreadCount,
  }) {
    return DmConversation(
      conversationId: conversationId ?? this.conversationId,
      otherUserId: otherUserId ?? this.otherUserId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt ?? this.createdAt,
      lastMessagePreview: clearLastMessagePreview
          ? null
          : (lastMessagePreview ?? this.lastMessagePreview),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
