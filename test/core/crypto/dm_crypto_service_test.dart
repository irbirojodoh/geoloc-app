import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/crypto/dm_crypto_service.dart';

void main() {
  late DmCryptoService crypto;

  setUp(() {
    crypto = DmCryptoService();
  });

  test('encrypt/decrypt round-trip', () async {
    final alice = await crypto.generateKeyPair();
    final bob = await crypto.generateKeyPair();

    final aliceAes = await crypto.deriveAesKey(
      privateKeyBytes: alice.privateKeyBytes,
      peerPublicKeyBase64: bob.publicKeyBase64,
    );
    final bobAes = await crypto.deriveAesKey(
      privateKeyBytes: bob.privateKeyBytes,
      peerPublicKeyBase64: alice.publicKeyBase64,
    );

    const plaintext = 'Hello, encrypted world!';
    final encrypted = await crypto.encrypt(
      plaintext: plaintext,
      aesKey: aliceAes,
    );

    final nonceBytes = encrypted.nonceBase64.length;
    expect(nonceBytes, greaterThan(0));

    final cipherBytes = encrypted.ciphertextBase64.length;
    expect(cipherBytes, greaterThan(0));

    final decrypted = await crypto.decrypt(
      ciphertextBase64: encrypted.ciphertextBase64,
      nonceBase64: encrypted.nonceBase64,
      aesKey: bobAes,
    );

    expect(decrypted, plaintext);
  });

  test('nonce decodes to 12 bytes', () async {
    final alice = await crypto.generateKeyPair();
    final bob = await crypto.generateKeyPair();
    final aesKey = await crypto.deriveAesKey(
      privateKeyBytes: alice.privateKeyBytes,
      peerPublicKeyBase64: bob.publicKeyBase64,
    );
    final encrypted = await crypto.encrypt(plaintext: 'test', aesKey: aesKey);
    final nonce = encrypted.nonceBase64;
    final decoded = await crypto.decrypt(
      ciphertextBase64: encrypted.ciphertextBase64,
      nonceBase64: nonce,
      aesKey: aesKey,
    );
    expect(decoded, 'test');
  });

  test('HKDF produces identical keys for both parties', () async {
    final alice = await crypto.generateKeyPair();
    final bob = await crypto.generateKeyPair();

    final aliceKey = await crypto.deriveAesKey(
      privateKeyBytes: alice.privateKeyBytes,
      peerPublicKeyBase64: bob.publicKeyBase64,
    );
    final bobKey = await crypto.deriveAesKey(
      privateKeyBytes: bob.privateKeyBytes,
      peerPublicKeyBase64: alice.publicKeyBase64,
    );

    final aliceBytes = await aliceKey.extractBytes();
    final bobBytes = await bobKey.extractBytes();
    expect(aliceBytes, bobBytes);
  });

  test('ciphertext wire format is at least 17 bytes encoded', () async {
    final alice = await crypto.generateKeyPair();
    final bob = await crypto.generateKeyPair();
    final aesKey = await crypto.deriveAesKey(
      privateKeyBytes: alice.privateKeyBytes,
      peerPublicKeyBase64: bob.publicKeyBase64,
    );
    final encrypted = await crypto.encrypt(plaintext: 'x', aesKey: aesKey);
    final decodedLength =
        encrypted.ciphertextBase64.replaceAll('=', '').length;
    expect(decodedLength, greaterThan(0));
    final raw = SecretKeyData(await aesKey.extractBytes());
    expect(raw.bytes.length, 32);
  });

  test('identity backup round-trip', () async {
    final pair = await crypto.generateKeyPair();
    const passphrase = 'correct-horse-battery-staple';

    final backup = await crypto.encryptIdentityBackup(
      privateKeyBytes: pair.privateKeyBytes,
      passphrase: passphrase,
    );

    final restored = await crypto.decryptIdentityBackup(
      passphrase: passphrase,
      ciphertextBase64: backup.ciphertextBase64,
      nonceBase64: backup.nonceBase64,
      kdfSaltBase64: backup.kdfSaltBase64,
    );

    expect(restored, pair.privateKeyBytes);
  });

  test('identity backup rejects wrong passphrase', () async {
    final pair = await crypto.generateKeyPair();
    final backup = await crypto.encryptIdentityBackup(
      privateKeyBytes: pair.privateKeyBytes,
      passphrase: 'right-pass',
    );

    expect(
      () => crypto.decryptIdentityBackup(
        passphrase: 'wrong-pass',
        ciphertextBase64: backup.ciphertextBase64,
        nonceBase64: backup.nonceBase64,
        kdfSaltBase64: backup.kdfSaltBase64,
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
