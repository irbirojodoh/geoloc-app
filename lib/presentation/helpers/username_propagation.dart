import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/post_detail_provider.dart';
import '../providers/post_preview_cache.dart';
import '../providers/profile_provider.dart';

/// After a successful username change, update every in-memory cache that was
/// hydrated with the old handle (current user, profile header, posts, comments).
///
/// Search/autocomplete may still show the old handle for a few seconds while
/// the server reindexes — that is expected, not a client bug.
Future<void> propagateUsernameChange(
  WidgetRef ref,
  String userId,
  String newUsername,
) async {
  await ref.read(authStateProvider.notifier).applyUsername(newUsername);

  ref.read(feedStateProvider.notifier).rewriteAuthorUsername(userId, newUsername);
  ref
      .read(postPreviewCacheProvider.notifier)
      .rewriteAuthorUsername(userId, newUsername);

  if (ref.exists(profileProvider(userId))) {
    ref
        .read(profileProvider(userId).notifier)
        .rewriteAuthorUsername(newUsername);
  }

  final postIds = <String>{
    ...ref.read(feedStateProvider).posts.map((p) => p.id),
    ...ref.read(postPreviewCacheProvider).keys,
  };
  for (final postId in postIds) {
    if (ref.exists(postDetailProvider(postId))) {
      ref
          .read(postDetailProvider(postId).notifier)
          .rewriteAuthorUsername(userId, newUsername);
    }
  }
}
