import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/post.dart';
import '../../services/moderation_service.dart';
import '../helpers/content_purge.dart';
import '../providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import 'report_content_sheet.dart';

/// 3-dot menu for posts: delete when author; Report / Block / Mute otherwise.
class PostOverflowMenuButton extends ConsumerWidget {
  final Post post;

  /// When non-null (post detail), deleting or blocking author may pop the route.
  final String? viewingPostDetailId;

  const PostOverflowMenuButton({
    super.key,
    required this.post,
    this.viewingPostDetailId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isMine = post.userId == me.id;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 20,
        color: AppColors.textMuted(context),
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: cs.outline),
      ),
      onSelected: (value) async {
        if (!context.mounted) return;
        switch (value) {
          case 'delete':
            await _handleDelete(context, ref);
            break;
          case 'report':
            await _handleReport(context, ref);
            break;
          case 'block':
            await _handleBlock(context, ref);
            break;
          case 'mute':
            await _handleMute(context, ref);
            break;
        }
      },
      itemBuilder: (ctx) {
        if (isMine) {
          return [
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete Post',
                style: context.bodyMedium,
              ),
            ),
          ];
        }
        return [
          PopupMenuItem(
            value: 'report',
            child: Text('Report', style: context.bodyMedium),
          ),
          PopupMenuItem(
            value: 'block',
            child: Text('Block', style: context.bodyMedium),
          ),
          PopupMenuItem(
            value: 'mute',
            child: Text('Mute', style: context.bodyMedium),
          ),
        ];
      },
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gold = AppColors.gold(ctx);
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          title: Text(
            'Delete post?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'This cannot be undone.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(moderationServiceProvider).deletePost(post.id);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete post.')),
      );
      return;
    }
    ref.read(feedStateProvider.notifier).removePost(post.id);
    final detailId = viewingPostDetailId;
    if (detailId != null &&
        detailId == post.id &&
        Navigator.of(context).canPop()) {
      context.pop();
    }
  }

  Future<void> _handleReport(BuildContext context, WidgetRef ref) async {
    final ok = await showReportContentSheet(
      context: context,
      ref: ref,
      targetType: 'post',
      targetId: post.id,
    );
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — we received your report.')),
      );
    }
  }

  Future<void> _handleBlock(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gold = AppColors.gold(ctx);
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          title: Text(
            'Block this user?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'You will no longer see their posts, and they won\'t see yours.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Block',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).blockUser(post.userId);
      purgeUserFromLocalFeeds(
        ref,
        post.userId,
        openPostDetailId: viewingPostDetailId,
      );
      if (context.mounted &&
          viewingPostDetailId != null &&
          viewingPostDetailId == post.id) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block user.')),
        );
      }
    }
  }

  Future<void> _handleMute(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gold = AppColors.gold(ctx);
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          title: Text(
            'Mute this user?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'You won\'t see their posts in your feed.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Mute', style: TextStyle(color: gold)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).muteUser(post.userId);
      purgeUserFromLocalFeeds(
        ref,
        post.userId,
        openPostDetailId: viewingPostDetailId,
      );
      if (context.mounted &&
          viewingPostDetailId != null &&
          viewingPostDetailId == post.id) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mute user.')),
        );
      }
    }
  }
}
