import 'package:flutter/foundation.dart';

/// App-wide configuration for Geoloc
class AppConfig {
  AppConfig._();

  /// Override at build time:
  /// ```
  /// flutter run --dart-define=API_BASE_URL=https://geolocapi-dev.irphotoarts.cloud
  /// flutter run --dart-define=API_BASE_URL=http://192.168.2.1:8080
  /// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com
  /// ```
  static const String _apiBaseUrlFromEnv = String.fromEnvironment('API_BASE_URL');
  static const String _googleServerClientIdFromEnv =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Defaults to cloud dev API. Override with --dart-define=API_BASE_URL=...
  static String get apiBaseUrl {
    if (_apiBaseUrlFromEnv.isNotEmpty) return _apiBaseUrlFromEnv;
    return 'https://geolocapi-dev.irphotoarts.cloud';
  }

  /// Web OAuth client ID passed as [GoogleSignIn.serverClientId].
  ///
  /// Required for a reliable ID token on Android. When empty, the native
  /// platform client is used as the token audience (works on iOS once the
  /// REVERSED_CLIENT_ID URL scheme is configured).
  /// Must match backend env `GOOGLE_CLIENT_ID`.
  static String get googleServerClientId => _googleServerClientIdFromEnv;

  static const String apiVersion = 'v1';

  /// Whether the configured base URL uses HTTPS.
  static bool get isSecureBaseUrl => apiBaseUrl.startsWith('https://');

  /// Fail fast in release if the API URL is not HTTPS.
  static void assertValidForRelease() {
    if (!kReleaseMode) return;
    if (!isSecureBaseUrl) {
      throw StateError(
        'Release builds require an HTTPS API_BASE_URL. '
        'Got: $apiBaseUrl. Pass '
        '--dart-define=API_BASE_URL=https://api.geoloc.app',
      );
    }
  }

  /// API Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// JWT Token Configuration
  static const Duration accessTokenDuration = Duration(minutes: 15);
  static const Duration refreshTokenDuration = Duration(days: 7);

  /// Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String accessTokenExpiryKey = 'access_token_expiry';
  static const String refreshTokenExpiryKey = 'refresh_token_expiry';
  static const String currentUserKey = 'current_user';

  /// DM E2EE secure storage keys (never log or upload private key)
  static const String dmPrivateKeyKey = 'dm_private_key';
  static const String dmPublicKeyVersionKey = 'dm_public_key_version';
  static const String dmBackupVersionKey = 'dm_backup_version';

  /// Hive box names for DM local cache
  static const String dmConversationsBox = 'dm_conversations';
  static const String dmMessagesBox = 'dm_messages';

  /// Hive box for offline feed cache (stores keys, not presigned URLs)
  static const String feedCacheBox = 'feed_cache';

  /// Location Configuration
  static const double defaultFeedRadiusKm = 5.0;
  static const int geohashPrecision = 5; // ~5km precision

  /// Pagination
  static const int defaultPageSize = 20;

  /// Rate Limiting
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int maxRequestsPerMinute = 100;

  /// Media Constraints (R2: 10MB max, images only)
  static const int maxMediaSizeMB = 10;
  static const int maxAvatarSizeMB = maxMediaSizeMB;
  static const int maxPostMediaSizeMB = maxMediaSizeMB;
  static const int maxMediaSizeBytes = maxMediaSizeMB * 1024 * 1024;

  /// How long feed data stays fresh before a background refresh on resume.
  static const Duration feedRefreshTtl = Duration(minutes: 5);

  /// Comment Configuration
  static const int maxCommentDepth = 3;
}
