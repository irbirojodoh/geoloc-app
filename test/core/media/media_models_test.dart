import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/media/media_content_type.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:geoloc_app/data/models/presigned_upload_url.dart';

void main() {
  group('MediaContentType', () {
    test('maps extensions to MIME types', () {
      expect(MediaContentType.forExtension('jpg'), 'image/jpeg');
      expect(MediaContentType.forExtension('png'), 'image/png');
      expect(MediaContentType.forExtension('webp'), 'image/webp');
    });

    test('extracts filename from path', () {
      expect(
        MediaContentType.filenameFromPath('/tmp/photo.jpg'),
        'photo.jpg',
      );
    });
  });

  group('PresignedUploadUrl', () {
    test('parses upload-url response', () {
      final result = PresignedUploadUrl.fromJson({
        'upload_url': 'https://abc.r2.cloudflarestorage.com/bucket/key.jpg?sig=1',
        'key': 'posts/user-1/uuid.jpg',
        'expires_at': '2026-06-27T13:00:00Z',
      });

      expect(result.key, 'posts/user-1/uuid.jpg');
      expect(result.uploadUrl, contains('r2.cloudflarestorage.com'));
    });
  });

  group('Post media keys', () {
    test('parses media_keys from API JSON', () {
      final post = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'media_keys': ['posts/u1/a.jpg', 'posts/u1/b.jpg'],
        'media_urls': ['https://abc.r2.cloudflarestorage.com/a.jpg'],
        'created_at': '2026-06-27T12:00:00Z',
      });

      expect(post.mediaKeys, hasLength(2));
      expect(post.mediaCount, 1);
      expect(post.mediaKeyAt(0), 'posts/u1/a.jpg');
    });

    test('toCacheJson omits presigned media_urls', () {
      final post = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'media_keys': ['posts/u1/a.jpg'],
        'media_urls': ['https://abc.r2.cloudflarestorage.com/a.jpg'],
        'created_at': '2026-06-27T12:00:00Z',
      });

      final cached = post.toCacheJson();
      expect(cached.containsKey('media_urls'), isFalse);
      expect(cached['media_keys'], ['posts/u1/a.jpg']);
    });

    test('mediaCount falls back to keys when urls absent', () {
      final post = Post.fromJson({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'hello',
        'media_keys': ['posts/u1/a.jpg'],
        'created_at': '2026-06-27T12:00:00Z',
      });

      expect(post.mediaCount, 1);
      expect(post.hasMedia, isTrue);
    });
  });
}
