import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/dm_exception.dart';
import '../providers/dm_provider.dart';

Future<void> showDmRestoreDialog(BuildContext context, WidgetRef ref) async {
  final passphraseController = TextEditingController();
  var obscure = true;
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            title: const Text('Restore message key'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enter the backup passphrase from your other device to '
                  'decrypt messages here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseController,
                  obscureText: obscure,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Backup passphrase',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: busy
                          ? null
                          : () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final passphrase = passphraseController.text.trim();
                        if (passphrase.isEmpty) return;
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(dmInboxProvider.notifier)
                              .restoreFromBackup(passphrase);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } on DmException catch (e) {
                          setState(() {
                            busy = false;
                            error = e.message;
                          });
                        } on FormatException {
                          setState(() {
                            busy = false;
                            error = 'Wrong passphrase or corrupted backup';
                          });
                        } catch (e) {
                          setState(() {
                            busy = false;
                            error = '$e';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore'),
              ),
            ],
          );
        },
      );
    },
  );
  passphraseController.dispose();
}

Future<void> showDmCreateBackupDialog(BuildContext context, WidgetRef ref) async {
  final passphraseController = TextEditingController();
  final confirmController = TextEditingController();
  var obscure = true;
  var busy = false;
  String? error;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            title: const Text('Message backup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create a passphrase-protected backup so you can read '
                  'messages on a new device. Geoloc never sees your passphrase.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passphraseController,
                  obscureText: obscure,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: 'Backup passphrase',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: busy
                          ? null
                          : () => setState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  enabled: !busy,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(color: cs.error, fontSize: 13),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final passphrase = passphraseController.text;
                        final confirm = confirmController.text;
                        if (passphrase.trim().isEmpty) {
                          setState(() => error = 'Passphrase is required');
                          return;
                        }
                        if (passphrase != confirm) {
                          setState(() => error = 'Passphrases do not match');
                          return;
                        }
                        setState(() {
                          busy = true;
                          error = null;
                        });
                        try {
                          await ref
                              .read(dmInboxProvider.notifier)
                              .uploadBackup(passphrase);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Message backup saved'),
                              ),
                            );
                          }
                        } on DmException catch (e) {
                          setState(() {
                            busy = false;
                            error = e.message;
                          });
                        } catch (e) {
                          setState(() {
                            busy = false;
                            error = '$e';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save backup'),
              ),
            ],
          );
        },
      );
    },
  );
  passphraseController.dispose();
  confirmController.dispose();
}

Future<bool> confirmCreateNewIdentity(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Create new encryption key?'),
        content: const Text(
          'This device will get a new identity. You will not be able to '
          'decrypt older messages unless you restore from backup first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Create new key'),
          ),
        ],
      );
    },
  );
  return result == true;
}
