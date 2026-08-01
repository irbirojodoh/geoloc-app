import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Maps FCM / notification `data` payloads to an in-app route.
///
/// Expected keys (any subset):
/// - `type` / `notification_type`: like | comment | follow | location_post | dm | message
/// - `target_type`: post | comment | user
/// - `target_id` / `post_id`
/// - `actor_id` / `user_id`
/// - `conversation_id` + `peer_user_id` (DM)
String? routeFromPushData(Map<String, dynamic> data) {
  String? str(String key) {
    final v = data[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  final type = (str('type') ?? str('notification_type') ?? '').toLowerCase();
  final targetType =
      (str('target_type') ?? str('targetType') ?? '').toLowerCase();
  final targetId = str('target_id') ?? str('targetId') ?? str('post_id');
  final actorId = str('actor_id') ?? str('actorId') ?? str('user_id');
  final conversationId =
      str('conversation_id') ?? str('conversationId');
  final peerUserId = str('peer_user_id') ?? str('peerUserId');

  if (type == 'dm' || type == 'message' || conversationId != null) {
    if (conversationId != null && peerUserId != null) {
      return RoutePaths.chatPath(conversationId, peerUserId);
    }
    return RoutePaths.messages;
  }

  if (targetType == 'post' ||
      type == 'like' ||
      type == 'comment' ||
      type == 'location_post') {
    if (targetId != null) return '/post/$targetId';
  }

  if (targetType == 'user' || type == 'follow') {
    if (actorId != null) return '/profile/$actorId';
    if (targetId != null) return '/profile/$targetId';
  }

  if (targetId != null &&
      (targetType == 'comment' || type == 'comment')) {
    // Comment notifications without a post id fall back to actor profile.
    if (actorId != null) return '/profile/$actorId';
  }

  if (actorId != null) return '/profile/$actorId';
  return RoutePaths.notifications;
}

/// Navigates using [routeFromPushData]. No-op when payload is empty/unknown.
void navigateFromPushData(Map<String, dynamic> data, GoRouter router) {
  final route = routeFromPushData(data);
  if (route == null) return;
  router.go(route);
}
