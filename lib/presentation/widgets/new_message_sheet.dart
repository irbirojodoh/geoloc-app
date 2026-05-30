import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../config/routes.dart';
import '../../../core/errors/dm_exception.dart';
import '../../../data/models/user.dart';
import '../../../services/search_service.dart';
import '../providers/auth_provider.dart';
import '../providers/dm_provider.dart';
import '../providers/moderation_lists_provider.dart';
import 'user_avatar.dart';

/// Bottom sheet to pick a user and start (or open) a DM thread.
Future<void> showNewMessageSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _NewMessageSheet(ref: ref),
  );
}

class _NewMessageSheet extends ConsumerStatefulWidget {
  const _NewMessageSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends ConsumerState<_NewMessageSheet> {
  final TextEditingController _queryController = TextEditingController();
  Timer? _debounce;
  List<User> _results = const [];
  bool _isLoading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(AppConfig.searchDebounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _isLoading = false;
        _error = null;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _lastQuery = trimmed;
    });

    try {
      final response = await ref
          .read(searchServiceProvider)
          .searchGlobal(trimmed, type: 'users', limit: 20);
      final currentUserId = ref.read(currentUserProvider)?.id;
      final blocked =
          ref.read(blockedUsersListProvider).valueOrNull ?? <User>[];
      final blockedIds = blocked.map((u) => u.id).toSet();

      final users = response.users
          .where((u) => u.id != currentUserId && !blockedIds.contains(u.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _results = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Search failed';
      });
    }
  }

  Future<void> _openChat(User user) async {
    if (!mounted) return;
    Navigator.of(context).pop();
    try {
      final conversation = await ref
          .read(dmInboxProvider.notifier)
          .openConversationWith(user.id);
      if (!mounted || conversation == null) return;
      setShellNavTransitionDirection(1);
      context.push(
        RoutePaths.chatPath(conversation.conversationId, user.id),
      );
    } on DmException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'New message',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchBar(
                controller: _queryController,
                leading: const Icon(Icons.search),
                hintText: 'Search people',
                backgroundColor: WidgetStatePropertyAll(
                  colorScheme.surfaceContainerHighest,
                ),
                onChanged: _onQueryChanged,
                trailing: [
                  if (_queryController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _queryController.clear();
                        _search('');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: _buildResults(
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    if (_lastQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 48,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Find someone to message',
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Search by name or username',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoading && _results.isEmpty) {
      return Center(
        child: Text(
          'No users found for "$_lastQuery"',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        indent: 72,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final user = _results[index];
        final displayName = user.fullName?.isNotEmpty == true
            ? user.fullName!
            : user.username;
        return ListTile(
          leading: UserAvatar(
            imageUrl: user.profilePictureUrl,
            name: user.username,
            size: 48,
          ),
          title: Text(
            displayName,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('@${user.username}'),
          trailing: Icon(
            Icons.chat_bubble_outline,
            color: colorScheme.primary,
          ),
          onTap: () => _openChat(user),
        );
      },
    );
  }
}
