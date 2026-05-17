import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

/// Notifications screen.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    Future<void>.microtask(() {
      final current = ref.read(notificationsProvider);
      if (current.notifications.isEmpty && !current.isLoading) {
        ref.read(notificationsProvider.notifier).loadNotifications();
      }
    });
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    final state = ref.read(notificationsProvider);
    final pos = _scrollController.position;
    if (state.isLoading || !state.hasMore) return;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: colorScheme.primary,
        onRefresh: () =>
            ref.read(notificationsProvider.notifier).refreshNotifications(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
                SliverAppBar.medium(
                  backgroundColor: colorScheme.surface,
                  title: Text(
                    'Notifications',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    if (state.unreadCount > 0)
                      TextButton(
                        onPressed: () =>
                            ref.read(notificationsProvider.notifier).markAllAsRead(),
                        child: const Text('Read all'),
                      ),
                  ],
                ),
                if (state.isLoading)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  )
                else if (state.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorState(
                      message: state.error!,
                      onRetry: () => ref
                          .read(notificationsProvider.notifier)
                          .loadNotifications(),
                      retryLabel: 'RETRY',
                    ),
                  )
                else if (state.notifications.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.notifications_outlined,
                      title: 'No notifications yet',
                      message:
                          "When someone interacts with your posts, you'll see it here.",
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    sliver: SliverList.builder(
                      itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.notifications.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: colorScheme.primary,
                              ),
                            ),
                          );
                        }
                        final item = state.notifications[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _NotificationTile(
                            item: item,
                            textTheme: textTheme,
                            onTap: () {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .markAsRead(item.id);
                              if (item.targetType == TargetType.post ||
                                  item.targetType == TargetType.comment) {
                                if (item.targetType == TargetType.post &&
                                    item.targetId != null &&
                                    item.targetId!.isNotEmpty) {
                                  // Notifications(2) -> Post detail(0.5): slide from left.
                                  setShellNavTransitionDirection(-1);
                                  context.push('/post/${item.targetId}');
                                } else {
                                  context.push('/profile/${item.actorId}');
                                }
                              } else {
                                context.push('/profile/${item.actorId}');
                              }
                            },
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.textTheme,
    required this.onTap,
  });

  final AppNotification item;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actorName = item.actor?.username ?? 'Someone';
    final actionText = item.message.trim().isNotEmpty
        ? item.message.trim()
        : _textFor(item.type);
    final previewText = item.payload?['post_preview']?.trim();

    return Card(
      color: item.isRead
          ? colorScheme.surface
          : colorScheme.primaryContainer.withValues(alpha: 0.22),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 8, right: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 14),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(item.type),
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                        children: [
                          TextSpan(
                            text: actorName,
                            style: textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                          ),
                          TextSpan(text: ' $actionText'),
                        ],
                      ),
                    ),
                    if (previewText != null && previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(item.createdAt, locale: 'en_short'),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(NotificationType type) {
    return switch (type) {
      NotificationType.like => Icons.favorite_outline,
      NotificationType.comment => Icons.chat_bubble_outline,
      NotificationType.follow => Icons.person_add_outlined,
      NotificationType.locationPost => Icons.location_on_outlined,
    };
  }

  static String _textFor(NotificationType type) {
    return switch (type) {
      NotificationType.like => 'liked your post',
      NotificationType.comment => 'commented on your post',
      NotificationType.follow => 'started following you',
      NotificationType.locationPost => 'posted near you',
    };
  }
}
