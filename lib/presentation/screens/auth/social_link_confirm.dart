import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';

String _methodLabel(String method) {
  switch (method.toLowerCase()) {
    case 'google':
      return 'Google';
    case 'apple':
      return 'Apple';
    case 'password':
      return 'email and password';
    default:
      return method;
  }
}

/// Shows proceed/cancel when social sign-in hits an existing email.
/// Returns true if the user confirmed and auth succeeded.
Future<bool> handlePendingSocialLinkIfNeeded(
  BuildContext context,
  WidgetRef ref,
) async {
  final pending = ref.read(authStateProvider).pendingSocialLink;
  if (pending == null || !context.mounted) return false;

  final existing = pending.existingMethods.map(_methodLabel).join(', ');
  final attempting = _methodLabel(pending.attemptingMethod);

  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Email already in use'),
        content: Text(
          'You have used ${pending.email} for another sign-in method'
          '${existing.isNotEmpty ? ' ($existing)' : ''}. '
          'Proceed to link $attempting to that account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Proceed'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return false;

  if (proceed == true) {
    final success =
        await ref.read(authStateProvider.notifier).confirmPendingSocialLink();
    return success;
  }

  await ref.read(authStateProvider.notifier).cancelPendingSocialLink();
  return false;
}

/// Completes social sign-in including optional email-link confirmation, then routes.
Future<void> completeSocialSignInFlow({
  required BuildContext context,
  required WidgetRef ref,
  required Future<bool> Function() signIn,
}) async {
  final success = await signIn();
  if (!context.mounted) return;

  var authenticated = success;
  if (!authenticated &&
      ref.read(authStateProvider).pendingSocialLink != null) {
    authenticated = await handlePendingSocialLinkIfNeeded(context, ref);
  }

  if (!authenticated || !context.mounted) return;

  final authState = ref.read(authStateProvider);
  if (authState.isNewUser) {
    context.go(RoutePaths.editProfile);
  } else {
    context.go(RoutePaths.feed);
  }
}
