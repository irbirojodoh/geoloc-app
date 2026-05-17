import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/notification.dart';
import '../data/models/user.dart';

/// Provider for NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(apiClientProvider));
});

/// Response model for paginated notifications
class NotificationPage {
  final List<AppNotification> notifications;
  final int unreadCount;
  final int total;
  final bool hasMore;

  const NotificationPage({
    required this.notifications,
    required this.unreadCount,
    required this.total,
    required this.hasMore,
  });
}

/// Service for handling notification operations
class NotificationService {
  final ApiClient _apiClient;
  final Map<String, User> _actorCache = {};

  NotificationService(this._apiClient);

  /// Get notifications list (`limit` + optional unread filter).
  Future<NotificationPage> getNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final cappedLimit = limit.clamp(1, 100);
    final queryParams = <String, dynamic>{'limit': cappedLimit};
    if (unreadOnly) {
      queryParams['unread'] = 'true';
    }

    final response = await _apiClient.get(
      ApiEndpoints.getNotifications,
      queryParameters: queryParams,
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final notificationsJson = data['notifications'] as List<dynamic>? ?? [];
      var notifications = notificationsJson
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
      notifications = await _attachActors(notifications);

      final unreadCount = data['unread_count'] as int? ??
          notifications.where((n) => !n.isRead).length;
      final total = data['total'] as int? ?? notifications.length;
      final hasMore = notifications.length >= cappedLimit && cappedLimit < 100;

      return NotificationPage(
        notifications: notifications,
        unreadCount: unreadCount,
        total: total,
        hasMore: hasMore,
      );
    }

    return const NotificationPage(
      notifications: [],
      unreadCount: 0,
      total: 0,
      hasMore: false,
    );
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

  /// Connect to SSE stream
  Stream<AppNotification> getNotificationStream() async* {
    final response = await _apiClient.dio.get<ResponseBody>(
      ApiEndpoints.getNotificationStream,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    yield* stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((data) => data.isNotEmpty)
        .map((data) {
      try {
        final Map<String, dynamic> json = jsonDecode(data) as Map<String, dynamic>;
        return AppNotification.fromJson(json);
      } catch (_) {
        return null;
      }
    }).where((notification) => notification != null).cast<AppNotification>();
  }

  Future<List<AppNotification>> _attachActors(
    List<AppNotification> notifications,
  ) async {
    final actorIds = notifications
        .map((n) => n.actorId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final missingIds = actorIds.where((id) => !_actorCache.containsKey(id));
    await Future.wait(missingIds.map(_fetchAndCacheUser));

    return notifications
        .map((n) => n.copyWith(actor: _actorCache[n.actorId]))
        .toList();
  }

  Future<void> _fetchAndCacheUser(String userId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.getUser(userId));
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final body = response.data as Map<String, dynamic>;
        final userJson =
            body['user'] as Map<String, dynamic>? ??
            body['data'] as Map<String, dynamic>? ??
            body;
        _actorCache[userId] = User.fromJson(userJson);
      }
    } catch (_) {
      // Ignore actor lookup failures; UI falls back to "Someone".
    }
  }
}
