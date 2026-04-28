/// App-wide configuration for Geoloc
class AppConfig {
  AppConfig._();

  /// API Configuration
  ///
  /// Override at build time:
  /// ```
  /// flutter run --dart-define=API_BASE_URL=https://api.geoloc.app
  /// ```
  /// Default is `http://localhost:8080` for local backend development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String apiVersion = 'v1';

  /// Whether the configured base URL uses HTTPS. Use to gate ATS exceptions
  /// or reject insecure connections in production builds.
  static bool get isSecureBaseUrl => apiBaseUrl.startsWith('https://');

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

  /// Location Configuration
  static const double defaultFeedRadiusKm = 5.0;
  static const int geohashPrecision = 5; // ~5km precision

  /// Pagination
  static const int defaultPageSize = 20;

  /// Rate Limiting
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const int maxRequestsPerMinute = 100;

  /// Media Constraints
  static const int maxAvatarSizeMB = 5;
  static const int maxPostMediaSizeMB = 50;

  /// Comment Configuration
  static const int maxCommentDepth = 3;
}
