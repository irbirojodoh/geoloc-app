import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/config/push_navigation.dart';
import 'package:geoloc_app/config/routes.dart';

void main() {
  group('routeFromPushData', () {
    test('maps post notifications to post detail', () {
      expect(
        routeFromPushData({
          'type': 'like',
          'target_type': 'post',
          'target_id': 'p1',
        }),
        '/post/p1',
      );
    });

    test('maps DM payloads to chat path', () {
      expect(
        routeFromPushData({
          'type': 'dm',
          'conversation_id': 'c1',
          'peer_user_id': 'u2',
        }),
        RoutePaths.chatPath('c1', 'u2'),
      );
    });

    test('maps follow to actor profile', () {
      expect(
        routeFromPushData({
          'type': 'follow',
          'actor_id': 'u9',
        }),
        '/profile/u9',
      );
    });

    test('falls back to notifications', () {
      expect(routeFromPushData(const {}), RoutePaths.notifications);
    });
  });
}
