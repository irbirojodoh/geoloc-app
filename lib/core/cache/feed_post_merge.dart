import 'package:flutter/foundation.dart';

import '../../data/models/post.dart';
import '../../data/models/user.dart';

/// Merges feed/profile updates without rotating presigned URLs unnecessarily.
class FeedPostMerge {
  FeedPostMerge._();

  /// Merge a refreshed first page with existing posts, preserving display URLs.
  static List<Post> mergeFeedPage(List<Post> incoming, List<Post> existing) {
    if (existing.isEmpty) return incoming;

    final existingById = {for (final post in existing) post.id: post};
    return incoming
        .map((post) => mergePost(post, existingById[post.id]))
        .toList();
  }

  /// Merge paginated posts — only deduplicates, no URL preservation needed.
  static List<Post> appendUnique(List<Post> current, List<Post> incoming) {
    if (incoming.isEmpty) return current;
    final ids = current.map((post) => post.id).toSet();
    final merged = [...current];
    for (final post in incoming) {
      if (!ids.contains(post.id)) {
        merged.add(post);
        ids.add(post.id);
      }
    }
    return merged;
  }

  static Post mergePost(Post incoming, Post? existing) {
    if (existing == null) return incoming;

    var merged = incoming;

    // Location labels (`location_name`, `address`) stay on [incoming]. The
    // server re-geocodes cells after the 6-char precision change, so a
    // cached "Jakarta Pusat" must not win over a live street-level name.

    if (_shouldPreserveMediaUrls(incoming, existing)) {
      merged = merged.copyWith(mediaUrls: existing.mediaUrls);
    }

    if (incoming.author != null) {
      merged = merged.copyWith(
        author: mergeUser(incoming.author!, existing.author),
      );
    }

    return merged;
  }

  static User mergeUser(User incoming, User? existing) {
    if (existing == null) return incoming;

    var merged = incoming;

    if (_shouldPreserveAvatarUrl(incoming, existing)) {
      merged = merged.copyWith(profilePictureUrl: existing.profilePictureUrl);
    }

    if (_shouldPreserveCoverUrl(incoming, existing)) {
      merged = merged.copyWith(coverImageUrl: existing.coverImageUrl);
    }

    return merged;
  }

  static bool _shouldPreserveMediaUrls(Post incoming, Post existing) {
    if (existing.mediaUrls.isEmpty) return false;

    if (incoming.mediaKeys.isNotEmpty && existing.mediaKeys.isNotEmpty) {
      return listEquals(incoming.mediaKeys, existing.mediaKeys);
    }

    if (incoming.mediaKeys.isEmpty && existing.mediaKeys.isEmpty) {
      return incoming.mediaCount == existing.mediaCount &&
          incoming.mediaCount > 0;
    }

    return listEquals(incoming.mediaKeys, existing.mediaKeys);
  }

  static bool _shouldPreserveAvatarUrl(User incoming, User existing) {
    if (existing.profilePictureUrl == null ||
        existing.profilePictureUrl!.trim().isEmpty) {
      return false;
    }

    if (incoming.avatarKey != null && existing.avatarKey != null) {
      return incoming.avatarKey == existing.avatarKey;
    }

    return incoming.id == existing.id &&
        incoming.profilePictureUrl != null &&
        incoming.profilePictureUrl!.trim().isNotEmpty;
  }

  static bool _shouldPreserveCoverUrl(User incoming, User existing) {
    if (existing.coverImageUrl == null ||
        existing.coverImageUrl!.trim().isEmpty) {
      return false;
    }

    if (incoming.coverKey != null && existing.coverKey != null) {
      return incoming.coverKey == existing.coverKey;
    }

    return incoming.id == existing.id &&
        incoming.coverImageUrl != null &&
        incoming.coverImageUrl!.trim().isNotEmpty;
  }
}
