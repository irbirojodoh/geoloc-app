import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feed_provider.dart';
import '../providers/post_detail_provider.dart';
import '../providers/profile_provider.dart';

/// After a successful block or mute (from the client's perspective): strip that
/// user's posts from current feed/grid state and prune their comments locally.
void purgeUserFromLocalFeeds(
  WidgetRef ref,
  String otherUserId, {
  String? openPostDetailId,
}) {
  ref.read(feedStateProvider.notifier).removePostsByAuthor(otherUserId);
  ref.invalidate(profileProvider(otherUserId));
  final postId = openPostDetailId;
  if (postId != null) {
    ref
        .read(postDetailProvider(postId).notifier)
        .removeCommentsByAuthor(otherUserId);
  }
}
