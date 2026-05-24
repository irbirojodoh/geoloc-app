import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../services/moderation_service.dart';
import '../../providers/moderation_lists_provider.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/top_bar_backdrop.dart';
import '../../widgets/user_avatar.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersListProvider);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: cs.primary,
        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.96),
        strokeWidth: 2.2,
        elevation: 1,
        edgeOffset: 86,
        displacement: 28,
        onRefresh: () async {
          ref.invalidate(blockedUsersListProvider);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          await ref.read(blockedUsersListProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              centerTitle: false,
              titleSpacing: 16,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              flexibleSpace: TopBarBackdrop(
                blurTintColor: cs.surface,
                blendColor: cs.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(
                'Blocked users',
                style: textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            blocked.when(
              data: (users) {
                if (users.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.block_outlined,
                      title: 'No blocked users',
                      message: 'People you block will appear here.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                  sliver: SliverList.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final u = users[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                            child: Row(
                              children: [
                                UserAvatar(
                                  imageUrl: u.profilePictureUrl,
                                  name: u.username,
                                  size: 44,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '@${u.username}',
                                        style: textTheme.titleSmall?.copyWith(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (u.fullName != null &&
                                          u.fullName!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          u.fullName!.trim(),
                                          style: textTheme.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _confirmUnblock(context, ref, u.id),
                                  child: const Text('Unblock'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.primary,
                  ),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(blockedUsersListProvider),
                  retryLabel: 'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnblock(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Unblock user?', style: context.textTheme.headlineSmall),
        content: Text(
          'Their posts may appear again in feeds you browse.',
          style: context.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: cs.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unblock', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).unblockUser(userId);
      ref.invalidate(blockedUsersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unblock user.')),
        );
      }
    }
  }
}
