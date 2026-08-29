import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/post.dart';
import '../../core/utils/username_rewrite.dart';
import 'feed_provider.dart';

/// In-memory cache of posts the user has already seen in list screens.
final postPreviewCacheProvider =
    NotifierProvider<PostPreviewCacheNotifier, Map<String, Post>>(
  PostPreviewCacheNotifier.new,
);

class PostPreviewCacheNotifier extends Notifier<Map<String, Post>> {
  @override
  Map<String, Post> build() => {};

  void seed(Post post) {
    state = {...state, post.id: post};
  }

  Post? get(String postId) => state[postId];

  void rewriteAuthorUsername(String userId, String newUsername) {
    if (state.isEmpty) return;
    state = {
      for (final entry in state.entries)
        entry.key: rewritePostAuthorUsername(entry.value, userId, newUsername),
    };
  }
}

/// Pure lookup used by post detail and tests.
Post? resolvePostPreview({
  required String postId,
  required Map<String, Post> previewCache,
  required List<Post> feedPosts,
}) {
  final cached = previewCache[postId];
  if (cached != null) return cached;

  for (final post in feedPosts) {
    if (post.id == postId) return post;
  }

  return null;
}

/// Resolve a post for the detail screen from cache or the loaded feed.
Post? findPostForDetail(Ref ref, String postId) {
  return resolvePostPreview(
    postId: postId,
    previewCache: ref.read(postPreviewCacheProvider),
    feedPosts: ref.read(feedStateProvider).posts,
  );
}
