import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/username.dart';

void main() {
  group('UsernameAvailability', () {
    test('parses a reserved-word reason', () {
      final result = UsernameAvailability.fromJson({
        'username': 'admin',
        'available': false,
        'reason': 'this username is reserved',
      });
      expect(result.available, isFalse);
      expect(result.reason, 'this username is reserved');
      expect(result.unavailableMessage, 'this username is reserved');
    });

    test('taken handles have no reason', () {
      final result = UsernameAvailability.fromJson({
        'username': 'new_handle',
        'available': false,
      });
      expect(result.available, isFalse);
      expect(result.reason, isNull);
      expect(result.unavailableMessage, 'This username is taken');
    });
  });

  group('UsernameHistory', () {
    test('omitted cooldown dates mean change is allowed', () {
      final history = UsernameHistory.fromJson({
        'username': 'fresh_user',
        'history': <dynamic>[],
      });
      expect(history.lastChangedAt, isNull);
      expect(history.nextChangeAt, isNull);
      expect(history.history, isEmpty);
    });

    test('sorts history newest first', () {
      final history = UsernameHistory.fromJson({
        'username': 'new_handle',
        'last_changed_at': '2026-08-28T12:00:00Z',
        'next_change_at': '2026-10-28T12:00:00Z',
        'history': [
          {
            'old_username': 'first',
            'new_username': 'second',
            'changed_at': '2026-01-01T00:00:00Z',
          },
          {
            'old_username': 'second',
            'new_username': 'new_handle',
            'changed_at': '2026-08-28T12:00:00Z',
          },
        ],
      });
      final newest = history.historyNewestFirst;
      expect(newest.first.oldUsername, 'second');
      expect(newest.last.oldUsername, 'first');
    });
  });

  group('UsernameChangeResult', () {
    test('parses RFC3339 next_change_at', () {
      final result = UsernameChangeResult.fromJson({
        'message': 'Username updated',
        'username': 'new_handle',
        'previous_username': 'old_handle',
        'next_change_at': '2026-10-28T12:00:00Z',
      });
      expect(result.username, 'new_handle');
      expect(result.previousUsername, 'old_handle');
      expect(result.nextChangeAt.isUtc, isTrue);
    });
  });
}
