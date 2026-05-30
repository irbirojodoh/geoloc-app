import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/crypto/dm_crypto_service.dart';

void main() {
  test('private key survives seed round-trip through storage', () async {
    final crypto = DmCryptoService();
    final pair = await crypto.generateKeyPair();

    final x = X25519();
    final restored = await x.newKeyPairFromSeed(pair.privateKeyBytes);
    final restoredPub = base64Encode(
      (await restored.extractPublicKey()).bytes,
    );

    expect(restoredPub, pair.publicKeyBase64);
  });

  test('incoming decrypt uses sender pubkey not recipient key_version', () async {
    final crypto = DmCryptoService();
    final alice = await crypto.generateKeyPair();
    final bob = await crypto.generateKeyPair();

    // Alice sends to Bob: ECDH(alice_priv, bob_pub), key_version = bob's (1)
    final sendKey = await crypto.deriveAesKey(
      privateKeyBytes: alice.privateKeyBytes,
      peerPublicKeyBase64: bob.publicKeyBase64,
    );
    final encrypted = await crypto.encrypt(plaintext: 'Hi Bob', aesKey: sendKey);

    // Bob receives: must use alice_pub (NOT key_version to pick alice's key)
    final recvKey = await crypto.deriveAesKey(
      privateKeyBytes: bob.privateKeyBytes,
      peerPublicKeyBase64: alice.publicKeyBase64,
    );
    final plain = await crypto.decrypt(
      ciphertextBase64: encrypted.ciphertextBase64,
      nonceBase64: encrypted.nonceBase64,
      aesKey: recvKey,
    );
    expect(plain, 'Hi Bob');
  });
}
