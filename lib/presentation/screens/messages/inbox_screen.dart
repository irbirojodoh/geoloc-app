import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/routes.dart';
import '../../../data/models/dm_conversation.dart';
import '../../../data/models/user.dart';
import '../../providers/dm_provider.dart';
import '../../../services/dm_service.dart';
import '../../widgets/dm_backup_dialogs.dart';
import '../../widgets/new_message_sheet.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/top_bar_backdrop.dart';
import '../../widgets/user_avatar.dart';

/// Main messaging inbox — conversation list, search, and compose.
class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _filterController.addListener(() {
      setState(() => _filterQuery = _filterController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inbox = ref.read(dmInboxProvider);
      if (inbox.conversations.isNotEmpty || inbox.isLoading) return;
      ref.read(dmInboxProvider.notifier).loadInbox();
    });
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(dmInboxProvider);
    final pos = _scrollController.position;
    if (state.isLoading || !state.hasMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      ref.read(dmInboxProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  List<DmConversation> _filteredConversations(DmInboxState state) {
    if (_filterQuery.isEmpty) return state.conversations;
    return state.conversations.where((conv) {
      final peer = state.peerUsers[conv.otherUserId];
      final name = peer?.fullName?.toLowerCase() ?? '';
      final username = peer?.username.toLowerCase() ?? '';
      final preview = conv.lastMessagePreview?.toLowerCase() ?? '';
      return name.contains(_filterQuery) ||
          username.contains(_filterQuery) ||
          preview.contains(_filterQuery);
    }).toList();
  }

  void _openChat(DmConversation conv) {
    setShellNavTransitionDirection(1);
    context.push(
      RoutePaths.chatPath(conv.conversationId, conv.otherUserId),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(dmSseHandlerProvider);

    final state = ref.watch(dmInboxProvider);
    final filtered = _filteredConversations(state);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: colorScheme.primary,
        backgroundColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
        strokeWidth: 2.2,
        elevation: 1,
        edgeOffset: 86,
        displacement: 28,
        onRefresh: () => ref.read(dmInboxProvider.notifier).refreshInbox(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              centerTitle: false,
              titleSpacing: 16,
              automaticallyImplyLeading: false,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              clipBehavior: Clip.antiAlias,
              flexibleSpace: TopBarBackdrop(
                blurTintColor: colorScheme.surface,
                blendColor: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages',
                    style: textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'End-to-end encrypted',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'New message',
                  onPressed: () => showNewMessageSheet(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(76),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SearchBar(
                    controller: _filterController,
                    leading: const Icon(Icons.search),
                    hintText: 'Search conversations',
                    backgroundColor: WidgetStatePropertyAll(
                      colorScheme.surfaceContainerHighest,
                    ),
                    trailing: [
                      if (_filterQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _filterController.clear,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (state.identityStatus == DmIdentityStatus.restoreRequired)
              SliverToBoxAdapter(
                child: MaterialBanner(
                  backgroundColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.5),
                  content: Text(
                    state.keysError ??
                        'Restore your encryption key to use messages on this device',
                  ),
                  leading: Icon(Icons.phonelink_setup, color: colorScheme.primary),
                  actions: [
                    TextButton(
                      onPressed: () => showDmRestoreDialog(context, ref),
                      child: const Text('Restore'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await confirmCreateNewIdentity(context);
                        if (ok && context.mounted) {
                          await ref
                              .read(dmInboxProvider.notifier)
                              .createNewIdentity();
                        }
                      },
                      child: const Text('New key'),
                    ),
                  ],
                ),
              )
            else if (!state.keysReady && state.keysError != null)
              SliverToBoxAdapter(
                child: MaterialBanner(
                  content: Text(state.keysError!),
                  actions: [
                    TextButton(
                      onPressed: () => ref
                          .read(dmInboxProvider.notifier)
                          .ensureKeysUploaded(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            if (state.error != null && state.conversations.isEmpty)
              SliverFillRemaining(
                child: ErrorState(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(dmInboxProvider.notifier).loadInbox(),
                ),
              )
            else if (state.isLoading && state.conversations.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.conversations.isEmpty)
              SliverFillRemaining(
                child: EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  message:
                      'Send a private encrypted message to someone you follow or discover in Explore.',
                  actionLabel: 'New message',
                  onAction: () => showNewMessageSheet(context, ref),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No conversations match "$_filterQuery"',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
                sliver: SliverList.builder(
                  itemCount: filtered.length +
                      (state.hasMore && state.isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final conv = filtered[index];
                    final peer = state.peerUsers[conv.otherUserId];
                    return Dismissible(
                      key: ValueKey(conv.conversationId),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete conversation?'),
                            content: const Text(
                              'This removes the chat from your inbox only. '
                              'Messages stay on the server.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (_) {
                        ref
                            .read(dmInboxProvider.notifier)
                            .deleteConversation(conv.conversationId);
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      child: _ConversationTile(
                        conversation: conv,
                        peer: peer,
                        onTap: () => _openChat(conv),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.peer,
    required this.onTap,
  });

  final DmConversation conversation;
  final User? peer;
  final VoidCallback onTap;

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 24) {
      return timeago.format(time, locale: 'en_short');
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[time.weekday - 1];
    }
    return '${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasUnread = conversation.unreadCount > 0;
    final displayName = peer?.fullName?.isNotEmpty == true
        ? peer!.fullName!
        : (peer?.username ?? 'User');
    final preview = conversation.lastMessagePreview ?? 'Tap to start chatting';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: hasUnread
                    ? [
                        colorScheme.primaryContainer.withValues(
                          alpha: brightness == Brightness.dark ? 0.62 : 0.82,
                        ),
                        colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
                      ]
                    : [
                        colorScheme.surfaceContainerLow,
                        colorScheme.surfaceContainer.withValues(alpha: 0.92),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUnread
                    ? colorScheme.primary.withValues(alpha: 0.35)
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        imageUrl: peer?.profilePictureUrl,
                        name: peer?.username ?? '?',
                        size: 52,
                        showBorder: hasUnread,
                      ),
                      if (hasUnread)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight:
                                      hasUnread ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(conversation.lastMessageAt),
                              style: textTheme.labelSmall?.copyWith(
                                color: hasUnread
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                                fontWeight:
                                    hasUnread ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      hasUnread ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  conversation.unreadCount > 99
                                      ? '99+'
                                      : '${conversation.unreadCount}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
