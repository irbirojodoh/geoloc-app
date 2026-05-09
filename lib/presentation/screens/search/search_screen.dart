import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/search_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/states/empty_state.dart';

/// Explore screen (Search) — Material 3.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(searchProvider.notifier).search(query);
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    ref.read(searchProvider.notifier).search(query);
  }

  void _onSearchSubmit(String query) {
    if (query.trim().isNotEmpty) {
      ref.read(searchProvider.notifier).addRecentSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            backgroundColor: colorScheme.surface,
            title: const Text('Explore'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(76),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search),
                  hintText: 'Search users or posts',
                  backgroundColor: WidgetStatePropertyAll(
                    colorScheme.surfaceContainerHighest,
                  ),
                  hintStyle: WidgetStatePropertyAll(
                    textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmit,
                  trailing: [
                    if (state.query.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchProvider.notifier).clearSearch();
                        },
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<SearchTab>(
                segments: const [
                  ButtonSegment(
                    value: SearchTab.users,
                    label: Text('Users'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: SearchTab.posts,
                    label: Text('Posts'),
                    icon: Icon(Icons.article_outlined),
                  ),
                ],
                selected: {state.activeTab},
                onSelectionChanged: (s) {
                  ref.read(searchProvider.notifier).setActiveTab(s.first);
                },
              ),
            ),
          ),
          if (state.query.isEmpty)
            _buildInitialSliver(context, state)
          else
            _buildResultsSliver(context, state, colorScheme, textTheme),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  SliverList _buildInitialSliver(BuildContext context, SearchState state) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (state.recentSearches.isEmpty && state.suggestedUsers.isEmpty) {
      return const SliverList(
        delegate: SliverChildListDelegate.fixed([
          Padding(
            padding: EdgeInsets.all(16),
            child: EmptyState(
              icon: Icons.people_outline,
              title: 'Discover nearby',
              message: 'Search for users and posts in your area.',
            ),
          ),
        ]),
      );
    }

    final children = <Widget>[];

    if (state.recentSearches.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('Recent', style: textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(searchProvider.notifier).clearRecentSearches(),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      );
      children.addAll(
        state.recentSearches.map(
          (q) => ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const Icon(Icons.history),
            title: Text(q, style: textTheme.bodyLarge),
            onTap: () => _onRecentSearchTap(q),
          ),
        ),
      );
    }

    if (state.suggestedUsers.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Suggested', style: textTheme.titleMedium),
        ),
      );
      children.addAll(
        state.suggestedUsers.map(
          (u) => ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: UserAvatar(
              imageUrl: u.profilePictureUrl,
              name: u.username,
              size: 40,
            ),
            title: Text(u.username, style: textTheme.titleMedium),
            subtitle: u.fullName != null && u.fullName!.isNotEmpty
                ? Text(
                    u.fullName!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            onTap: () => context.push('/profile/${u.id}'),
          ),
        ),
      );
    }

    return SliverList(delegate: SliverChildListDelegate(children));
  }

  Widget _buildResultsSliver(
    BuildContext context,
    SearchState state,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (state.isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.showEmptyState) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState(
          icon: Icons.search_off_outlined,
          title: 'No results',
          message: 'Try a different search.',
        ),
      );
    }

    if (state.activeTab == SearchTab.users) {
      return SliverList.builder(
        itemCount: state.userResults.length,
        itemBuilder: (context, index) {
          final user = state.userResults[index];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: UserAvatar(
              imageUrl: user.profilePictureUrl,
              name: user.username,
              size: 40,
            ),
            title: Text(user.username, style: textTheme.titleMedium),
            subtitle: user.fullName != null && user.fullName!.isNotEmpty
                ? Text(
                    user.fullName!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            onTap: () => context.push('/profile/${user.id}'),
          );
        },
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      sliver: SliverList.builder(
        itemCount: state.postResults.length,
        itemBuilder: (context, index) {
          final post = state.postResults[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PostCard(
              post: post,
              headerTrailing: PostOverflowMenuButton(post: post),
              onTap: () => context.push('/post/${post.id}'),
              onUserTap: () => context.push('/profile/${post.userId}'),
            ),
          );
        },
      ),
    );
  }
}
