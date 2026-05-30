import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// End-to-end encryption for direct messages (X25519 + HKDF + AES-256-GCM).
class DmCryptoService {
  DmCryptoService();

  static const _hkdfSalt = 'geoloc-dm';
  static const _hkdfInfo = 'dm-aes-key-v1';
  static const _backupKdfInfo = 'geoloc-dm-backup-v1';
  static const _nonceLength = 12;
  static const _macLength = 16;
  static const _kdfSaltLength = 16;
  static const x25519PublicKeyLength = 32;

  final _x25519 = X25519();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final _aesGcm = AesGcm.with256bits();
  final _random = Random.secure();

  /// Validates base64-encoded X25519 public key material (32 bytes decoded).
  static void validatePublicKeyBase64(String publicKeyBase64) {
    List<int> bytes;
    try {
      bytes = base64Decode(publicKeyBase64.trim());
    } on FormatException {
      throw const FormatException('invalid_public_key_base64');
    }
    if (bytes.length != x25519PublicKeyLength) {
      throw FormatException('invalid_public_key_length:${bytes.length}');
    }
  }

  /// Generates a new X25519 key pair. Returns (privateKeyBytes, publicKeyBase64).
  Future<({List<int> privateKeyBytes, String publicKeyBase64})>
      generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return (
      privateKeyBytes: privateKeyBytes,
      publicKeyBase64: base64Encode(publicKey.bytes),
    );
  }

  /// Derives the AES-256 message key via canonical HKDF.
  Future<SecretKey> deriveAesKey({
    required List<int> privateKeyBytes,
    required String peerPublicKeyBase64,
  }) async {
    validatePublicKeyBase64(peerPublicKeyBase64);
    final peerPublicKey = SimplePublicKey(
      base64Decode(peerPublicKeyBase64.trim()),
      type: KeyPairType.x25519,
    );
    final keyPair = await _x25519.newKeyPairFromSeed(privateKeyBytes);
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: peerPublicKey,
    );
    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(_hkdfSalt),
      info: utf8.encode(_hkdfInfo),
    );
  }

  /// Wraps identity [privateKeyBytes] with a user [passphrase] for server backup.
  Future<
      ({
        String ciphertextBase64,
        String nonceBase64,
        String kdfSaltBase64,
      })> encryptIdentityBackup({
    required List<int> privateKeyBytes,
    required String passphrase,
  }) async {
    final kdfSalt = _randomBytes(_kdfSaltLength);
    final backupKey = await _deriveBackupKey(
      passphrase: passphrase,
      kdfSalt: kdfSalt,
    );
    final encrypted = await encryptBytes(
      bytes: privateKeyBytes,
      aesKey: backupKey,
    );
    return (
      ciphertextBase64: encrypted.ciphertextBase64,
      nonceBase64: encrypted.nonceBase64,
      kdfSaltBase64: base64Encode(kdfSalt),
    );
  }

  /// Restores identity private key bytes from a server backup blob.
  Future<List<int>> decryptIdentityBackup({
    required String passphrase,
    required String ciphertextBase64,
    required String nonceBase64,
    required String kdfSaltBase64,
  }) async {
    final kdfSalt = base64Decode(kdfSaltBase64);
    if (kdfSalt.length < _kdfSaltLength) {
      throw const FormatException('invalid_kdf_salt_length');
    }
    final backupKey = await _deriveBackupKey(
      passphrase: passphrase,
      kdfSalt: kdfSalt,
    );
    final privateBytes = await decryptBytes(
      ciphertextBase64: ciphertextBase64,
      nonceBase64: nonceBase64,
      aesKey: backupKey,
    );
    if (privateBytes.length != 32) {
      throw const FormatException('invalid_backup_private_key');
    }
    return privateBytes;
  }

  Future<SecretKey> _deriveBackupKey({
    required String passphrase,
    required List<int> kdfSalt,
  }) async {
    return _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: kdfSalt,
      info: utf8.encode(_backupKdfInfo),
    );
  }

  /// Encrypts [plaintext] for the recipient. Returns base64 ciphertext (with tag)
  /// and base64 nonce (12 bytes).
  Future<({String ciphertextBase64, String nonceBase64})> encrypt({
    required String plaintext,
    required SecretKey aesKey,
  }) async {
    final nonce = _randomNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: aesKey,
      nonce: nonce,
    );
    final wireBytes = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return (
      ciphertextBase64: base64Encode(wireBytes),
      nonceBase64: base64Encode(nonce),
    );
  }

  /// Encrypts raw bytes (used for identity backup payload).
  Future<({String ciphertextBase64, String nonceBase64})> encryptBytes({
    required List<int> bytes,
    required SecretKey aesKey,
  }) async {
    final nonce = _randomNonce();
    final secretBox = await _aesGcm.encrypt(
      bytes,
      secretKey: aesKey,
      nonce: nonce,
    );
    final wireBytes = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return (
      ciphertextBase64: base64Encode(wireBytes),
      nonceBase64: base64Encode(nonce),
    );
  }

  /// Decrypts incoming message wire format.
  Future<String> decrypt({
    required String ciphertextBase64,
    required String nonceBase64,
    required SecretKey aesKey,
  }) async {
    final clearBytes = await decryptBytes(
      ciphertextBase64: ciphertextBase64,
      nonceBase64: nonceBase64,
      aesKey: aesKey,
    );
    return utf8.decode(clearBytes);
  }

  Future<List<int>> decryptBytes({
    required String ciphertextBase64,
    required String nonceBase64,
    required SecretKey aesKey,
  }) async {
    final wireBytes = base64Decode(ciphertextBase64);
    if (wireBytes.length < _macLength + 1) {
      throw const FormatException('Ciphertext too short');
    }
    final cipherText = wireBytes.sublist(0, wireBytes.length - _macLength);
    final macBytes = wireBytes.sublist(wireBytes.length - _macLength);
    final nonce = base64Decode(nonceBase64);
    if (nonce.length != _nonceLength) {
      throw const FormatException('Invalid nonce length');
    }
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    return _aesGcm.decrypt(secretBox, secretKey: aesKey);
  }

  List<int> _randomNonce() =>
      List<int>.generate(_nonceLength, (_) => _random.nextInt(256));

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
