class DmPublicKey {
  final String userId;
  final String publicKeyBase64;
  final int keyVersion;
  final DateTime createdAt;

  const DmPublicKey({
    required this.userId,
    required this.publicKeyBase64,
    required this.keyVersion,
    required this.createdAt,
  });

  factory DmPublicKey.fromJson(Map<String, dynamic> json) {
    return DmPublicKey(
      userId: json['user_id'] as String,
      publicKeyBase64: json['public_key'] as String,
      keyVersion: json['key_version'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
