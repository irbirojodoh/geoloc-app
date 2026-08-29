import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/services/location_follow_service.dart';

void main() {
  test('parseFollowingResponse keeps server geohash_prefix verbatim', () {
    final list = LocationFollowService.parseFollowingResponse({
      'locations': [
        {
          'geohash_prefix': 'qqggyn',
          'name': 'Menteng',
          'latitude': -6.195,
          'longitude': 106.837,
          'created_at': '2026-08-29T00:00:00Z',
        },
      ],
      'count': 1,
    });

    expect(list, hasLength(1));
    expect(list.single.geohashPrefix, 'qqggyn');
    expect(list.single.geohashPrefix.length, 6);
  });
}
