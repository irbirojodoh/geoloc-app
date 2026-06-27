/// Presigned PUT URL returned by POST /api/v1/media/upload-url (Pattern B).
class PresignedUploadUrl {
  final String uploadUrl;
  final String key;
  final DateTime expiresAt;

  const PresignedUploadUrl({
    required this.uploadUrl,
    required this.key,
    required this.expiresAt,
  });

  factory PresignedUploadUrl.fromJson(Map<String, dynamic> json) {
    final uploadUrl = json['upload_url'] as String?;
    final key = json['key'] as String?;
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        key == null ||
        key.isEmpty) {
      throw const FormatException('Upload URL response missing upload_url or key');
    }
    final expiresAtRaw = json['expires_at'] as String?;
    return PresignedUploadUrl(
      uploadUrl: uploadUrl,
      key: key,
      expiresAt: expiresAtRaw != null
          ? DateTime.parse(expiresAtRaw).toLocal()
          : DateTime.now().add(const Duration(minutes: 10)),
    );
  }
}
