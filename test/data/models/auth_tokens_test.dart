import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/auth_tokens.dart';

void main() {
  group('AuthTokens.fromJson', () {
    test('parses a fully-specified payload', () {
      final json = {
        'access_token': 'a.b.c',
        'refresh_token': 'r.r.r',
        'access_token_expiry': '2030-01-01T00:00:00Z',
        'refresh_token_expiry': '2031-01-01T00:00:00Z',
      };
      final tokens = AuthTokens.fromJson(json);
      expect(tokens.accessToken, 'a.b.c');
      expect(tokens.refreshToken, 'r.r.r');
      expect(tokens.accessTokenExpiry.toUtc().year, 2030);
      expect(tokens.refreshTokenExpiry.toUtc().year, 2031);
    });

    test('falls back to expires_in for access token when explicit expiry missing', () {
      final before = DateTime.now();
      final tokens = AuthTokens.fromJson({
        'access_token': 'x',
        'refresh_token': 'y',
        'expires_in': 3600,
      });
      final delta = tokens.accessTokenExpiry.difference(before);
      expect(delta.inSeconds, inInclusiveRange(3590, 3610));
    });

    test('falls back to default 15m / 7d when nothing is provided', () {
      final before = DateTime.now();
      final tokens = AuthTokens.fromJson({
        'access_token': 'x',
        'refresh_token': 'y',
      });
      expect(
        tokens.accessTokenExpiry.difference(before).inMinutes,
        inInclusiveRange(14, 16),
      );
      expect(
        tokens.refreshTokenExpiry.difference(before).inDays,
        inInclusiveRange(6, 7),
      );
    });
  });

  group('AuthTokens expiry helpers', () {
    test('isAccessTokenExpired is true for past expiry', () {
      final t = AuthTokens(
        accessToken: 'a',
        refreshToken: 'b',
        accessTokenExpiry: DateTime.now().subtract(const Duration(seconds: 1)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 7)),
      );
      expect(t.isAccessTokenExpired, isTrue);
    });

    test('isAccessTokenExpiringSoon is true within 1 minute', () {
      final t = AuthTokens(
        accessToken: 'a',
        refreshToken: 'b',
        accessTokenExpiry: DateTime.now().add(const Duration(seconds: 30)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 7)),
      );
      expect(t.isAccessTokenExpiringSoon, isTrue);
    });

    test('isAccessTokenExpiringSoon is false outside the 1-minute buffer', () {
      final t = AuthTokens(
        accessToken: 'a',
        refreshToken: 'b',
        accessTokenExpiry: DateTime.now().add(const Duration(minutes: 30)),
        refreshTokenExpiry: DateTime.now().add(const Duration(days: 7)),
      );
      expect(t.isAccessTokenExpiringSoon, isFalse);
    });
  });

  group('AuthTokens round-trip JSON', () {
    test('fromJson(toJson(t)) preserves values', () {
      final original = AuthTokens(
        accessToken: 'A',
        refreshToken: 'R',
        accessTokenExpiry: DateTime.utc(2030, 6, 1, 12),
        refreshTokenExpiry: DateTime.utc(2030, 7, 1, 12),
      );
      final restored = AuthTokens.fromJson(original.toJson());
      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.accessTokenExpiry, original.accessTokenExpiry);
      expect(restored.refreshTokenExpiry, original.refreshTokenExpiry);
    });
  });
}
