/// Result of a successful R2 media upload.
class UploadResult {
  final String key;
  final String url;

  const UploadResult({required this.key, required this.url});

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String?;
    if (key == null || key.isEmpty) {
      throw const FormatException('Upload response missing key');
    }
    return UploadResult(
      key: key,
      url: json['url'] as String? ?? '',
    );
  }
}
