import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/post.dart';

void main() {
  group('Post location_verified', () {
    Map<String, dynamic> baseJson({Object? locationVerified}) {
      final json = <String, dynamic>{
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'created_at': '2026-06-27T12:00:00Z',
      };
      if (locationVerified != null) {
        json['location_verified'] = locationVerified;
      }
      return json;
    }

    test('parses true from JSON', () {
      final post = Post.fromJson(baseJson(locationVerified: true));
      expect(post.locationVerified, isTrue);
    });

    test('parses false from JSON', () {
      final post = Post.fromJson(baseJson(locationVerified: false));
      expect(post.locationVerified, isFalse);
    });

    test('defaults to false when the key is omitted', () {
      final post = Post.fromJson(baseJson());
      expect(post.locationVerified, isFalse);
    });

    test('round-trips through toJson', () {
      final original = Post.fromJson(baseJson(locationVerified: true));
      final restored = Post.fromJson(original.toJson());
      expect(restored.locationVerified, isTrue);
      expect(restored.toJson()['location_verified'], isTrue);
    });

    test('copyWith updates locationVerified', () {
      final post = Post.fromJson(baseJson());
      expect(post.copyWith(locationVerified: true).locationVerified, isTrue);
    });

    test('parses 1/0 and is_location_verified', () {
      expect(
        Post.fromJson(baseJson(locationVerified: 1)).locationVerified,
        isTrue,
      );
      expect(
        Post.fromJson(baseJson(locationVerified: 0)).locationVerified,
        isFalse,
      );
      final post = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'created_at': '2026-06-27T12:00:00Z',
        'is_location_verified': true,
      });
      expect(post.locationVerified, isTrue);
    });
  });

  group('Post cache location labels', () {
    test('toCacheJson omits location_name and address', () {
      final post = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'location_name': 'Jakarta Pusat',
        'address': {'city': 'Jakarta'},
        'created_at': '2026-06-27T12:00:00Z',
      });
      final cached = post.toCacheJson();
      expect(cached.containsKey('location_name'), isFalse);
      expect(cached.containsKey('address'), isFalse);
    });

    test('fromCacheJson drops persisted location labels', () {
      final post = Post.fromCacheJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'location_name': 'Jakarta Pusat',
        'address': {'city': 'Jakarta'},
        'created_at': '2026-06-27T12:00:00Z',
      });
      expect(post.locationName, isNull);
      expect(post.address, isNull);
    });
  });
}
