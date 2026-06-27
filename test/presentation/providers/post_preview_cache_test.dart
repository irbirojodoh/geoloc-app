import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/post.dart';
import 'package:geoloc_app/presentation/providers/post_preview_cache.dart';

Post _post(String id) => Post.fromJson({
      'id': id,
      'user_id': 'u1',
      'content': 'hello',
      'created_at': '2026-06-27T12:00:00Z',
    });

void main() {
  test('resolvePostPreview prefers preview cache', () {
    final post = _post('p1');

    expect(
      resolvePostPreview(
        postId: 'p1',
        previewCache: {'p1': post},
        feedPosts: const [],
      ),
      post,
    );
  });

  test('resolvePostPreview falls back to feed posts', () {
    final post = _post('p2');

    expect(
      resolvePostPreview(
        postId: 'p2',
        previewCache: const {},
        feedPosts: [post],
      ),
      post,
    );
  });
}
