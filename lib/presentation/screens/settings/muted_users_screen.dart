import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../services/moderation_service.dart';
import '../../providers/moderation_lists_provider.dart';
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/user_avatar.dart';

class MutedUsersScreen extends ConsumerWidget {
  const MutedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(mutedUsersListProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          GeolocAppBar(
            title: 'Muted Users',
            leading: IconSquareButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.gold(context),
              onRefresh: () async {
                ref.invalidate(mutedUsersListProvider);
                await Future<void>.delayed(const Duration(milliseconds: 150));
                await ref.read(mutedUsersListProvider.future);
              },
              child: muted.when(
                data: (users) {
                  if (users.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        Icon(
                          Icons.volume_off_outlined,
                          size: 48,
                          color: AppColors.textMuted(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No muted users.',
                          style: context.bodyMedium,
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (context, _) =>
                        Divider(height: 1, thickness: 0.5, color: cs.outline),
                    itemBuilder: (ctx, index) {
                      final u = users[index];
                      return ListTile(
                        leading: UserAvatar(
                          imageUrl: u.profilePictureUrl,
                          name: u.username,
                          size: 40,
                        ),
                        title: Text(
                          '@${u.username}',
                          style: context.username,
                        ),
                        subtitle: Text(
                          u.fullName ?? '',
                          style: context.caption,
                        ),
                        trailing: TextButton(
                          onPressed: () => _confirmUnmute(context, ref, u.id),
                          child: Text(
                            'Unmute',
                            style: TextStyle(color: AppColors.gold(context)),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$e',
                          style: context.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(mutedUsersListProvider),
                          child: Text(
                            'Retry',
                            style: TextStyle(color: AppColors.gold(context)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmUnmute(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        title:
            Text('Unmute?', style: context.textTheme.headlineSmall),
        content: Text(
          'Their posts may show in your Nearby feed again.',
          style: context.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: gold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Unmute', style: TextStyle(color: gold)),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) return;

    try {
      await ref.read(moderationServiceProvider).unmuteUser(userId);
      ref.invalidate(mutedUsersListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unmuted.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not unmute user.')),
        );
      }
    }
  }
}
