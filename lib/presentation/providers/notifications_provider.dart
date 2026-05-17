import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification.dart';
import '../../services/notification_service.dart';

/// Notifications state
class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? error;
  final int unreadCount;
  final int total;
  final int limit;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.error,
    this.unreadCount = 0,
    this.total = 0,
    this.limit = 50,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? error,
    int? unreadCount,
    int? total,
    int? limit,
    bool clearError = false,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      unreadCount: unreadCount ?? this.unreadCount,
      total: total ?? this.total,
      limit: limit ?? this.limit,
    );
  }
}

/// Notifications provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(notificationServiceProvider));
});

/// Unread count provider (for badge)
final unreadCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});

/// Stream provider for real-time SSE notifications with exponential backoff
final notificationStreamProvider = StreamProvider<AppNotification>((ref) async* {
  final service = ref.watch(notificationServiceProvider);
  int retryCount = 0;
  
  while (true) {
    try {
      yield* service.getNotificationStream();
      // Stream completed normally (e.g. server closed connection), retry shortly
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      retryCount++;
      final backoffSeconds = 2 << (retryCount < 6 ? retryCount : 6); // max 128s
      await Future.delayed(Duration(seconds: backoffSeconds));
    }
  }
});

/// Notifications state notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationService _notificationService;

  NotificationsNotifier(this._notificationService)
      : super(const NotificationsState());

  /// Load initial notifications
  Future<void> loadNotifications() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      const initialLimit = 50;
      final page = await _notificationService.getNotifications(
        limit: initialLimit,
      );

      state = state.copyWith(
        notifications: page.notifications,
        isLoading: false,
        hasMore: page.hasMore,
        unreadCount: page.unreadCount,
        total: page.total,
        limit: initialLimit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load notifications: $e',
      );
    }
  }

  /// Refresh notifications (pull to refresh)
  Future<void> refreshNotifications() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      const refreshedLimit = 50;
      final page = await _notificationService.getNotifications(
        limit: refreshedLimit,
      );

      state = state.copyWith(
        notifications: page.notifications,
        isRefreshing: false,
        hasMore: page.hasMore,
        unreadCount: page.unreadCount,
        total: page.total,
        limit: refreshedLimit,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh notifications: $e',
      );
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextLimit = (state.limit + 25).clamp(1, 100);
      final page = await _notificationService.getNotifications(
        limit: nextLimit,
      );

      state = state.copyWith(
        notifications: page.notifications,
        isLoading: false,
        hasMore: page.hasMore,
        unreadCount: page.unreadCount,
        total: page.total,
        limit: nextLimit,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load more notifications: $e',
      );
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      // Phase 1: local state update only.

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId && !n.isRead) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: newUnreadCount,
      );
    } catch (_) {
      // Ignore errors for mark as read
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (!n.isRead) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: 0,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to mark all as read: $e');
    }
  }

  /// Add a real-time notification to the state
  void addNotification(AppNotification notification) {
    final updatedNotifications = [notification, ...state.notifications];
    final newUnreadCount = updatedNotifications.where((n) => !n.isRead).length;

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: newUnreadCount,
    );
  }

  /// Get grouped notifications by date
  Map<String, List<AppNotification>> get groupedNotifications {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeek = today.subtract(const Duration(days: 7));

    final groups = <String, List<AppNotification>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };

    for (final notification in state.notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      if (date == today) {
        groups['Today']!.add(notification);
      } else if (date == yesterday) {
        groups['Yesterday']!.add(notification);
      } else if (date.isAfter(thisWeek)) {
        groups['This Week']!.add(notification);
      } else {
        groups['Older']!.add(notification);
      }
    }

    // Remove empty groups
    groups.removeWhere((key, value) => value.isEmpty);

    return groups;
  }
}
