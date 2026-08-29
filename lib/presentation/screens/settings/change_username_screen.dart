import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/username.dart';
import '../../../data/models/username.dart';
import '../../helpers/username_propagation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/change_username_provider.dart';
import '../../widgets/top_bar_backdrop.dart';

/// Dedicated username change flow — cooldown, live availability, confirm.
class ChangeUsernameScreen extends ConsumerStatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  ConsumerState<ChangeUsernameScreen> createState() =>
      _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends ConsumerState<ChangeUsernameScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncController(String candidate) {
    if (_controller.text == candidate) return;
    _controller.value = TextEditingValue(
      text: candidate,
      selection: TextSelection.collapsed(offset: candidate.length),
    );
  }

  Future<void> _onSubmit() async {
    final state = ref.read(changeUsernameProvider);
    if (!state.canSubmit) return;

    final confirmed = await _confirmChange(
      oldHandle: state.currentUsername,
      newHandle: state.candidate,
    );
    if (confirmed != true || !mounted) return;

    final result =
        await ref.read(changeUsernameProvider.notifier).submit();
    if (!mounted) return;
    if (result == null) return;

    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      await propagateUsernameChange(ref, userId, result.username);
    }

    if (!mounted) return;
    context.pop();
  }

  Future<bool?> _confirmChange({
    required String oldHandle,
    required String newHandle,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(
            'Change username to @$newHandle?',
            style: context.textTheme.headlineSmall,
          ),
          content: Text(
            '@$oldHandle will stop working immediately — anyone linking to '
            'it will no longer find you.\n\n'
            'You won’t be able to change your username again for 2 months.',
            style: context.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cs.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Change username',
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final state = ref.watch(changeUsernameProvider);

    ref.listen<ChangeUsernameState>(changeUsernameProvider, (prev, next) {
      if (prev?.candidate != next.candidate) {
        _syncController(next.candidate);
      }
    });

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
              'Username',
              style: textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.isLoadingHistory)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            )
          else if (state.loadError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _LoadError(
                message: state.loadError!,
                onRetry: () =>
                    ref.read(changeUsernameProvider.notifier).loadHistory(),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (state.isOnCooldown) ...[
                    _CooldownBanner(
                      nextChangeAt: state.nextChangeAt!,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _UsernameCard(
                    controller: _controller,
                    focusNode: _focusNode,
                    state: state,
                    onChanged: (value) => ref
                        .read(changeUsernameProvider.notifier)
                        .onCandidateChanged(value),
                    onSubmit: _onSubmit,
                  ),
                  if (!state.isOnCooldown) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          state.canSubmit && !state.isSubmitting
                              ? _onSubmit
                              : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Change username'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _ReservedHandlesNote(),
                  if (state.history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _HistorySection(entries: state.history),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: context.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner({required this.nextChangeAt});

  final DateTime nextChangeAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = formatUsernameDate(context, nextChangeAt);
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.schedule, color: cs.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You can change your username again on $date. '
                'Usernames can only be changed once every 2 months.',
                style: context.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsernameCard extends StatelessWidget {
  const _UsernameCard({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChangeUsernameState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final readOnly = state.isOnCooldown;
    final fieldError = _fieldError(state);
    final helper = _helper(state);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Username',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('change_username_field'),
              controller: controller,
              focusNode: focusNode,
              enabled: !readOnly,
              readOnly: readOnly,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              style: context.body,
              inputFormatters: [
                LengthLimitingTextInputFormatter(kUsernameMaxLength),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final lower = newValue.text.toLowerCase();
                  if (lower == newValue.text) return newValue;
                  return newValue.copyWith(
                    text: lower,
                    composing: TextRange.empty,
                  );
                }),
              ],
              decoration: _decoration(
                context,
                prefixText: '@',
                errorText: fieldError,
                helperText: helper,
                suffix: _suffix(context, state),
              ),
              onChanged: onChanged,
              onSubmitted: (_) {
                if (state.canSubmit) onSubmit();
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _fieldError(ChangeUsernameState state) {
    if (state.isOnCooldown) return null;
    if (state.submitError != null) return state.submitError;
    if (state.formatError != null) return state.formatError;
    if (state.availabilityStatus == UsernameAvailabilityStatus.unavailable) {
      return state.availabilityReason;
    }
    return null;
  }

  String? _helper(ChangeUsernameState state) {
    if (state.isOnCooldown) return null;
    if (state.submitError != null || state.formatError != null) return null;
    switch (state.availabilityStatus) {
      case UsernameAvailabilityStatus.checking:
        return 'Checking…';
      case UsernameAvailabilityStatus.available:
        return 'This username is available';
      case UsernameAvailabilityStatus.unavailable:
      case UsernameAvailabilityStatus.idle:
        return null;
    }
  }

  Widget? _suffix(BuildContext context, ChangeUsernameState state) {
    if (state.isOnCooldown) return null;
    final cs = Theme.of(context).colorScheme;
    switch (state.availabilityStatus) {
      case UsernameAvailabilityStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        );
      case UsernameAvailabilityStatus.available:
        return Icon(Icons.check_circle_outline, color: cs.primary, size: 20);
      case UsernameAvailabilityStatus.unavailable:
        return Icon(Icons.error_outline, color: cs.error, size: 20);
      case UsernameAvailabilityStatus.idle:
        return null;
    }
  }

  InputDecoration _decoration(
    BuildContext context, {
    String? prefixText,
    String? errorText,
    String? helperText,
    Widget? suffix,
  }) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      prefixText: prefixText,
      prefixStyle: context.body.copyWith(color: cs.onSurfaceVariant),
      errorText: errorText,
      helperText: helperText,
      helperStyle: errorText == null &&
              state.availabilityStatus == UsernameAvailabilityStatus.available
          ? TextStyle(color: cs.primary)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _ReservedHandlesNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Previous usernames stay reserved to your account, so nobody else can '
        'take them. You can reclaim one later.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.entries});

  final List<UsernameHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Past usernames',
            style: textTheme.labelLarge?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  title: Text(
                    'was @${entries[i].oldUsername} until '
                    '${formatUsernameDate(context, entries[i].changedAt)}',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String formatUsernameDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatFullDate(date.toLocal());
}
