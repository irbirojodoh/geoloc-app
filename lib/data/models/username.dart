DateTime? _parseOptionalDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime _parseRequiredDate(dynamic value, {required String field}) {
  final parsed = _parseOptionalDate(value);
  if (parsed == null) {
    throw FormatException('Missing or invalid $field');
  }
  return parsed;
}

/// GET /api/v1/users/username-available
class UsernameAvailability {
  final String username;
  final bool available;

  /// Present only when the handle fails server-side validation (reserved,
  /// invalid). Omitted when the handle is merely taken.
  final String? reason;

  const UsernameAvailability({
    required this.username,
    required this.available,
    this.reason,
  });

  factory UsernameAvailability.fromJson(Map<String, dynamic> json) {
    return UsernameAvailability(
      username: json['username'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  /// Display copy for the unavailable state. Prefer the server `reason`;
  /// a taken handle has no reason, so we fall back to a taken message.
  String get unavailableMessage =>
      reason ?? 'This username is taken';
}

/// PUT /api/v1/users/me/username 200 body
class UsernameChangeResult {
  final String message;
  final String username;
  final String previousUsername;
  final DateTime nextChangeAt;

  const UsernameChangeResult({
    required this.message,
    required this.username,
    required this.previousUsername,
    required this.nextChangeAt,
  });

  factory UsernameChangeResult.fromJson(Map<String, dynamic> json) {
    return UsernameChangeResult(
      message: json['message'] as String? ?? 'Username updated',
      username: json['username'] as String? ?? '',
      previousUsername: json['previous_username'] as String? ?? '',
      nextChangeAt: _parseRequiredDate(
        json['next_change_at'],
        field: 'next_change_at',
      ),
    );
  }
}

/// One row from GET /api/v1/users/me/username-history `history`
class UsernameHistoryEntry {
  final String oldUsername;
  final String newUsername;
  final DateTime changedAt;

  const UsernameHistoryEntry({
    required this.oldUsername,
    required this.newUsername,
    required this.changedAt,
  });

  factory UsernameHistoryEntry.fromJson(Map<String, dynamic> json) {
    return UsernameHistoryEntry(
      oldUsername: json['old_username'] as String? ?? '',
      newUsername: json['new_username'] as String? ?? '',
      changedAt: _parseRequiredDate(
        json['changed_at'],
        field: 'changed_at',
      ),
    );
  }
}

/// GET /api/v1/users/me/username-history
///
/// [lastChangedAt] and [nextChangeAt] are omitted for users who have never
/// renamed — treat that as "change allowed now", not an error.
class UsernameHistory {
  final String username;
  final DateTime? lastChangedAt;
  final DateTime? nextChangeAt;
  final List<UsernameHistoryEntry> history;

  const UsernameHistory({
    required this.username,
    this.lastChangedAt,
    this.nextChangeAt,
    this.history = const [],
  });

  factory UsernameHistory.fromJson(Map<String, dynamic> json) {
    final raw = json['history'] as List<dynamic>? ?? const [];
    return UsernameHistory(
      username: json['username'] as String? ?? '',
      lastChangedAt: _parseOptionalDate(json['last_changed_at']),
      nextChangeAt: _parseOptionalDate(json['next_change_at']),
      history: raw
          .map((e) => UsernameHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Newest first, as shown on the change-username screen.
  List<UsernameHistoryEntry> get historyNewestFirst {
    final copy = [...history];
    copy.sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return copy;
  }
}
