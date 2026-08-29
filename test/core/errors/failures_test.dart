import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/errors/failures.dart';

void main() {
  group('Failure hierarchy', () {
    test('TokenExpiredFailure is an AuthFailure (and hence a Failure)', () {
      const f = TokenExpiredFailure();
      expect(f, isA<AuthFailure>());
      expect(f, isA<Failure>());
    });

    test('InvalidCredentialsFailure is an AuthFailure', () {
      const f = InvalidCredentialsFailure();
      expect(f, isA<AuthFailure>());
    });

    test('Failure.toString includes message', () {
      const f = NetworkFailure(message: 'Offline', details: 'no DNS');
      expect(f.toString(), contains('Offline'));
      expect(f.toString(), contains('no DNS'));
    });

    test('UsernameTakenFailure is a ClientFailure with 409', () {
      const f = UsernameTakenFailure();
      expect(f, isA<ClientFailure>());
      expect(f.statusCode, 409);
    });

    test('UsernameCooldownFailure is a RateLimitFailure', () {
      final f = UsernameCooldownFailure(
        nextChangeAt: DateTime.utc(2026, 10, 28),
      );
      expect(f, isA<RateLimitFailure>());
      expect(f, isA<Failure>());
    });
  });

  group('Failure default messages', () {
    test('each subclass has a sensible default', () {
      expect(const NetworkFailure().message, 'Network error occurred');
      expect(const ServerFailure().message, 'Server error occurred');
      expect(const AuthFailure().message, 'Authentication failed');
      expect(const TokenExpiredFailure().message, contains('Session expired'));
      expect(const ValidationFailure().message, 'Validation failed');
      expect(const LocationPermissionFailure().message, contains('permission'));
      expect(const RateLimitFailure().message, contains('Too many requests'));
    });
  });

  group('ValidationFailure.fieldErrors', () {
    test('preserves field-level error map', () {
      const f = ValidationFailure(
        message: 'Bad form',
        fieldErrors: {
          'email': 'Invalid email',
          'password': 'Too short',
        },
      );
      expect(f.fieldErrors, isNotNull);
      expect(f.fieldErrors!['email'], 'Invalid email');
      expect(f.fieldErrors!['password'], 'Too short');
    });
  });
}
