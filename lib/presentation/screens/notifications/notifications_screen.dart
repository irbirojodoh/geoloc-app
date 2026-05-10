import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../data/models/notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

/// Notifications screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: const Text('Read all'),
            ),
        ],
      ),
      body: state.isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colorScheme.primary,
              ),
            )
          : state.error != null
              ? ErrorState(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(notificationsProvider.notifier).loadNotifications(),
                  retryLabel: 'RETRY',
                )
              : state.notifications.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_outlined,
                      title: 'No notifications yet',
                      message:
                          "When someone interacts with your posts, you'll see it here.",
                    )
                  : _NotificationList(
                      state: state,
                      textTheme: textTheme,
                    ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.state, required this.textTheme});

  final NotificationsState state;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final notifications = state.notifications;

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () =>
          ref.read(notificationsProvider.notifier).refreshNotifications(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (!state.isLoading &&
              state.hasMore &&
              scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
            ref.read(notificationsProvider.notifier).loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: notifications.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant,
            ),
          ),
          itemBuilder: (context, index) {
            if (index == notifications.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: colorScheme.primary,
                  ),
                ),
              );
            }

            final item = notifications[index];
            final actorName = item.actor?.username ?? 'Someone';

            return Material(
              color: item.isRead
                  ? colorScheme.surface
                  : colorScheme.primaryContainer.withValues(alpha: 0.22),
              child: InkWell(
                onTap: () {
                  ref.read(notificationsProvider.notifier).markAsRead(item.id);
                  if (item.targetType == TargetType.post ||
                      item.targetType == TargetType.comment) {
                    context.push('/post/${item.targetId}');
                  } else {
                    context.push('/profile/${item.actorId}');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  TextSpan(text: ' ${_textFor(item.type)}'),
                                ],
                              ),
                            ),
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
          },
        ),
      ),
    );
  }

  IconData _iconFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Icons.favorite_outline;
      case NotificationType.comment:
        return Icons.chat_bubble_outline;
      case NotificationType.follow:
        return Icons.person_add_outlined;
      case NotificationType.locationPost:
        return Icons.location_on_outlined;
    }
  }

  String _textFor(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return 'liked your post';
      case NotificationType.comment:
        return 'commented on your post';
      case NotificationType.follow:
        return 'started following you';
      case NotificationType.locationPost:
        return 'posted near you';
    }
  }
}
