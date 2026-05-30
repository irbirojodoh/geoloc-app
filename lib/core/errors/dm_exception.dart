/// DM-specific API failures surfaced to the UI layer.
class DmException implements Exception {
  final String code;
  final String message;
  final int? currentKeyVersion;

  const DmException({
    required this.code,
    required this.message,
    this.currentKeyVersion,
  });

  bool get isBlocked => code == 'blocked';
  bool get isForbidden => code == 'forbidden';
  bool get isKeyVersionMismatch => code == 'key_version_mismatch';
  bool get isRecipientHasNoKey => code == 'recipient_has_no_public_key';
  bool get isPublicKeyNotFound => code == 'public_key_not_found';

  @override
  String toString() => message;
}
