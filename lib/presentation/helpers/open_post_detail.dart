import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/post.dart';
import '../providers/feed_provider.dart';
import '../providers/post_preview_cache.dart';

/// Opens post detail using list data already on screen — no loading flash.
Future<T?> openPostDetail<T>(
  BuildContext context,
  WidgetRef ref,
  Post post,
) {
  ref.read(postPreviewCacheProvider.notifier).seed(post);
  return context.push<T>('/post/${post.id}');
}

/// Opens post detail by id when no [Post] is available (e.g. notifications).
Future<T?> openPostDetailById<T>(
  BuildContext context,
  WidgetRef ref,
  String postId,
) {
  Post? known = ref.read(postPreviewCacheProvider)[postId];
  if (known == null) {
    for (final post in ref.read(feedStateProvider).posts) {
      if (post.id == postId) {
        known = post;
        break;
      }
    }
  }
  if (known != null) {
    ref.read(postPreviewCacheProvider.notifier).seed(known);
  }
  return context.push<T>('/post/$postId');
}
