/// Client-side username format rules. Reserved words are server-only —
/// never duplicate that list here; use the availability endpoint's `reason`.
const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 30;

final _allowedChars = RegExp(r'^[a-z0-9._]+$');
final _doubledPunctuation = RegExp(r'[._]{2}');
final _startsOrEndsWithPunctuation = RegExp(r'^[._]|[._]$');

/// Lowercase, strip a leading `@`, and trim. The backend silently lowercases
/// too, so the UI should show this form as the user types.
String normalizeUsername(String raw) {
  var value = raw.toLowerCase().trim();
  if (value.startsWith('@')) {
    value = value.substring(1).trim();
  }
  return value;
}

/// Lowercase as the user types (no trim, so the caret does not jump).
String normalizeUsernameInput(String raw) {
  var value = raw.toLowerCase();
  if (value.startsWith('@')) {
    value = value.substring(1);
  }
  return value;
}

/// Returns a user-facing error, or `null` when [username] is well-formed.
/// [username] should already be normalized (lowercase, no leading `@`).
String? validateUsernameFormat(String username) {
  if (username.isEmpty) {
    return 'Enter a username';
  }
  if (username.length < kUsernameMinLength) {
    return 'Username must be at least $kUsernameMinLength characters';
  }
  if (username.length > kUsernameMaxLength) {
    return 'Username must be $kUsernameMaxLength characters or fewer';
  }
  if (!_allowedChars.hasMatch(username)) {
    return 'Use only letters, numbers, periods, and underscores';
  }
  if (_startsOrEndsWithPunctuation.hasMatch(username)) {
    return "Username can't start or end with a period or underscore";
  }
  if (_doubledPunctuation.hasMatch(username)) {
    return "Username can't contain consecutive periods or underscores";
  }
  return null;
}

bool isValidUsernameFormat(String username) =>
    validateUsernameFormat(username) == null;
