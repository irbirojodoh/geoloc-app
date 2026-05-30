class DmKeyBackup {
  final int backupVersion;
  final String ciphertextBase64;
  final String nonceBase64;
  final String kdfSaltBase64;
  final DateTime? updatedAt;

  const DmKeyBackup({
    required this.backupVersion,
    required this.ciphertextBase64,
    required this.nonceBase64,
    required this.kdfSaltBase64,
    this.updatedAt,
  });

  factory DmKeyBackup.fromJson(Map<String, dynamic> json) {
    return DmKeyBackup(
      backupVersion: json['backup_version'] as int,
      ciphertextBase64: json['ciphertext'] as String,
      nonceBase64: json['nonce'] as String,
      kdfSaltBase64: json['kdf_salt'] as String,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toUploadJson() {
    return {
      'backup_version': backupVersion,
      'ciphertext': ciphertextBase64,
      'nonce': nonceBase64,
      'kdf_salt': kdfSaltBase64,
    };
  }
}
