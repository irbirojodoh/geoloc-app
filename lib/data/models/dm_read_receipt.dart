class DmReadReceipt {
  final String conversationId;
  final String lastReadId;
  final DateTime readAt;

  const DmReadReceipt({
    required this.conversationId,
    required this.lastReadId,
    required this.readAt,
  });

  factory DmReadReceipt.fromJson(Map<String, dynamic> json) {
    return DmReadReceipt(
      conversationId: json['conversation_id'] as String,
      lastReadId: json['last_read_id'] as String,
      readAt: DateTime.parse(json['read_at'] as String),
    );
  }
}
