import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/cache/feed_post_merge.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:geoloc_app/data/models/user.dart';

void main() {
  group('FeedPostMerge', () {
    test('preserves media URLs when keys are unchanged', () {
      const existingUrl = 'https://abc.r2.cloudflarestorage.com/old.jpg?sig=1';
      const incomingUrl = 'https://abc.r2.cloudflarestorage.com/new.jpg?sig=2';

      final existing = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'media_keys': ['posts/u1/a.jpg'],
        'media_urls': [existingUrl],
        'created_at': '2026-06-27T12:00:00Z',
      });

      final incoming = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello updated',
        'media_keys': ['posts/u1/a.jpg'],
        'media_urls': [incomingUrl],
        'created_at': '2026-06-27T12:00:00Z',
      });

      final merged = FeedPostMerge.mergePost(incoming, existing);

      expect(merged.content, 'hello updated');
      expect(merged.mediaUrls, [existingUrl]);
    });

    test('preserves avatar URL when avatar key is unchanged', () {
      const existingAvatar = 'https://abc.r2.cloudflarestorage.com/av.jpg?sig=1';
      const incomingAvatar = 'https://abc.r2.cloudflarestorage.com/av.jpg?sig=2';

      final existing = User(
        id: 'u1',
        username: 'alice',
        email: 'a@test.com',
        avatarKey: 'avatars/u1/a.jpg',
        profilePictureUrl: existingAvatar,
      );
      final incoming = User(
        id: 'u1',
        username: 'alice',
        email: 'a@test.com',
        avatarKey: 'avatars/u1/a.jpg',
        profilePictureUrl: incomingAvatar,
        bio: 'updated bio',
      );

      final merged = FeedPostMerge.mergeUser(incoming, existing);

      expect(merged.bio, 'updated bio');
      expect(merged.profilePictureUrl, existingAvatar);
    });

    test('mergeFeedPage applies per-post merge', () {
      final existing = [
        Post.fromJson({
          'id': 'p1',
          'user_id': 'u1',
          'content': 'one',
          'media_urls': ['https://abc.r2.cloudflarestorage.com/1.jpg?sig=1'],
          'created_at': '2026-06-27T12:00:00Z',
        }),
      ];

      final incoming = [
        Post.fromJson({
          'id': 'p1',
          'user_id': 'u1',
          'content': 'one updated',
          'media_urls': ['https://abc.r2.cloudflarestorage.com/1.jpg?sig=2'],
          'created_at': '2026-06-27T12:00:00Z',
        }),
        Post.fromJson({
          'id': 'p2',
          'user_id': 'u1',
          'content': 'two',
          'created_at': '2026-06-27T12:01:00Z',
        }),
      ];

      final merged = FeedPostMerge.mergeFeedPage(incoming, existing);

      expect(merged, hasLength(2));
      expect(merged.first.mediaUrls.first, contains('sig=1'));
      expect(merged.last.id, 'p2');
    });
  });
}
