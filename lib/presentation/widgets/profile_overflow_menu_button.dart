import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';

import '../../services/moderation_service.dart';
import '../helpers/content_purge.dart';
import '../providers/auth_provider.dart';
import 'report_content_sheet.dart';

/// App-bar style overflow for another user's profile header.
class ProfileOverflowMenuButton extends ConsumerWidget {
  final String profileUserId;

  const ProfileOverflowMenuButton({
    super.key,
    required this.profileUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    if (me == null || me.id == profileUserId) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.scrim.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          size: 20,
          color: cs.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: cs.outline),
        ),
        onSelected: (value) async {
          if (!context.mounted) return;
          switch (value) {
            case 'report':
              final ok = await showReportContentSheet(
                context: context,
                ref: ref,
                targetType: 'user',
                targetId: profileUserId,
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
        ],
      ),
    );
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
      await ref.read(moderationServiceProvider).blockUser(profileUserId);
      purgeUserFromLocalFeeds(ref, profileUserId);
      if (context.mounted) context.pop();
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
      await ref.read(moderationServiceProvider).muteUser(profileUserId);
      purgeUserFromLocalFeeds(ref, profileUserId);
      if (context.mounted) context.pop();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mute user.')),
        );
      }
    }
  }
}
