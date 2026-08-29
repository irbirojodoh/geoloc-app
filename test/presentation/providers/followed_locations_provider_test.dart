import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/location_follow.dart';
import 'package:geoloc_app/presentation/providers/followed_locations_provider.dart';

import '../../helpers/fake_location_follow_api.dart';

LocationFollow _follow({
  required String prefix,
  String name = 'Menteng',
}) {
  return LocationFollow(
    geohashPrefix: prefix,
    name: name,
    latitude: -6.195,
    longitude: 106.837,
    createdAt: DateTime.utc(2026, 8, 1),
  );
}

void main() {
  group('FollowedLocationsNotifier.unfollow', () {
    test('sends the 6-char prefix from a freshly fetched list', () async {
      final api = FakeLocationFollowApi()
        ..following = [_follow(prefix: 'qqggyn')];
      final notifier = FollowedLocationsNotifier(api);

      await notifier.refresh();
      expect(api.getFollowingCalls, 1);
      expect(notifier.state.locations.single.geohashPrefix, 'qqggyn');

      final ok = await notifier.unfollow('qqggyn');

      expect(ok, isTrue);
      expect(api.unfollowedPrefixes, ['qqggyn']);
      expect(api.unfollowedPrefixes.single.length, 6);
      expect(notifier.state.locations, isEmpty);
    });

    test('refetches before unfollow when the in-memory list is cold', () async {
      final api = FakeLocationFollowApi()
        ..following = [_follow(prefix: 'qqggyn')];
      final notifier = FollowedLocationsNotifier(api);

      final ok = await notifier.unfollow('qqggyn');

      expect(ok, isTrue);
      expect(api.getFollowingCalls, 1);
      expect(api.unfollowedPrefixes, ['qqggyn']);
    });

    test('does not DELETE a stale 5-char prefix missing from GET', () async {
      final api = FakeLocationFollowApi()
        ..following = [_follow(prefix: 'qqggyn')];
      final notifier = FollowedLocationsNotifier(api);

      await notifier.refresh();
      final ok = await notifier.unfollow('qqggy');

      expect(ok, isFalse);
      expect(api.getFollowingCalls, 2);
      expect(api.unfollowedPrefixes, isEmpty);
      expect(notifier.state.locations.single.geohashPrefix, 'qqggyn');
    });

    test('never client-computes a prefix — only exact server matches', () async {
      final api = FakeLocationFollowApi()
        ..following = [_follow(prefix: 'qqggyn')];
      final notifier = FollowedLocationsNotifier(api);
      await notifier.refresh();

      expect(notifier.state.isFollowedPrefix('qqggy'), isFalse);
      expect(notifier.state.isFollowedPrefix('qqggyn'), isTrue);
      expect(notifier.state.isFollowedPrefix('qqggynp'), isFalse);
    });
  });
}
