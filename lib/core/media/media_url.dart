/// Utilities for R2 presigned media URLs returned by the Geoloc API.
class MediaUrl {
  MediaUrl._();

  static const _r2HostSuffix = '.r2.cloudflarestorage.com';
  static const _mediaFolders = ['avatars', 'covers', 'posts'];

  /// Presigned GET URLs from R2 — load without JWT.
  static bool isPresignedR2Url(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host != null && host.endsWith(_r2HostSuffix);
  }

  /// External URLs (Unsplash, etc.) — load as-is, no signing.
  static bool isExternalUrl(String url) => !isPresignedR2Url(url);

  /// Extract the stable object key from a presigned R2 URL path.
  static String? parseKeyFromUrl(String url) {
    if (!isPresignedR2Url(url)) return null;

    final path = Uri.tryParse(url)?.path;
    if (path == null || path.isEmpty) return null;

    for (final folder in _mediaFolders) {
      final marker = '/$folder/';
      final index = path.indexOf(marker);
      if (index >= 0) {
        return path.substring(index + 1);
      }
    }
    return null;
  }

  /// Presigned URLs authenticate via query params — never attach Bearer token.
  static bool shouldAttachAuthHeader(String url) => false;
}
