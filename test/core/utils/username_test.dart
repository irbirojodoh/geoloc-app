import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/utils/username.dart';

void main() {
  group('normalizeUsername', () {
    test('lowercases, trims, and strips a leading @', () {
      expect(normalizeUsername('  @New_Handle  '), 'new_handle');
    });
  });

  group('normalizeUsernameInput', () {
    test('lowercases as the user types without trimming', () {
      expect(normalizeUsernameInput('AbC'), 'abc');
    });
  });

  group('validateUsernameFormat', () {
    test('accepts letters, digits, dots, and underscores', () {
      expect(validateUsernameFormat('new_handle'), isNull);
      expect(validateUsernameFormat('a.b_c1'), isNull);
      expect(validateUsernameFormat('abc'), isNull);
      expect(validateUsernameFormat('a' * 30), isNull);
    });

    test('rejects empty, short, and long values', () {
      expect(validateUsernameFormat(''), 'Enter a username');
      expect(
        validateUsernameFormat('ab'),
        'Username must be at least 3 characters',
      );
      expect(
        validateUsernameFormat('a' * 31),
        'Username must be 30 characters or fewer',
      );
    });

    test('rejects illegal characters', () {
      expect(
        validateUsernameFormat('hello-world'),
        'Use only letters, numbers, periods, and underscores',
      );
    });

    test('rejects starting or ending punctuation', () {
      expect(
        validateUsernameFormat('_hello'),
        "Username can't start or end with a period or underscore",
      );
      expect(
        validateUsernameFormat('hello.'),
        "Username can't start or end with a period or underscore",
      );
    });

    test('rejects doubled punctuation', () {
      expect(
        validateUsernameFormat('a..b'),
        "Username can't contain consecutive periods or underscores",
      );
      expect(
        validateUsernameFormat('a__b'),
        "Username can't contain consecutive periods or underscores",
      );
      expect(
        validateUsernameFormat('a._b'),
        "Username can't contain consecutive periods or underscores",
      );
      expect(
        validateUsernameFormat('a_.b'),
        "Username can't contain consecutive periods or underscores",
      );
    });
  });
}
