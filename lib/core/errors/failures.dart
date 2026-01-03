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
