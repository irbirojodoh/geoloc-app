import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';

/// Account & privacy entry point — blocked/muted lists and account deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Scaffold(
      body: Column(
        children: [
          GeolocAppBar(
            title: 'Settings',
            leading: IconSquareButton(
              icon: Icons.arrow_back,
              semanticLabel: 'Back',
              onTap: () => context.pop(),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
          ListTile(
            title: Text('Blocked Users', style: context.bodyMedium),
            subtitle: Text(
              'Manage people you blocked.',
              style: context.caption,
            ),
            trailing: Icon(Icons.chevron_right, color: gold),
            onTap: () => context.push(RoutePaths.settingsBlocked),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text('Muted Users', style: context.bodyMedium),
            subtitle: Text(
              'Manage muted feeds.',
              style: context.caption,
            ),
            trailing: Icon(Icons.chevron_right, color: gold),
            onTap: () => context.push(RoutePaths.settingsMuted),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Text(
              'DANGER ZONE',
              style: context.sectionLabel.copyWith(color: AppColors.error),
            ),
          ),
          ListTile(
            title: Text(
              'Delete account',
              style: context.errorText,
            ),
            subtitle: Text(
              'Permanent. Your data will be anonymized.',
              style: context.caption,
            ),
            trailing: Icon(Icons.delete_forever_outlined, color: AppColors.error),
            onTap: () => _startDeleteFlow(context, ref),
          ),
        ],
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDeleteFlow(BuildContext context, WidgetRef ref) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final gold = AppColors.gold(ctx);
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          title: Text(
            'Delete your account?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            'This action is irreversible. All data will be anonymized.',
            style: context.postContent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('KEEP ACCOUNT', style: TextStyle(color: gold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'CONTINUE',
                style: TextStyle(color: AppColors.error),
              ),
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
          final ngold = AppColors.gold(nested);
          return AlertDialog(
            backgroundColor: ncs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            title: Text(
              'Contact support',
              style: context.textTheme.headlineSmall,
            ),
            content: Text(
              'OAuth accounts cannot be deleted via password from this app. '
              'Please contact Geoloc support so they can help you securely.',
              style: context.postContent,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(nested),
                child: Text('OK', style: TextStyle(color: ngold)),
              ),
            ],
          );
        },
      );
    } else {
      widget.rootMessenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      title: Text(
        'Confirm with password',
        style: context.textTheme.headlineSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pwd,
            autofocus: true,
            obscureText: _obscure,
            enabled: !_busy,
            style: context.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted(context),
                ),
                onPressed:
                    _busy ? null : () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: gold)),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: gold,
                  ),
                )
              : Text(
                  'DELETE',
                  style: const TextStyle(color: AppColors.error),
                ),
        ),
      ],
    );
  }
}
