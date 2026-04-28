import 'auth_tokens.dart';
import 'user.dart';

/// Unified response model for all authentication endpoints
/// (login, register, Google token, Apple token).
///
/// Wraps the user object, JWT tokens, and the `is_new_user` flag
/// used to determine if the user should be routed to onboarding.
class AuthResponse {
  final User user;
  final AuthTokens tokens;
  final bool isNewUser;

  const AuthResponse({
    required this.user,
    required this.tokens,
    this.isNewUser = false,
  });

  /// Parse the standardized backend auth response:
  /// ```json
  /// {
  ///   "user": { "id": "...", "username": "...", "email": "..." },
  ///   "access_token": "...",
  ///   "refresh_token": "...",
  ///   "expires_in": 900,
  ///   "is_new_user": true
  /// }
  /// ```
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      tokens: AuthTokens.fromJson(json),
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }
}
