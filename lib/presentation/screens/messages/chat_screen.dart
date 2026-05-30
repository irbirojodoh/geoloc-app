import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/dm_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../../data/models/sse_event.dart';
import '../../widgets/top_bar_backdrop.dart';
import '../../widgets/user_avatar.dart';

/// Encrypted 1:1 chat thread.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.peerUserId,
  });

  final String conversationId;
  final String peerUserId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DmChatKey get _chatKey => (
        conversationId: widget.conversationId,
        peerUserId: widget.peerUserId,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadOlder);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dmChatProvider(_chatKey).notifier).initialize();
    });
  }

  void _maybeLoadOlder() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 80) {
      ref.read(dmChatProvider(_chatKey).notifier).loadOlder();
    }
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dmSseHandlerProvider);

    ref.listen(sseStreamProvider, (previous, next) {
      if (!next.hasValue) return;
      final event = next.value;
      if (event is DmSseEvent) {
        ref.read(dmChatProvider(_chatKey).notifier).handleSseEvent(event);
      }
    });

    final state = ref.watch(dmChatProvider(_chatKey));
    final inboxState = ref.watch(dmInboxProvider);
    final keysReady = inboxState.keysReady;
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (state.messages.isNotEmpty) {
      _scrollToBottom();
    }

    final peerName = state.peerUser?.fullName?.isNotEmpty == true
        ? state.peerUser!.fullName!
        : (state.peerUser?.username ?? 'Chat');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: TopBarBackdrop(
          blurTintColor: colorScheme.surface,
          blendColor: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        title: Row(
          children: [
            UserAvatar(
              imageUrl: state.peerUser?.profilePictureUrl,
              name: state.peerUser?.username ?? '?',
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                peerName,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (state.error != null)
            MaterialBanner(
              content: Text(state.error!),
              actions: [
                TextButton(
                  onPressed: () => ref
                      .read(dmChatProvider(_chatKey).notifier)
                      .initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          if (!keysReady)
            MaterialBanner(
              content: Text(
                inboxState.keysError ??
                    'Set up encryption on this device before sending messages',
              ),
              actions: const [SizedBox.shrink()],
            ),
          if (!state.peerHasKey)
            MaterialBanner(
              content: const Text(
                'This user has not set up messaging yet. They must open the app first.',
              ),
              backgroundColor: colorScheme.errorContainer,
              actions: const [SizedBox.shrink()],
            ),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.messages.isEmpty
                    ? const Center(child: Text('Say hello 👋'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          final isMine = message.senderId == currentUserId;
                          final isReadByPeer = state.lastReadByPeerId != null &&
                              _isMessageReadByPeer(
                                message.messageId,
                                state.lastReadByPeerId!,
                                state.messages,
                              );
                          return _MessageBubble(
                            message: message,
                            isMine: isMine,
                            isReadByPeer: isMine && isReadByPeer,
                            onDelete: isMine && !message.isDeleted
                                ? () => ref
                                    .read(dmChatProvider(_chatKey).notifier)
                                    .deleteMessage(message.messageId)
                                : null,
                          );
                        },
                      ),
          ),
          _Composer(
            controller: _composerController,
            enabled: keysReady && state.peerHasKey && !state.isSending,
            onSend: () {
              final text = _composerController.text;
              _composerController.clear();
              ref.read(dmChatProvider(_chatKey).notifier).sendMessage(text);
            },
          ),
        ],
      ),
    );
  }

  bool _isMessageReadByPeer(
    String messageId,
    String lastReadId,
    List<DmMessage> messages,
  ) {
    if (messageId == lastReadId) return true;
    final readIndex = messages.indexWhere((m) => m.messageId == lastReadId);
    final msgIndex = messages.indexWhere((m) => m.messageId == messageId);
    if (readIndex < 0 || msgIndex < 0) return false;
    return msgIndex <= readIndex;
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isReadByPeer,
    this.onDelete,
  });

  final DmMessage message;
  final bool isMine;
  final bool isReadByPeer;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget content;
    if (message.isDeleted) {
      content = Text(
        'Message deleted',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    } else if (message.decryptFailed) {
      content = Text(
        'Unable to decrypt message. Ask the sender to resend, or re-open the chat after both users have opened the app.',
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      );
    } else {
      content = Text(message.plaintext ?? '…');
    }

    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            DefaultTextStyle(
              style: textTheme.bodyMedium!.copyWith(
                color: isMine ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
              child: content,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeago.format(message.sentAt, locale: 'en_short'),
                  style: textTheme.labelSmall?.copyWith(
                    color: isMine
                        ? colorScheme.onPrimary.withValues(alpha: 0.75)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isMine && isReadByPeer) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: colorScheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return bubble;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete message'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete!();
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: bubble,
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: enabled ? 'Message…' : 'Messaging unavailable',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: enabled ? (_) => onSend() : null,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
