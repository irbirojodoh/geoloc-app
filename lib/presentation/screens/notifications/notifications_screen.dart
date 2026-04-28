import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/notification.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

/// Notifications screen — old-money luxury aesthetic
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationsProvider);
    final gold = AppColors.gold(context);

    return Scaffold(
      body: Column(
        children: [
          GeolocAppBar(
            title: 'Notifications',
            leading: IconSquareButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onTap: () => context.pop(),
            ),
            trailing: notificationState.unreadCount > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: TextButton(
                      onPressed: () => ref
                          .read(notificationsProvider.notifier)
                          .markAllAsRead(),
                      child: Text(
                        'Read all',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: gold,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: notificationState.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: gold,
                    ),
                  )
                : notificationState.error != null
                    ? ErrorState(
                        message: notificationState.error!,
                        onRetry: () => ref
                            .read(notificationsProvider.notifier)
                            .loadNotifications(),
                        retryLabel: 'RETRY',
                      )
                    : notificationState.notifications.isEmpty
                        ? const EmptyState(
                            icon: Icons.notifications_outlined,
                            title: 'No notifications yet',
                            message:
                                "When someone interacts with your posts, you'll see it here.",
                          )
                        : _buildNotificationsList(
                            context,
                            ref,
                            notificationState,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
  ) {
    final notifCs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);
    final notifications = state.notifications;

    return RefreshIndicator(
      color: gold,
      onRefresh: () async {
        await ref.read(notificationsProvider.notifier).loadNotifications();
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: 0.5, color: notifCs.outline),
        ),
        itemBuilder: (context, index) {
          final notification = notifications[index];

          return GestureDetector(
            onTap: () {
              ref
                  .read(notificationsProvider.notifier)
                  .markAsRead(notification.id);

              if (notification.targetType == TargetType.post ||
                  notification.targetType == TargetType.comment) {
                context.push('/post/${notification.targetId}');
              } else {
                context.push('/profile/${notification.actorId}');
              }
            },
            child: Container(
              color: notification.isRead
                  ? Colors.transparent
                  : gold.withValues(alpha: 0.04),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread dot
                  if (!notification.isRead)
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: gold,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(width: 14),

                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: notifCs.outline, width: 1),
                    ),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      size: 18,
                      color: gold,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: notification.actor?.username ?? 'Someone',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: notifCs.onSurface,
                                ),
                              ),
                              TextSpan(
                                text:
                                    ' ${_getNotificationText(notification.type)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w400,
                                  fontSize: 14,
                                  color: notifCs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(notification.createdAt,
                              locale: 'en_short'),
                          style: GoogleFonts.firaCode(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
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

  String _getNotificationText(NotificationType type) {
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
