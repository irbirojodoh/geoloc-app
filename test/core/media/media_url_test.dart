import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/media/media_url.dart';

void main() {
  group('MediaUrl', () {
    test('isPresignedR2Url detects R2 host', () {
      expect(
        MediaUrl.isPresignedR2Url(
          'https://abc123.r2.cloudflarestorage.com/geoloc-media/posts/u/uuid.jpg?X-Amz-Expires=900',
        ),
        isTrue,
      );
      expect(
        MediaUrl.isPresignedR2Url('https://images.unsplash.com/photo.jpg'),
        isFalse,
      );
    });

    test('parseKeyFromUrl extracts object key from R2 path', () {
      expect(
        MediaUrl.parseKeyFromUrl(
          'https://abc.r2.cloudflarestorage.com/geoloc-media/avatars/user-1/uuid.jpg?sig=1',
        ),
        'avatars/user-1/uuid.jpg',
      );
      expect(
        MediaUrl.parseKeyFromUrl(
          'https://abc.r2.cloudflarestorage.com/bucket/covers/user-2/cover.png',
        ),
        'covers/user-2/cover.png',
      );
      expect(
        MediaUrl.parseKeyFromUrl('https://example.com/avatars/x.jpg'),
        isNull,
      );
    });

    test('shouldAttachAuthHeader is always false for presigned media', () {
      expect(
        MediaUrl.shouldAttachAuthHeader(
          'https://abc.r2.cloudflarestorage.com/geoloc-media/posts/u/uuid.jpg',
        ),
        isFalse,
      );
    });
  });
}
