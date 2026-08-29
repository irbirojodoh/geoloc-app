import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/dm_exception.dart';
import '../../data/models/dm_conversation.dart';
import '../../data/models/dm_message.dart';
import '../../data/models/dm_read_receipt.dart';
import '../../data/models/sse_event.dart';
import '../../data/models/user.dart';
import '../../services/dm_service.dart';
import 'auth_provider.dart';
import 'notifications_provider.dart';

class DmInboxState {
  final List<DmConversation> conversations;
  final Map<String, User> peerUsers;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final bool keysReady;
  final String? keysError;
  final DmIdentityStatus identityStatus;

  const DmInboxState({
    this.conversations = const [],
    this.peerUsers = const {},
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.keysReady = true,
    this.keysError,
    this.identityStatus = DmIdentityStatus.ready,
  });

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  DmInboxState copyWith({
    List<DmConversation>? conversations,
    Map<String, User>? peerUsers,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
    bool? keysReady,
    String? keysError,
    bool clearKeysError = false,
    DmIdentityStatus? identityStatus,
  }) {
    return DmInboxState(
      conversations: conversations ?? this.conversations,
      peerUsers: peerUsers ?? this.peerUsers,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
      keysReady: keysReady ?? this.keysReady,
      keysError: clearKeysError ? null : (keysError ?? this.keysError),
      identityStatus: identityStatus ?? this.identityStatus,
    );
  }
}

final dmInboxProvider =
    StateNotifierProvider<DmInboxNotifier, DmInboxState>((ref) {
  return DmInboxNotifier(
    ref.watch(dmServiceProvider),
    () => ref.read(currentUserProvider)?.id,
  );
});

final dmUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(dmInboxProvider.select((s) => s.totalUnread));
});

class DmInboxNotifier extends StateNotifier<DmInboxState> {
  DmInboxNotifier(this._dmService, this._currentUserId)
      : super(const DmInboxState());

  final DmService _dmService;
  final String? Function() _currentUserId;

  Future<void> ensureKeysUploaded() async {
    try {
      final status = await _dmService.getIdentityStatus();
      if (status == DmIdentityStatus.restoreRequired) {
        state = state.copyWith(
          identityStatus: status,
          keysReady: false,
          keysError:
              'Restore your encryption key from backup to use messages on this device',
        );
        return;
      }

      await _dmService.ensureKeysUploaded();
      state = state.copyWith(
        keysReady: true,
        identityStatus: DmIdentityStatus.ready,
        clearKeysError: true,
      );
    } catch (_) {
      state = state.copyWith(
        keysReady: false,
        keysError: 'Could not set up encrypted messaging',
      );
    }
  }

  Future<void> restoreFromBackup(String passphrase) async {
    final userId = _currentUserId();
    if (userId == null) return;

    await _dmService.restoreIdentityFromBackup(
      passphrase: passphrase,
      currentUserId: userId,
    );
    state = state.copyWith(
      keysReady: true,
      identityStatus: DmIdentityStatus.ready,
      clearKeysError: true,
    );
    await loadInbox(force: true);
  }

  Future<void> createNewIdentity() async {
    await _dmService.createNewIdentity();
    state = state.copyWith(
      keysReady: true,
      identityStatus: DmIdentityStatus.ready,
      clearKeysError: true,
    );
    await loadInbox(force: true);
  }

  Future<void> uploadBackup(String passphrase) async {
    await _dmService.uploadIdentityBackup(passphrase);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _dmService.deleteConversation(conversationId);
    state = state.copyWith(
      conversations: state.conversations
          .where((c) => c.conversationId != conversationId)
          .toList(),
    );
  }

  /// Clears unread for a conversation without a full inbox network refresh.
  void markConversationReadLocally(String conversationId) {
    final updated = state.conversations
        .map(
          (c) => c.conversationId == conversationId
              ? c.copyWith(unreadCount: 0)
              : c,
        )
        .toList();
    state = state.copyWith(conversations: updated);
  }

  Future<void> loadInbox({bool force = false}) async {
    if (state.isLoading) return;
    if (!force && state.conversations.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      unawaited(ensureKeysUploaded());

      final local = await _dmService.getLocalConversations();
      if (local.isNotEmpty) {
        state = state.copyWith(conversations: local);
      }

      final page = await _dmService.getConversations();
      var merged = await _mergeLocalPreviews(page.conversations);
      final userId = _currentUserId();
      if (userId != null) {
        merged = await _dmService.hydrateConversationPreviews(
          merged,
          currentUserId: userId,
        );
      }
      final users = await _loadPeerUsers(merged);

      state = state.copyWith(
        conversations: merged,
        peerUsers: users,
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor.isEmpty ? null : page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages: $e',
      );
    }
  }

  Future<void> refreshInbox() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await _dmService.getConversations();
      var merged = await _mergeLocalPreviews(page.conversations);
      final userId = _currentUserId();
      if (userId != null) {
        merged = await _dmService.hydrateConversationPreviews(
          merged,
          currentUserId: userId,
        );
      }
      final users = await _loadPeerUsers(merged);
      state = state.copyWith(
        conversations: merged,
        peerUsers: users,
        isRefreshing: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor.isEmpty ? null : page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh: $e',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.nextCursor == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final page = await _dmService.getConversations(
        cursor: state.nextCursor,
      );
      final merged = await _mergeLocalPreviews(page.conversations);
      final existingIds =
          state.conversations.map((c) => c.conversationId).toSet();
      final appended = [
        ...state.conversations,
        ...merged.where((c) => !existingIds.contains(c.conversationId)),
      ];
      final users = await _loadPeerUsers(appended);
      state = state.copyWith(
        conversations: appended,
        peerUsers: {...state.peerUsers, ...users},
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor.isEmpty ? null : page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<DmConversation?> openConversationWith(String peerUserId) async {
    final conversation = await _dmService.startConversation(peerUserId);
    final merged = await _mergeLocalPreviews([conversation]);
    final conv = merged.first;
    final users = await _loadPeerUsers([conv]);
    final existing = state.conversations
        .where((c) => c.conversationId != conv.conversationId)
        .toList();
    state = state.copyWith(
      conversations: [conv, ...existing],
      peerUsers: {...state.peerUsers, ...users},
    );
    return conv;
  }

  void handleSseEvent(DmSseEvent event) {
    if (event.type == 'dm_new_message') {
      unawaited(_handleNewMessage(event.json));
    }
  }

  Future<void> _handleNewMessage(Map<String, dynamic> json) async {
    final message = DmMessage.fromSseJson(json);
    final currentUserId = _currentUserId();
    if (currentUserId == null) return;

    final conv = state.conversations.where(
      (c) => c.conversationId == message.conversationId,
    );
    final matched = conv.isEmpty ? null : conv.first;
    final peerUserId = matched?.otherUserId ??
        (message.senderId == currentUserId ? null : message.senderId);

    if (peerUserId == null) {
      unawaited(refreshInbox());
      return;
    }

    final decrypted = await _dmService.decryptIncomingMessage(
      message: message,
      currentUserId: currentUserId,
      peerUserId: peerUserId,
    );
    await _dmService.updateConversationPreview(
      conversationId: message.conversationId,
      preview: decrypted.isDeleted
          ? 'Message deleted'
          : (decrypted.plaintext ?? 'New message'),
      lastMessageAt: message.sentAt,
      unreadDelta: message.senderId == currentUserId ? 0 : 1,
    );

    final updatedLocal = await _dmService.getLocalConversations();
    state = state.copyWith(conversations: updatedLocal);
  }

  Future<List<DmConversation>> _mergeLocalPreviews(
    List<DmConversation> remote,
  ) async {
    final local = await _dmService.getLocalConversations();
    return remote.map((conv) {
      final match = local.where(
        (c) => c.conversationId == conv.conversationId,
      );
      final localConv = match.isEmpty ? null : match.first;
      return conv.copyWith(
        lastMessagePreview: localConv?.lastMessagePreview,
        unreadCount: localConv?.unreadCount ?? 0,
      );
    }).toList();
  }

  Future<Map<String, User>> _loadPeerUsers(List<DmConversation> convs) async {
    final map = <String, User>{};
    for (final conv in convs) {
      if (state.peerUsers.containsKey(conv.otherUserId)) {
        map[conv.otherUserId] = state.peerUsers[conv.otherUserId]!;
        continue;
      }
      final user = await _dmService.fetchUser(conv.otherUserId);
      if (user != null) map[conv.otherUserId] = user;
    }
    return map;
  }
}

typedef DmChatKey = ({String conversationId, String peerUserId});

class DmChatState {
  final String conversationId;
  final String peerUserId;
  final User? peerUser;
  final List<DmMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final String? nextCursor;
  final String? error;
  final bool peerHasKey;
  final String? lastReadByPeerId;

  const DmChatState({
    required this.conversationId,
    required this.peerUserId,
    this.peerUser,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.peerHasKey = true,
    this.lastReadByPeerId,
  });

  DmChatState copyWith({
    User? peerUser,
    List<DmMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
    bool? peerHasKey,
    String? lastReadByPeerId,
  }) {
    return DmChatState(
      conversationId: conversationId,
      peerUserId: peerUserId,
      peerUser: peerUser ?? this.peerUser,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
      peerHasKey: peerHasKey ?? this.peerHasKey,
      lastReadByPeerId: lastReadByPeerId ?? this.lastReadByPeerId,
    );
  }
}

final dmChatProvider = StateNotifierProvider.autoDispose
    .family<DmChatNotifier, DmChatState, DmChatKey>(
  (ref, key) {
    return DmChatNotifier(
      ref.watch(dmServiceProvider),
      conversationId: key.conversationId,
      peerUserId: key.peerUserId,
      currentUserId: () => ref.read(currentUserProvider)?.id,
      inboxNotifier: ref.read(dmInboxProvider.notifier),
    );
  },
);

class DmChatNotifier extends StateNotifier<DmChatState> {
  DmChatNotifier(
    this._dmService, {
    required String conversationId,
    required String peerUserId,
    required this.currentUserId,
    required DmInboxNotifier inboxNotifier,
  })  : _inboxNotifier = inboxNotifier,
        super(
          DmChatState(
            conversationId: conversationId,
            peerUserId: peerUserId,
          ),
        );

  final DmService _dmService;
  final DmInboxNotifier _inboxNotifier;
  final String? Function() currentUserId;

  Timer? _readDebounce;
  final Set<String> _inFlightMessageIds = {};

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _dmService.fetchUser(state.peerUserId);
      final hasKey = await _dmService.peerHasPublicKey(state.peerUserId);

      final local = await _dmService.getLocalMessages(state.conversationId);
      if (local.isNotEmpty) {
        state = state.copyWith(
          messages: local,
          peerUser: user,
          peerHasKey: hasKey,
        );
      }

      final userId = currentUserId();
      if (userId == null) return;

      final page = await _dmService.getMessages(
        conversationId: state.conversationId,
        currentUserId: userId,
        peerUserId: state.peerUserId,
      );

      state = state.copyWith(
        messages: _sortMessages(page.messages),
        peerUser: user,
        peerHasKey: hasKey,
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor.isEmpty ? null : page.nextCursor,
      );

      _scheduleMarkRead();
      await _dmService.resetConversationUnread(state.conversationId);
      _inboxNotifier.markConversationReadLocally(state.conversationId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> loadOlder() async {
    if (state.isLoading || !state.hasMore || state.nextCursor == null) return;
    final userId = currentUserId();
    if (userId == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final page = await _dmService.getMessages(
        conversationId: state.conversationId,
        currentUserId: userId,
        peerUserId: state.peerUserId,
        cursor: state.nextCursor,
      );
      final existingIds = state.messages.map((m) => m.messageId).toSet();
      final older = page.messages
          .where((m) => !existingIds.contains(m.messageId))
          .toList();
      state = state.copyWith(
        messages: _sortMessages([...older, ...state.messages]),
        isLoading: false,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor.isEmpty ? null : page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> sendMessage(String plaintext) async {
    final trimmed = plaintext.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userId = currentUserId();
    if (userId == null) return;

    state = state.copyWith(isSending: true, clearError: true);
    try {
      final result = await _dmService.sendMessage(
        conversationId: state.conversationId,
        recipientUserId: state.peerUserId,
        plaintext: trimmed,
        senderId: userId,
      );

      final localMessages =
          await _dmService.getLocalMessages(state.conversationId);
      final sent = localMessages.firstWhere(
        (m) => m.messageId == result.messageId,
        orElse: () => DmMessage(
          messageId: result.messageId,
          conversationId: state.conversationId,
          senderId: userId,
          ciphertextBase64: '',
          nonceBase64: '',
          keyVersion: 0,
          senderKeyVersion: 0,
          sentAt: result.sentAt,
          plaintext: trimmed,
        ),
      );

      final alreadyShown =
          state.messages.any((m) => m.messageId == sent.messageId);
      state = state.copyWith(
        messages: alreadyShown
            ? state.messages
            : _sortMessages([...state.messages, sent]),
        isSending: false,
      );
      _scheduleMarkRead();
    } on DmException catch (e) {
      state = state.copyWith(isSending: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isSending: false, error: '$e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _dmService.deleteMessage(
        messageId: messageId,
        conversationId: state.conversationId,
      );
      final updated = state.messages.map((m) {
        if (m.messageId == messageId) {
          return m.copyWith(
            deletedAt: DateTime.now(),
            clearPlaintext: true,
          );
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
    } on DmException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  void handleSseEvent(DmSseEvent event) {
    if (event.type == 'dm_new_message') {
      unawaited(_handleIncoming(event.json));
    } else if (event.type == 'dm_read_receipt') {
      final receipt = DmReadReceipt.fromJson(event.json);
      if (receipt.conversationId == state.conversationId) {
        state = state.copyWith(lastReadByPeerId: receipt.lastReadId);
      }
    }
  }

  Future<void> _handleIncoming(Map<String, dynamic> json) async {
    if (json['conversation_id'] != state.conversationId) return;

    final message = DmMessage.fromSseJson(json);
    final userId = currentUserId();
    if (userId == null) return;

    // Own sends are appended in sendMessage(); SSE echo would duplicate.
    if (message.senderId == userId) return;
    if (state.messages.any((m) => m.messageId == message.messageId)) return;
    if (_inFlightMessageIds.contains(message.messageId)) return;

    _inFlightMessageIds.add(message.messageId);
    try {
      final decrypted = await _dmService.decryptIncomingMessage(
        message: message,
        currentUserId: userId,
        peerUserId: state.peerUserId,
      );

      if (state.messages.any((m) => m.messageId == message.messageId)) return;

      state = state.copyWith(
        messages: _sortMessages([...state.messages, decrypted]),
      );
      _scheduleMarkRead();
    } finally {
      _inFlightMessageIds.remove(message.messageId);
    }
  }

  void _scheduleMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_markRead());
    });
  }

  Future<void> _markRead() async {
    DmMessage? newest;
    for (final m in state.messages) {
      if (m.isDeleted) continue;
      if (newest == null || m.sentAt.isAfter(newest.sentAt)) {
        newest = m;
      }
    }
    if (newest == null) return;

    try {
      await _dmService.markConversationRead(
        conversationId: state.conversationId,
        lastReadId: newest.messageId,
      );
      await _dmService.resetConversationUnread(state.conversationId);
    } catch (_) {}
  }

  List<DmMessage> _sortMessages(List<DmMessage> messages) {
    final sorted = [...messages]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return sorted;
  }

  @override
  void dispose() {
    _readDebounce?.cancel();
    super.dispose();
  }
}

/// Routes SSE DM events to inbox + active chat threads.
final dmSseHandlerProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<SseEvent>>(sseStreamProvider, (previous, next) {
    if (!next.hasValue) return;
    final event = next.value;
    if (event is! DmSseEvent) return;

    ref.read(dmInboxProvider.notifier).handleSseEvent(event);

    final convId = event.json['conversation_id'] as String?;
    if (convId == null) return;

    final currentUserId = ref.read(currentUserProvider)?.id;
    if (currentUserId == null) return;

    String? peerUserId;
    final inbox = ref.read(dmInboxProvider);
    for (final conv in inbox.conversations) {
      if (conv.conversationId == convId) {
        peerUserId = conv.otherUserId;
        break;
      }
    }

    if (peerUserId == null && event.type == 'dm_new_message') {
      final senderId = event.json['sender_id'] as String?;
      if (senderId != null && senderId != currentUserId) {
        peerUserId = senderId;
      }
    }

    if (peerUserId == null) return;

    ref
        .read(
          dmChatProvider((
            conversationId: convId,
            peerUserId: peerUserId,
          )).notifier,
        )
        .handleSseEvent(event);
  });
});
