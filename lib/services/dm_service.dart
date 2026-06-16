import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../core/crypto/dm_crypto_service.dart';
import '../core/errors/dm_exception.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/dm_conversation.dart';
import '../data/models/dm_message.dart';
import '../data/models/dm_key_backup.dart';
import '../data/models/dm_public_key.dart';
import '../data/models/dm_read_receipt.dart';
import '../data/models/user.dart';
import 'dm_local_storage.dart';
import 'secure_storage.dart';

final dmCryptoServiceProvider = Provider<DmCryptoService>((ref) {
  return DmCryptoService();
});

final dmLocalStorageProvider = Provider<DmLocalStorage>((ref) {
  return DmLocalStorage();
});

final dmServiceProvider = Provider<DmService>((ref) {
  return DmService(
    ref.watch(apiClientProvider),
    ref.watch(dmCryptoServiceProvider),
    ref.watch(dmLocalStorageProvider),
  );
});

class DmConversationPage {
  final List<DmConversation> conversations;
  final String nextCursor;

  const DmConversationPage({
    required this.conversations,
    required this.nextCursor,
  });

  bool get hasMore => nextCursor.isNotEmpty;
}

class DmMessagePage {
  final List<DmMessage> messages;
  final String nextCursor;

  const DmMessagePage({
    required this.messages,
    required this.nextCursor,
  });

  bool get hasMore => nextCursor.isNotEmpty;
}

class DmSendResult {
  final String messageId;
  final DateTime sentAt;

  const DmSendResult({required this.messageId, required this.sentAt});
}

/// Local DM identity state for multi-device flows.
enum DmIdentityStatus {
  /// Private key in secure storage; messaging available.
  ready,

  /// Server has a backup but this device has no local identity yet.
  restoreRequired,

  /// No local key and no server backup — new identity can be created.
  noLocalKey,
}

/// REST + crypto orchestration for encrypted direct messages.
class DmService {
  DmService(
    this._apiClient,
    this._crypto,
    this._localStorage,
  ) : _storage = secureStorage;

  final ApiClient _apiClient;
  final DmCryptoService _crypto;
  final DmLocalStorage _localStorage;
  final FlutterSecureStorage _storage;

  final Map<String, SecretKey> _aesKeyCache = {};
  final Map<String, DmPublicKey> _peerKeyCache = {};
  final Map<String, User> _userCache = {};

  String _cacheKey(String peerUserId, int keyVersion) =>
      '$peerUserId:$keyVersion';

  String _peerCacheKey(String userId, int version) => '$userId:$version';

  Future<bool> hasLocalIdentity() async {
    final key = await _storage.read(key: AppConfig.dmPrivateKeyKey);
    return key != null && key.isNotEmpty;
  }

  Future<int?> getLocalKeyVersion() async {
    final versionStr =
        await _storage.read(key: AppConfig.dmPublicKeyVersionKey);
    return int.tryParse(versionStr ?? '');
  }

  /// Whether this device needs the user to restore from a server backup.
  Future<DmIdentityStatus> getIdentityStatus() async {
    if (await hasLocalIdentity()) return DmIdentityStatus.ready;
    try {
      await fetchKeyBackup();
      return DmIdentityStatus.restoreRequired;
    } on DmException catch (e) {
      if (e.code == 'backup_not_found') {
        return DmIdentityStatus.noLocalKey;
      }
      rethrow;
    }
  }

  Future<void> ensureKeysUploaded({String? password}) async {
    final status = await getIdentityStatus();
    if (status == DmIdentityStatus.restoreRequired) {
      return;
    }

    final privateKeyB64 = await _storage.read(key: AppConfig.dmPrivateKeyKey);
    final versionStr =
        await _storage.read(key: AppConfig.dmPublicKeyVersionKey);

    if (privateKeyB64 == null || versionStr == null) {
      await _createAndUploadIdentity(keyVersion: 1, password: password);
      return;
    }

    final version = int.tryParse(versionStr) ?? 1;
    final privateBytes = base64Decode(privateKeyB64);
    final keyPair = await X25519().newKeyPairFromSeed(privateBytes);
    final publicKey = await keyPair.extractPublicKey();
    await _uploadPublicKey(
      publicKeyBase64: base64Encode(publicKey.bytes),
      keyVersion: version,
    );

    if (password != null) {
      try {
        final backup = await fetchKeyBackup();
        // Try decrypting the backup to see if the passphrase is still valid
        try {
          await _crypto.decryptIdentityBackup(
            passphrase: password,
            ciphertextBase64: backup.ciphertextBase64,
            nonceBase64: backup.nonceBase64,
            kdfSaltBase64: backup.kdfSaltBase64,
          );
        } on SecretBoxAuthenticationError {
          debugPrint('Server key backup password mismatch. Rotating key backup...');
          await uploadIdentityBackup(password);
        } catch (_) {
          await uploadIdentityBackup(password);
        }
      } on DmException catch (e) {
        if (e.code == 'backup_not_found') {
          await uploadIdentityBackup(password);
        } else {
          debugPrint('Failed to query existing server backup: $e');
        }
      } catch (e) {
        debugPrint('Failed to auto-upload/rotate backup: $e');
      }
    }
  }

  /// Creates a fresh identity on this device (cannot decrypt old inbound history).
  Future<void> createNewIdentity({String? password}) async {
    await _createAndUploadIdentity(keyVersion: 1, password: password);
  }

  Future<void> _createAndUploadIdentity({
    required int keyVersion,
    String? password,
  }) async {
    final pair = await _crypto.generateKeyPair();
    await _storeIdentity(
      privateKeyBytes: pair.privateKeyBytes,
      keyVersion: keyVersion,
    );
    await _uploadPublicKey(
      publicKeyBase64: pair.publicKeyBase64,
      keyVersion: keyVersion,
    );
    if (password != null) {
      try {
        await uploadIdentityBackup(password);
      } catch (e) {
        debugPrint('Failed to auto-upload backup on identity generation: $e');
      }
    }
  }

  Future<void> _storeIdentity({
    required List<int> privateKeyBytes,
    required int keyVersion,
  }) async {
    await _storage.write(
      key: AppConfig.dmPrivateKeyKey,
      value: base64Encode(privateKeyBytes),
    );
    await _storage.write(
      key: AppConfig.dmPublicKeyVersionKey,
      value: '$keyVersion',
    );
    _aesKeyCache.clear();
    _peerKeyCache.clear();
  }

  /// Downloads and decrypts server backup, restores identity, re-uploads public key.
  Future<void> restoreIdentityFromBackup({
    required String passphrase,
    required String currentUserId,
    DmKeyBackup? backup,
  }) async {
    final activeBackup = backup ?? await fetchKeyBackup();
    final privateBytes = await _crypto.decryptIdentityBackup(
      passphrase: passphrase,
      ciphertextBase64: activeBackup.ciphertextBase64,
      nonceBase64: activeBackup.nonceBase64,
      kdfSaltBase64: activeBackup.kdfSaltBase64,
    );
    final keyPair = await X25519().newKeyPairFromSeed(privateBytes);
    final publicKey = await keyPair.extractPublicKey();
    final derivedPublicB64 = base64Encode(publicKey.bytes);

    var keyVersion = 1;
    try {
      final serverKey = await fetchPeerPublicKey(currentUserId);
      keyVersion = serverKey.publicKeyBase64 == derivedPublicB64
          ? serverKey.keyVersion
          : serverKey.keyVersion + 1;
    } on DmException catch (e) {
      if (!e.isPublicKeyNotFound) rethrow;
    }

    await _storeIdentity(
      privateKeyBytes: privateBytes,
      keyVersion: keyVersion,
    );
    await _uploadPublicKey(
      publicKeyBase64: derivedPublicB64,
      keyVersion: keyVersion,
    );
    await _storage.write(
      key: AppConfig.dmBackupVersionKey,
      value: '${activeBackup.backupVersion}',
    );
  }

  Future<DmKeyBackup> fetchKeyBackup({int? backupVersion}) async {
    try {
      final query = backupVersion != null
          ? {'backup_version': backupVersion}
          : null;
      final response = await _apiClient.get(
        ApiEndpoints.dmKeyBackup,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        return DmKeyBackup.fromJson(response.data as Map<String, dynamic>);
      }
      throw const DmException(code: 'unknown', message: 'Failed to fetch backup');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> uploadIdentityBackup(String passphrase) async {
    final privateKeyB64 = await _storage.read(key: AppConfig.dmPrivateKeyKey);
    if (privateKeyB64 == null) {
      throw const DmException(
        code: 'no_local_key',
        message: 'Set up messaging before creating a backup',
      );
    }
    final privateBytes = base64Decode(privateKeyB64);
    final encrypted = await _crypto.encryptIdentityBackup(
      privateKeyBytes: privateBytes,
      passphrase: passphrase,
    );

    int latestVersion = 0;
    try {
      final existingBackup = await fetchKeyBackup();
      latestVersion = existingBackup.backupVersion;
    } catch (_) {
      // If no backup exists on the server, we start at 0
    }

    final versionStr = await _storage.read(key: AppConfig.dmBackupVersionKey);
    final localVersion = int.tryParse(versionStr ?? '') ?? 0;
    final backupVersion = (localVersion > latestVersion ? localVersion : latestVersion) + 1;

    await _apiClient.put(
      ApiEndpoints.dmKeyBackup,
      data: {
        'backup_version': backupVersion,
        'ciphertext': encrypted.ciphertextBase64,
        'nonce': encrypted.nonceBase64,
        'kdf_salt': encrypted.kdfSaltBase64,
      },
    );
    await _storage.write(
      key: AppConfig.dmBackupVersionKey,
      value: '$backupVersion',
    );
  }

  Future<bool> hasServerBackup() async {
    try {
      await fetchKeyBackup();
      return true;
    } on DmException catch (e) {
      if (e.code == 'backup_not_found') return false;
      rethrow;
    }
  }

  Future<void> clearLocalData() async {
    _aesKeyCache.clear();
    _peerKeyCache.clear();
    _userCache.clear();
    await _storage.delete(key: AppConfig.dmPrivateKeyKey);
    await _storage.delete(key: AppConfig.dmPublicKeyVersionKey);
    await _storage.delete(key: AppConfig.dmBackupVersionKey);
    await _localStorage.clearAll();
  }

  Future<DmPublicKey> fetchPeerPublicKey(
    String userId, {
    int? keyVersion,
  }) async {
    if (keyVersion != null) {
      final cached = _peerKeyCache[_peerCacheKey(userId, keyVersion)];
      if (cached != null) return cached;
    } else {
      final cached = _peerKeyCache[userId];
      if (cached != null) return cached;
    }

    try {
      final query = keyVersion != null
          ? {'key_version': keyVersion}
          : null;
      final response = await _apiClient.get(
        ApiEndpoints.getDmKey(userId),
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final key = DmPublicKey.fromJson(response.data as Map<String, dynamic>);
        DmCryptoService.validatePublicKeyBase64(key.publicKeyBase64);
        _peerKeyCache[_peerCacheKey(userId, key.keyVersion)] = key;
        if (keyVersion == null) {
          _peerKeyCache[userId] = key;
        }
        return key;
      }
      throw const DmException(
        code: 'unknown',
        message: 'Failed to fetch public key',
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    } on FormatException {
      throw const DmException(
        code: 'invalid_peer_public_key',
        message: 'Peer has an invalid encryption key on the server',
      );
    }
  }

  Future<List<DmPublicKey>> fetchPeerKeyVersions(String userId) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.getDmKeyVersions(userId),
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final versions = (data['versions'] as List<dynamic>? ?? [])
            .map((json) => DmPublicKey.fromJson(json as Map<String, dynamic>))
            .toList();
        for (final key in versions) {
          _peerKeyCache[_peerCacheKey(userId, key.keyVersion)] = key;
        }
        return versions;
      }
      return const [];
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<DmConversation> startConversation(String peerUserId) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.createDmConversation,
        data: {'user_id': peerUserId},
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final convJson =
            data['conversation'] as Map<String, dynamic>? ?? data;
        final conversation = DmConversation(
          conversationId: convJson['conversation_id'] as String,
          otherUserId: peerUserId,
          lastMessageAt: DateTime.parse(convJson['last_message_at'] as String),
          createdAt: DateTime.parse(convJson['created_at'] as String),
        );
        await _localStorage.upsertConversation(conversation);
        return conversation;
      }
      throw const DmException(
        code: 'unknown',
        message: 'Failed to start conversation',
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<DmConversationPage> getConversations({
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit.clamp(1, 100)};
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      final response = await _apiClient.get(
        ApiEndpoints.getDmConversations,
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['conversations'] as List<dynamic>? ?? [])
            .map((json) => DmConversation.fromJson(json as Map<String, dynamic>))
            .toList();
        final nextCursor = data['next_cursor'] as String? ?? '';

        for (final conv in list) {
          final local = await _localStorage.getConversation(conv.conversationId);
          await _localStorage.upsertConversation(
            conv.copyWith(
              lastMessagePreview: local?.lastMessagePreview,
              unreadCount: local?.unreadCount ?? 0,
            ),
          );
        }

        return DmConversationPage(
          conversations: list,
          nextCursor: nextCursor,
        );
      }
      return const DmConversationPage(conversations: [], nextCursor: '');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<DmMessagePage> getMessages({
    required String conversationId,
    required String currentUserId,
    required String peerUserId,
    int limit = 50,
    String? cursor,
  }) async {
    try {
      final query = <String, dynamic>{'limit': limit.clamp(1, 100)};
      if (cursor != null && cursor.isNotEmpty) {
        query['cursor'] = cursor;
      }
      final response = await _apiClient.get(
        ApiEndpoints.getDmMessages(conversationId),
        queryParameters: query,
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawMessages = (data['messages'] as List<dynamic>? ?? [])
            .map(
              (json) => DmMessage.fromJson(
                json as Map<String, dynamic>,
                conversationId: conversationId,
              ),
            )
            .toList();
        final nextCursor = data['next_cursor'] as String? ?? '';

        final decrypted = await Future.wait(
          rawMessages.map(
            (m) => _decryptMessage(
              message: m,
              currentUserId: currentUserId,
              peerUserId: peerUserId,
            ),
          ),
        );

        for (final message in decrypted) {
          await _localStorage.upsertMessage(message);
        }

        return DmMessagePage(messages: decrypted, nextCursor: nextCursor);
      }
      return const DmMessagePage(messages: [], nextCursor: '');
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<DmMessage> decryptIncomingMessage({
    required DmMessage message,
    required String currentUserId,
    required String peerUserId,
  }) {
    return _decryptMessage(
      message: message,
      currentUserId: currentUserId,
      peerUserId: peerUserId,
    );
  }

  Future<DmSendResult> sendMessage({
    required String conversationId,
    required String recipientUserId,
    required String plaintext,
    required String senderId,
  }) async {
    final peerKey = await _getPeerKey(recipientUserId);
    try {
      return await _sendEncrypted(
        conversationId: conversationId,
        recipientUserId: recipientUserId,
        plaintext: plaintext,
        senderId: senderId,
        recipientKeyVersion: peerKey.keyVersion,
      );
    } on DmException catch (e) {
      if (e.isKeyVersionMismatch && e.currentKeyVersion != null) {
        _invalidatePeerCache(recipientUserId);
        final refreshed = await fetchPeerPublicKey(recipientUserId);
        return _sendEncrypted(
          conversationId: conversationId,
          recipientUserId: recipientUserId,
          plaintext: plaintext,
          senderId: senderId,
          recipientKeyVersion: refreshed.keyVersion,
        );
      }
      rethrow;
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.deleteDmConversation(conversationId),
      );
      await _localStorage.removeConversation(conversationId);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      await _apiClient.delete(
        ApiEndpoints.deleteDmMessage(messageId),
        queryParameters: {'conversation_id': conversationId},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<void> markConversationRead({
    required String conversationId,
    required String lastReadId,
  }) async {
    try {
      await _apiClient.put(
        ApiEndpoints.markDmConversationRead(conversationId),
        data: {'last_read_id': lastReadId},
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<User?> fetchUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    try {
      final response = await _apiClient.get(ApiEndpoints.getUser(userId));
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        final userJson =
            body['user'] as Map<String, dynamic>? ??
            body['data'] as Map<String, dynamic>? ??
            body;
        final user = User.fromJson(userJson);
        _userCache[userId] = user;
        return user;
      }
    } catch (_) {}
    return null;
  }

  Future<void> updateConversationPreview({
    required String conversationId,
    required String preview,
    DateTime? lastMessageAt,
    int? unreadDelta,
  }) async {
    final existing = await _localStorage.getConversation(conversationId);
    if (existing == null) return;
    await _localStorage.upsertConversation(
      existing.copyWith(
        lastMessagePreview: preview,
        lastMessageAt: lastMessageAt ?? existing.lastMessageAt,
        unreadCount: unreadDelta == null
            ? existing.unreadCount
            : (existing.unreadCount + unreadDelta).clamp(0, 999),
      ),
    );
  }

  Future<void> resetConversationUnread(String conversationId) async {
    final existing = await _localStorage.getConversation(conversationId);
    if (existing == null) return;
    await _localStorage.upsertConversation(
      existing.copyWith(unreadCount: 0),
    );
  }

  Future<List<DmConversation>> getLocalConversations() {
    return _localStorage.getConversations();
  }

  Future<List<DmMessage>> getLocalMessages(String conversationId) {
    return _localStorage.getMessagesForConversation(conversationId);
  }

  Future<bool> peerHasPublicKey(String userId) async {
    try {
      await fetchPeerPublicKey(userId);
      return true;
    } on DmException catch (e) {
      if (e.isPublicKeyNotFound || e.code == 'invalid_peer_public_key') {
        return false;
      }
      rethrow;
    }
  }

  /// Fetches the latest message for rows missing a local preview.
  Future<List<DmConversation>> hydrateConversationPreviews(
    List<DmConversation> conversations, {
    required String currentUserId,
  }) async {
    final hydrated = <DmConversation>[];
    for (final conv in conversations) {
      final preview = conv.lastMessagePreview?.trim();
      if (preview != null && preview.isNotEmpty) {
        hydrated.add(conv);
        continue;
      }
      try {
        final page = await getMessages(
          conversationId: conv.conversationId,
          currentUserId: currentUserId,
          peerUserId: conv.otherUserId,
          limit: 1,
        );
        if (page.messages.isEmpty) {
          hydrated.add(conv);
          continue;
        }
        final latest = page.messages.first;
        final text = latest.isDeleted
            ? 'Message deleted'
            : (latest.plaintext ??
                (latest.decryptFailed ? 'Encrypted message' : 'Message'));
        final updated = conv.copyWith(
          lastMessagePreview: text,
          lastMessageAt: latest.sentAt,
        );
        await _localStorage.upsertConversation(updated);
        hydrated.add(updated);
      } catch (_) {
        hydrated.add(conv);
      }
    }
    return hydrated;
  }

  Future<DmSendResult> _sendEncrypted({
    required String conversationId,
    required String recipientUserId,
    required String plaintext,
    required String senderId,
    required int recipientKeyVersion,
  }) async {
    final peerKey = await _getPeerKey(
      recipientUserId,
      version: recipientKeyVersion,
    );
    final aesKey = await _deriveAesKey(
      peerUserId: recipientUserId,
      peerPublicKeyBase64: peerKey.publicKeyBase64,
      keyVersion: peerKey.keyVersion,
    );
    final encrypted = await _crypto.encrypt(
      plaintext: plaintext,
      aesKey: aesKey,
    );

    try {
      final response = await _apiClient.post(
        ApiEndpoints.sendDmMessage(conversationId),
        data: {
          'ciphertext': encrypted.ciphertextBase64,
          'nonce': encrypted.nonceBase64,
          'key_version': recipientKeyVersion,
        },
      );
      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final messageId = data['message_id'] as String;
        final sentAt = DateTime.parse(data['sent_at'] as String);

        final myVersion = await getLocalKeyVersion() ?? 1;
        final message = DmMessage(
          messageId: messageId,
          conversationId: conversationId,
          senderId: senderId,
          ciphertextBase64: encrypted.ciphertextBase64,
          nonceBase64: encrypted.nonceBase64,
          keyVersion: recipientKeyVersion,
          senderKeyVersion: myVersion,
          sentAt: sentAt,
          plaintext: plaintext,
        );
        await _localStorage.upsertMessage(message);
        await updateConversationPreview(
          conversationId: conversationId,
          preview: plaintext,
          lastMessageAt: sentAt,
        );

        return DmSendResult(messageId: messageId, sentAt: sentAt);
      }
      throw const DmException(
        code: 'unknown',
        message: 'Failed to send message',
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<DmMessage> _decryptMessage({
    required DmMessage message,
    required String currentUserId,
    required String peerUserId,
  }) async {
    if (message.isDeleted) {
      return message;
    }

    if (message.plaintext != null && !message.decryptFailed) {
      return message;
    }

    final isOwnMessage = message.senderId == currentUserId;
    DmPublicKey? remoteKey;
    String? remoteKeyUserId;
    int? remoteKeyVersion;

    try {
      // key_version on the wire is the recipient's version at send time.
      // sender_key_version is the sender's key version at encrypt time.
      // - Incoming: fetch sender public key at sender_key_version.
      // - Own sent: fetch recipient public key at key_version.
      if (isOwnMessage) {
        remoteKeyUserId = peerUserId;
        remoteKeyVersion = message.keyVersion;
        remoteKey = await fetchPeerPublicKey(
          peerUserId,
          keyVersion: message.keyVersion,
        );
      } else {
        remoteKeyUserId = message.senderId;
        remoteKeyVersion = message.senderKeyVersion;
        remoteKey = await fetchPeerPublicKey(
          message.senderId,
          keyVersion: message.senderKeyVersion,
        );
      }

      final aesKey = await _deriveAesKey(
        peerUserId: remoteKeyUserId,
        peerPublicKeyBase64: remoteKey.publicKeyBase64,
        keyVersion: remoteKeyVersion,
      );
      final plaintext = await _crypto.decrypt(
        ciphertextBase64: message.ciphertextBase64,
        nonceBase64: message.nonceBase64,
        aesKey: aesKey,
      );
      return message.copyWith(plaintext: plaintext, decryptFailed: false);
    } catch (e, st) {
      await _logDecryptFailure(
        message: message,
        currentUserId: currentUserId,
        peerUserId: peerUserId,
        isOwnMessage: isOwnMessage,
        remoteKeyUserId: remoteKeyUserId,
        remoteKeyVersion: remoteKeyVersion,
        remoteKeyVersionOnServer: remoteKey?.keyVersion,
        hadCachedPlaintext: message.plaintext != null,
        wasRetry: message.decryptFailed,
        error: e,
        stackTrace: st,
      );
      return message.copyWith(decryptFailed: true);
    }
  }

  /// Debug-only decrypt failure log. Never logs private keys, passphrases, or plaintext.
  Future<void> _logDecryptFailure({
    required DmMessage message,
    required String currentUserId,
    required String peerUserId,
    required bool isOwnMessage,
    required Object error,
    required StackTrace stackTrace,
    String? remoteKeyUserId,
    int? remoteKeyVersion,
    int? remoteKeyVersionOnServer,
    bool hadCachedPlaintext = false,
    bool wasRetry = false,
  }) async {
    if (!kDebugMode) return;

    final hasLocalKey = await hasLocalIdentity();
    final localKeyVersion = await getLocalKeyVersion();
    final errorLabel = switch (error) {
      DmException(:final code) => 'DmException($code)',
      SecretBoxAuthenticationError() => 'SecretBoxAuthenticationError',
      FormatException(:final message) => 'FormatException($message)',
      _ => error.runtimeType.toString(),
    };
    final dmMessage = error is DmException ? error.message : null;

    debugPrint('🔐 DM decrypt failed');
    debugPrint('   message_id: ${message.messageId}');
    debugPrint('   conversation_id: ${message.conversationId}');
    debugPrint('   sender_id: ${message.senderId}');
    debugPrint('   current_user_id: $currentUserId');
    debugPrint('   peer_user_id: $peerUserId');
    debugPrint('   is_own_message: $isOwnMessage');
    debugPrint('   message.key_version (recipient): ${message.keyVersion}');
    debugPrint('   message.sender_key_version: ${message.senderKeyVersion}');
    debugPrint('   remote_key_user_id: ${remoteKeyUserId ?? 'unknown'}');
    debugPrint('   remote_key_version_requested: ${remoteKeyVersion ?? 'unknown'}');
    debugPrint(
      '   remote_key_version_from_server: ${remoteKeyVersionOnServer ?? 'not_fetched'}',
    );
    debugPrint('   local_identity_present: $hasLocalKey');
    debugPrint('   local_key_version: ${localKeyVersion ?? 'none'}');
    debugPrint('   had_cached_plaintext: $hadCachedPlaintext');
    debugPrint('   was_retry_after_prior_failure: $wasRetry');
    debugPrint('   error: $errorLabel');
    if (dmMessage != null) {
      debugPrint('   error_message: $dmMessage');
    }
    debugPrint('   stack: $stackTrace');
  }

  Future<DmPublicKey> _getPeerKey(String userId, {int? version}) async {
    if (version != null) {
      return fetchPeerPublicKey(userId, keyVersion: version);
    }
    return fetchPeerPublicKey(userId);
  }

  Future<SecretKey> _deriveAesKey({
    required String peerUserId,
    required String peerPublicKeyBase64,
    required int keyVersion,
  }) async {
    final cacheKey = _cacheKey(peerUserId, keyVersion);
    final cached = _aesKeyCache[cacheKey];
    if (cached != null) return cached;

    final privateKeyB64 = await _storage.read(key: AppConfig.dmPrivateKeyKey);
    if (privateKeyB64 == null) {
      throw const DmException(
        code: 'no_local_key',
        message: 'Encryption keys not set up',
      );
    }
    final privateBytes = base64Decode(privateKeyB64);
    final aesKey = await _crypto.deriveAesKey(
      privateKeyBytes: privateBytes,
      peerPublicKeyBase64: peerPublicKeyBase64,
    );
    _aesKeyCache[cacheKey] = aesKey;
    return aesKey;
  }

  void _invalidatePeerCache(String userId) {
    _peerKeyCache.removeWhere(
      (key, _) => key == userId || key.startsWith('$userId:'),
    );
    _aesKeyCache.removeWhere((key, _) => key.startsWith('$userId:'));
  }

  Future<void> _uploadPublicKey({
    required String publicKeyBase64,
    required int keyVersion,
  }) async {
    await _apiClient.put(
      ApiEndpoints.uploadDmKey,
      data: {
        'public_key': publicKeyBase64,
        'key_version': keyVersion,
      },
    );
  }

  DmException _mapDioError(DioException e) {
    final data = e.response?.data;
    String code = 'unknown';
    int? currentVersion;

    if (data is Map<String, dynamic>) {
      code = data['error'] as String? ?? code;
      currentVersion = data['current_version'] as int?;
    }

    final message = switch (code) {
      'blocked' => "You can't message this user",
      'forbidden' => 'You are not a participant in this conversation',
      'public_key_not_found' => 'This user has not set up messaging yet',
      'recipient_has_no_public_key' =>
        'Recipient must open the app to receive messages',
      'sender_has_no_public_key' =>
        'Upload your encryption key before sending messages',
      'backup_not_found' => 'No message backup found on the server',
      'key_version_mismatch' => 'Encryption key updated — retrying…',
      _ => 'Something went wrong ($code)',
    };

    return DmException(
      code: code,
      message: message,
      currentKeyVersion: currentVersion,
    );
  }
}

/// Convenience parse for SSE read receipts.
DmReadReceipt? parseDmReadReceipt(Map<String, dynamic> json) {
  if (json['type'] != 'dm_read_receipt') return null;
  return DmReadReceipt.fromJson(json);
}
