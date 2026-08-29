import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/dm_backup_dialogs.dart';
import '../../widgets/top_bar_backdrop.dart';

/// Account & privacy entry point — blocked/muted lists, logout, and account deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            title: Text(
              'Account & privacy',
              style: textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: _SettingsNavRow(
                    icon: Icons.alternate_email,
                    title: 'Username',
                    subtitle: currentUser != null
                        ? '@${currentUser.username}'
                        : 'Change your username',
                    onTap: () => context.push(RoutePaths.settingsUsername),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _SettingsNavRow(
                        icon: Icons.block_outlined,
                        title: 'Blocked users',
                        subtitle: 'Manage people you blocked',
                        onTap: () => context.push(RoutePaths.settingsBlocked),
                      ),
                      Divider(height: 1, color: cs.outlineVariant),
                      _SettingsNavRow(
                        icon: Icons.backup_outlined,
                        title: 'Message backup',
                        subtitle: 'Restore encrypted messages on new devices',
                        onTap: () => showDmCreateBackupDialog(context, ref),
                      ),
                      Divider(height: 1, color: cs.outlineVariant),
                      _SettingsNavRow(
                        icon: Icons.volume_off_outlined,
                        title: 'Muted users',
                        subtitle: 'Manage muted feeds',
                        onTap: () => context.push(RoutePaths.settingsMuted),
                      ),
                      Divider(height: 1, color: cs.outlineVariant),
                      _SettingsNavRow(
                        icon: Icons.logout,
                        title: 'Log out',
                        subtitle: 'Sign out of this device',
                        onTap: () => _confirmLogout(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Danger zone',
                    style: textTheme.labelLarge?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: cs.error.withValues(alpha: 0.35)),
                  ),
                  child: _SettingsNavRow(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete account',
                    subtitle: 'Permanent. Your data will be anonymized.',
                    titleColor: cs.error,
                    iconColor: cs.error,
                    onTap: () => _startDeleteFlow(context, ref),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            'Log out?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'You will need to sign in again to use Geoloc on this device.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Log out', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );

    if (proceed != true || !context.mounted) return;
    await ref.read(authStateProvider.notifier).logout();
  }

  Future<void> _startDeleteFlow(BuildContext context, WidgetRef ref) async {
    final cs = Theme.of(context).colorScheme;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            'Delete your account?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'This action is irreversible. All data will be anonymized.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep account', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continue', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );

    if (proceed != true || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => _DeleteAccountPasswordDialog(
        notifier: ref.read(authStateProvider.notifier),
        rootMessenger: ScaffoldMessenger.maybeOf(context),
      ),
    );
  }
}

class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? titleColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      color: titleColor ?? cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog({
    required this.notifier,
    required this.rootMessenger,
  });

  final AuthNotifier notifier;
  final ScaffoldMessengerState? rootMessenger;

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final TextEditingController _pwd = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final password = _pwd.text.trim();
    if (password.isEmpty) return;

    setState(() => _busy = true);

    final message =
        await widget.notifier.deleteAccountWithPassword(password);

    if (!mounted) return;

    Navigator.of(context).pop();

    if (!context.mounted) return;

    if (message == null) {
      widget.rootMessenger?.showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
      return;
    }

    final oauthDelete =
        message.contains('OAuth accounts cannot be deleted via password');
    if (oauthDelete) {
      await showDialog<void>(
        context: context,
        builder: (nested) {
          final ncs = Theme.of(nested).colorScheme;
          return AlertDialog(
            backgroundColor: ncs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Text(
              'Contact support',
              style: context.textTheme.headlineSmall,
            ),
            content: Text(
              'OAuth accounts cannot be deleted via password from this app. '
              'Please contact Geoloc support so they can help you securely.',
              style: context.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(nested),
                child: Text('OK', style: TextStyle(color: ncs.primary)),
              ),
            ],
          );
        },
      );
    } else {
      widget.rootMessenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  InputDecoration _passwordDecoration(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      labelText: 'Current password',
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: cs.onSurfaceVariant,
        ),
        onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        'Confirm with password',
        style: context.textTheme.headlineSmall,
      ),
      content: TextField(
        controller: _pwd,
        autofocus: true,
        obscureText: _obscure,
        enabled: !_busy,
        style: context.bodyMedium,
        decoration: _passwordDecoration(context),
        onSubmitted: (_) {
          if (!_busy) _submit();
        },
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: cs.primary)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: cs.error,
                  ),
                )
              : Text('Delete', style: TextStyle(color: cs.error)),
        ),
      ],
    );
  }
}
