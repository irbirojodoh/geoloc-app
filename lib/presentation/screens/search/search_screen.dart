import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
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
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
              SliverAppBar.medium(
                backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
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

    if (state.recentSearches.isEmpty) {
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
        itemCount:
            state.userResults.length +
            (state.autocompleteUsers.isNotEmpty ||
                    state.autocompleteHashtags.isNotEmpty
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (index == 0 &&
              (state.autocompleteUsers.isNotEmpty ||
                  state.autocompleteHashtags.isNotEmpty)) {
            return _buildAutocompleteSection(context, state, textTheme);
          }

          final user = state.userResults[
              index -
                  ((state.autocompleteUsers.isNotEmpty ||
                          state.autocompleteHashtags.isNotEmpty)
                      ? 1
                      : 0)];
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      sliver: SliverList.builder(
        itemCount:
            state.postResults.length +
            (state.autocompleteUsers.isNotEmpty ||
                    state.autocompleteHashtags.isNotEmpty
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (index == 0 &&
              (state.autocompleteUsers.isNotEmpty ||
                  state.autocompleteHashtags.isNotEmpty)) {
            return _buildAutocompleteSection(context, state, textTheme);
          }

          final post = state.postResults[
              index -
                  ((state.autocompleteUsers.isNotEmpty ||
                          state.autocompleteHashtags.isNotEmpty)
                      ? 1
                      : 0)];
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: PostCard(
              post: post,
              headerTrailing: PostOverflowMenuButton(post: post),
              onTap: () {
                // Search(1) -> Post detail(0.5): slide from left.
                setShellNavTransitionDirection(-1);
                context.push('/post/${post.id}');
              },
              onUserTap: () => context.push('/profile/${post.userId}'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAutocompleteSection(
    BuildContext context,
    SearchState state,
    TextTheme textTheme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    final chips = <Widget>[
      ...state.autocompleteUsers.map((username) {
        return ActionChip(
          avatar: const Icon(Icons.person_outline, size: 16),
          label: Text('@$username'),
          onPressed: () => _onRecentSearchTap(username),
        );
      }),
      ...state.autocompleteHashtags.map((hashtag) {
        return ActionChip(
          avatar: const Icon(Icons.tag, size: 16),
          label: Text(hashtag),
          onPressed: () => _onRecentSearchTap(hashtag),
        );
      }),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
