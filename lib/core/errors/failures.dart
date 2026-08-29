/// Base failure class for all app failures
abstract class Failure {
  final String message;
  final String? details;

  const Failure({required this.message, this.details});

  @override
  String toString() =>
      'Failure: $message${details != null ? ' ($details)' : ''}';
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Network error occurred',
    super.details,
  });
}

/// Server-side failures (5xx errors)
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    super.message = 'Server error occurred',
    super.details,
    this.statusCode,
  });
}

/// Client-side failures (4xx errors)
class ClientFailure extends Failure {
  final int? statusCode;

  const ClientFailure({
    super.message = 'Request failed',
    super.details,
    this.statusCode,
  });
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({super.message = 'Authentication failed', super.details});
}

/// Social sign-in hit an existing account with a different method; user must confirm link.
class EmailInUseFailure extends AuthFailure {
  final String email;
  final List<String> existingMethods;
  final String attemptingMethod;

  const EmailInUseFailure({
    required this.email,
    required this.existingMethods,
    required this.attemptingMethod,
    super.message =
        'This email is already used by another sign-in method',
    super.details,
  });
}

/// Apple identityToken was rejected (usually expired ~10 min). Force a new native sheet.
class AppleIdentityTokenExpiredFailure extends AuthFailure {
  const AppleIdentityTokenExpiredFailure({
    super.message =
        'Your Apple sign-in expired. Please try Sign in with Apple again.',
    super.details,
  });
}

/// Token expired failure
class TokenExpiredFailure extends AuthFailure {
  const TokenExpiredFailure({
    super.message = 'Session expired. Please login again.',
    super.details,
  });
}

/// Invalid credentials failure
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password',
    super.details,
  });
}

/// User not found failure
class UserNotFoundFailure extends Failure {
  const UserNotFoundFailure({super.message = 'User not found', super.details});
}

/// Resource not found failure
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Resource not found', super.details});
}

/// Validation failure
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    super.message = 'Validation failed',
    super.details,
    this.fieldErrors,
  });
}

/// Rate limit failure
class RateLimitFailure extends Failure {
  final Duration? retryAfter;

  const RateLimitFailure({
    super.message = 'Too many requests. Please try again later.',
    super.details,
    this.retryAfter,
  });
}

/// 409 on PUT /users/me/username — taken by another account.
class UsernameTakenFailure extends ClientFailure {
  const UsernameTakenFailure({
    super.message = 'This username is already taken',
    super.statusCode = 409,
  });
}

/// 429 on PUT /users/me/username — cooldown still active.
class UsernameCooldownFailure extends RateLimitFailure {
  final DateTime? lastChangedAt;
  final DateTime nextChangeAt;

  const UsernameCooldownFailure({
    required this.nextChangeAt,
    this.lastChangedAt,
    super.message = 'You cannot change your username yet',
  });
}

/// Location permission failure
class LocationPermissionFailure extends Failure {
  const LocationPermissionFailure({
    super.message = 'Location permission denied',
    super.details,
  });
}

/// Location service disabled failure
class LocationServiceFailure extends Failure {
  const LocationServiceFailure({
    super.message = 'Location services are disabled',
    super.details,
  });
}

/// Cache failure
class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Cache error occurred', super.details});
}

/// Unknown failure
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.details,
  });
}
