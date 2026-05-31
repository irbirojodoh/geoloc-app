import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../data/models/dm_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../widgets/app_bottom_sheet.dart';
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.16),
                    colorScheme.surfaceContainerLowest.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: state.isLoading && state.messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mark_chat_unread_outlined,
                                size: 28,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Start the conversation',
                                style: textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Messages are end-to-end encrypted',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                            return _BubbleEntrance(
                              key: ValueKey(message.messageId),
                              isMine: isMine,
                              child: _MessageBubble(
                                message: message,
                                isMine: isMine,
                                isReadByPeer: isMine && isReadByPeer,
                                onDelete: isMine && !message.isDeleted
                                    ? () => ref
                                        .read(dmChatProvider(_chatKey).notifier)
                                        .deleteMessage(message.messageId)
                                    : null,
                              ),
                            );
                          },
                        ),
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

  String _formatSentAt(BuildContext context, DateTime sentAt) {
    final local = sentAt.toLocal();
    final now = DateTime.now();
    final sameDay = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final sameYear = now.year == local.year;
    final time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
    );
    if (sameDay) return time;
    if (sameYear) return '${local.month}/${local.day} $time';
    return '${local.year}/${local.month}/${local.day} $time';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mineBase = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.24 : 0.12),
      colorScheme.primaryContainer,
    );
    final otherBase = colorScheme.surfaceContainerHighest;
    final bubbleColor = message.decryptFailed
        ? colorScheme.errorContainer
        : (isMine ? mineBase : otherBase);
    final bubbleBrightness = ThemeData.estimateBrightnessForColor(bubbleColor);
    final bubbleTextColor = bubbleBrightness == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;
    final bubbleMetaColor = bubbleTextColor.withValues(alpha: 0.74);

    Widget content;
    if (message.isDeleted) {
      content = Text(
        'Message deleted',
        style: textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: bubbleMetaColor,
        ),
      );
    } else if (message.decryptFailed) {
      content = Text(
        'Unable to decrypt this message. Ask the sender to resend.',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      content = Text(
        message.plaintext ?? '…',
        style: textTheme.bodyMedium?.copyWith(
          color: bubbleTextColor,
          fontWeight: FontWeight.w500,
          height: 1.32,
        ),
      );
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
          color: bubbleColor,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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
                color: bubbleTextColor,
              ),
              child: content,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatSentAt(context, message.sentAt),
                  style: textTheme.labelSmall?.copyWith(
                    color: bubbleMetaColor,
                  ),
                ),
                if (isMine && isReadByPeer) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 14,
                    color: bubbleMetaColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return bubble;

    return _PressScale(
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.lightImpact();
          showAppBottomSheet<void>(
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
      ),
    );
  }
}

class _BubbleEntrance extends StatefulWidget {
  const _BubbleEntrance({
    super.key,
    required this.child,
    required this.isMine,
  });

  final Widget child;
  final bool isMine;

  @override
  State<_BubbleEntrance> createState() => _BubbleEntranceState();
}

class _BubbleEntranceState extends State<_BubbleEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startDx = widget.isMine ? 0.05 : -0.05;
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        return Opacity(
          opacity: _curve.value,
          child: Transform.translate(
            offset: Offset((1 - _curve.value) * startDx * 260, (1 - _curve.value) * 8),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onLongPressStart: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
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
    final textTheme = Theme.of(context).textTheme;
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
                  hintStyle: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.9),
                      width: 1.3,
                    ),
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
            IconButton.filledTonal(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
              icon: const Icon(Icons.send_rounded, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
