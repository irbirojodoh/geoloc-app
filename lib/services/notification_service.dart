import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/notification.dart';

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(apiClientProvider));
});

/// Response model for paginated notifications
class NotificationPage {
  final List<AppNotification> notifications;
  final bool hasMore;
  final String? nextCursor;

  const NotificationPage({
    required this.notifications,
    required this.hasMore,
    this.nextCursor,
  });
}

/// Service for handling notification operations
class NotificationService {
  final ApiClient _apiClient;

  NotificationService(this._apiClient);

  /// Get paginated notifications
  Future<NotificationPage> getNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{'limit': limit};
    if (cursor != null) {
      queryParams['cursor'] = cursor;
    }

    final response = await _apiClient.get(
      ApiEndpoints.getNotifications,
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final notificationsJson = data['notifications'] as List<dynamic>? ?? [];
      final notifications = notificationsJson
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      return NotificationPage(
        notifications: notifications,
        hasMore: data['has_more'] as bool? ?? false,
        nextCursor: data['next_cursor'] as String?,
      );
    }

    return const NotificationPage(notifications: [], hasMore: false);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _apiClient.put(
      ApiEndpoints.markNotificationRead(notificationId),
    );
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _apiClient.put(ApiEndpoints.markAllNotificationsRead);
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.getNotifications}/unread-count',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['count'] as int? ?? 0;
      }
    } catch (_) {
      // Fallback: count unread from first page
    }
    return 0;
  }
}
