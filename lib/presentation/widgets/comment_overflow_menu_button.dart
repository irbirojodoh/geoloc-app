import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_extensions.dart';

import '../../data/models/comment.dart';
import '../../services/moderation_service.dart';
import '../helpers/content_purge.dart';
import '../providers/auth_provider.dart';
import 'report_content_sheet.dart';

/// 3-dot menu for comments: Report / Block / Mute when not the current user.
class CommentOverflowMenuButton extends ConsumerWidget {
  final Comment comment;
  final String postId;

  const CommentOverflowMenuButton({
    super.key,
    required this.comment,
    required this.postId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null ||
        comment.userId == me.id ||
        comment.isSoftDeleted) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 18,
        color: cs.onSurfaceVariant,
      ),
      padding: EdgeInsets.zero,
      elevation: 4,
      surfaceTintColor: Colors.transparent,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
      ),
      onSelected: (value) async {
        if (!context.mounted) return;
        switch (value) {
          case 'report':
            final ok = await showReportContentSheet(
              context: context,
              ref: ref,
              targetType: 'comment',
              targetId: comment.id,
            );
            if (context.mounted && ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thanks — we received your report.'),
                ),
              );
            }
            break;
          case 'block':
            await _block(context, ref);
            break;
          case 'mute':
            await _mute(context, ref);
            break;
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: 20,
                color: cs.onSurface,
              ),
              const SizedBox(width: 12),
              Text('Report', style: context.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: Row(
            children: [
              Icon(
                Icons.block_outlined,
                size: 20,
                color: cs.onSurface,
              ),
              const SizedBox(width: 12),
              Text('Block', style: context.bodyMedium),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(
                Icons.volume_off_outlined,
                size: 20,
                color: cs.onSurface,
              ),
              const SizedBox(width: 12),
              Text('Mute', style: context.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
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
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Block',
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).blockUser(comment.userId);
      purgeUserFromLocalFeeds(
        ref,
        comment.userId,
        openPostDetailId: postId,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block user.')),
        );
      }
    }
  }

  Future<void> _mute(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
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
              child: Text(
                'Cancel',
                style: TextStyle(color: cs.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Mute',
                style: TextStyle(color: cs.primary),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).muteUser(comment.userId);
      purgeUserFromLocalFeeds(
        ref,
        comment.userId,
        openPostDetailId: postId,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mute user.')),
        );
      }
    }
  }
}
