import 'package:geoloc_app/data/models/location_follow.dart';
import 'package:geoloc_app/services/location_follow_service.dart';

class FakeLocationFollowApi implements LocationFollowApi {
  List<LocationFollow> following = [];
  final List<String> unfollowedPrefixes = [];
  int getFollowingCalls = 0;
  Object? getFollowingThrow;
  Object? unfollowThrow;

  @override
  Future<List<LocationFollow>> getFollowing() async {
    getFollowingCalls++;
    final error = getFollowingThrow;
    if (error != null) throw error;
    return List<LocationFollow>.from(following);
  }

  @override
  Future<LocationFollow> follow({
    required double latitude,
    required double longitude,
    String? name,
  }) async {
    final created = LocationFollow(
      geohashPrefix: 'qqggyn',
      name: name,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.utc(2026, 8, 29),
    );
    following = [created, ...following];
    return created;
  }

  @override
  Future<void> unfollow(String geohashPrefix) async {
    final error = unfollowThrow;
    if (error != null) throw error;
    unfollowedPrefixes.add(geohashPrefix);
    following = following
        .where((item) => item.geohashPrefix != geohashPrefix)
        .toList();
  }
}
