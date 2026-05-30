class DmMessage {
  final String messageId;
  final String conversationId;
  final String senderId;
  final String ciphertextBase64;
  final String nonceBase64;
  final int keyVersion;
  final int senderKeyVersion;
  final DateTime sentAt;
  final DateTime? deletedAt;
  final String? plaintext;
  final bool decryptFailed;

  const DmMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderId,
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.keyVersion,
    required this.senderKeyVersion,
    required this.sentAt,
    this.deletedAt,
    this.plaintext,
    this.decryptFailed = false,
  });

  bool get isDeleted => deletedAt != null;

  factory DmMessage.fromJson(
    Map<String, dynamic> json, {
    required String conversationId,
  }) {
    final deletedAtRaw = json['deleted_at'];
    final senderKeyVersion = json['sender_key_version'] as int? ??
        json['key_version'] as int? ??
        1;
    return DmMessage(
      messageId: json['message_id'] as String,
      conversationId: conversationId,
      senderId: json['sender_id'] as String,
      ciphertextBase64: json['ciphertext'] as String,
      nonceBase64: json['nonce'] as String,
      keyVersion: json['key_version'] as int,
      senderKeyVersion: senderKeyVersion,
      sentAt: DateTime.parse(json['sent_at'] as String),
      deletedAt: deletedAtRaw == null
          ? null
          : DateTime.parse(deletedAtRaw as String),
    );
  }

  factory DmMessage.fromSseJson(Map<String, dynamic> json) {
    final senderKeyVersion = json['sender_key_version'] as int? ??
        json['key_version'] as int? ??
        1;
    return DmMessage(
      messageId: json['message_id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      ciphertextBase64: json['ciphertext'] as String,
      nonceBase64: json['nonce'] as String,
      keyVersion: json['key_version'] as int,
      senderKeyVersion: senderKeyVersion,
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'message_id': messageId,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'ciphertext': ciphertextBase64,
      'nonce': nonceBase64,
      'key_version': keyVersion,
      'sender_key_version': senderKeyVersion,
      'sent_at': sentAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'plaintext': plaintext,
      'decrypt_failed': decryptFailed,
    };
  }

  factory DmMessage.fromLocalJson(Map<String, dynamic> json) {
    final deletedAtRaw = json['deleted_at'];
    return DmMessage(
      messageId: json['message_id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      ciphertextBase64: json['ciphertext'] as String,
      nonceBase64: json['nonce'] as String,
      keyVersion: json['key_version'] as int,
      senderKeyVersion: json['sender_key_version'] as int? ??
          json['key_version'] as int? ??
          1,
      sentAt: DateTime.parse(json['sent_at'] as String),
      deletedAt: deletedAtRaw == null
          ? null
          : DateTime.parse(deletedAtRaw as String),
      plaintext: json['plaintext'] as String?,
      decryptFailed: json['decrypt_failed'] as bool? ?? false,
    );
  }

  DmMessage copyWith({
    String? messageId,
    String? conversationId,
    String? senderId,
    String? ciphertextBase64,
    String? nonceBase64,
    int? keyVersion,
    int? senderKeyVersion,
    DateTime? sentAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? plaintext,
    bool clearPlaintext = false,
    bool? decryptFailed,
  }) {
    return DmMessage(
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      ciphertextBase64: ciphertextBase64 ?? this.ciphertextBase64,
      nonceBase64: nonceBase64 ?? this.nonceBase64,
      keyVersion: keyVersion ?? this.keyVersion,
      senderKeyVersion: senderKeyVersion ?? this.senderKeyVersion,
      sentAt: sentAt ?? this.sentAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      plaintext: clearPlaintext ? null : (plaintext ?? this.plaintext),
      decryptFailed: decryptFailed ?? this.decryptFailed,
    );
  }
}
