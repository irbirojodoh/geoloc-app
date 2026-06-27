import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:geoloc_app/services/feed_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    Hive.init('./.dart_tool/test_hive');
    await Hive.deleteBoxFromDisk('feed_cache');
  });

  tearDown(() async {
    await Hive.close();
  });

  test('FeedCacheService stores posts without presigned URLs', () async {
    final service = FeedCacheService();
    final post = Post.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'content': 'cached post',
      'media_keys': ['posts/u1/a.jpg'],
      'media_urls': ['https://abc.r2.cloudflarestorage.com/a.jpg?sig=1'],
      'created_at': '2026-06-27T12:00:00Z',
    });

    await service.saveFeed(
      posts: [post],
      latitude: -6.2,
      longitude: 106.8,
      radiusKm: 5,
      hasMore: false,
    );

    final loaded = await service.loadFeed();
    expect(loaded, isNotNull);
    expect(loaded!.posts, hasLength(1));
    expect(loaded.posts.first.mediaKeys, ['posts/u1/a.jpg']);
    expect(loaded.posts.first.mediaUrls, isEmpty);
    expect(loaded.posts.first.content, 'cached post');
  });
}
