/// JWT authentication tokens model
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiry;
  final DateTime refreshTokenExpiry;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiry,
    required this.refreshTokenExpiry,
  });

  /// Check if access token is expired
  bool get isAccessTokenExpired => DateTime.now().isAfter(accessTokenExpiry);

  /// Check if refresh token is expired
  bool get isRefreshTokenExpired => DateTime.now().isAfter(refreshTokenExpiry);

  /// Check if access token will expire soon (within 1 minute)
  bool get isAccessTokenExpiringSoon {
    final buffer = DateTime.now().add(const Duration(minutes: 1));
    return buffer.isAfter(accessTokenExpiry);
  }

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    // Handle different response formats from backend
    final accessTokenExpiry = json['access_token_expiry'] != null
        ? DateTime.parse(json['access_token_expiry'] as String)
        : DateTime.now().add(const Duration(minutes: 15));

    final refreshTokenExpiry = json['refresh_token_expiry'] != null
        ? DateTime.parse(json['refresh_token_expiry'] as String)
        : DateTime.now().add(const Duration(days: 7));

    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      accessTokenExpiry: accessTokenExpiry,
      refreshTokenExpiry: refreshTokenExpiry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'access_token_expiry': accessTokenExpiry.toIso8601String(),
      'refresh_token_expiry': refreshTokenExpiry.toIso8601String(),
    };
  }

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiry,
    DateTime? refreshTokenExpiry,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiry: accessTokenExpiry ?? this.accessTokenExpiry,
      refreshTokenExpiry: refreshTokenExpiry ?? this.refreshTokenExpiry,
    );
  }

  @override
  String toString() =>
      'AuthTokens(accessExpiry: $accessTokenExpiry, refreshExpiry: $refreshTokenExpiry)';
}
