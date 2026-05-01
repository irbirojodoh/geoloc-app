import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/search_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/user_avatar.dart';

/// Search screen — old-money luxury aesthetic
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(context, state),
            if (state.query.isNotEmpty && state.hasSearched)
              _buildTabBar(context, state),
            Expanded(
              child: state.query.isEmpty
                  ? _buildInitialContent(context, state)
                  : _buildSearchResults(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context, SearchState state) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outline, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmit,
              cursorColor: gold,
              style: context.body,
              decoration: InputDecoration(
                hintText: 'Search users or posts...',
                hintStyle: context.body,
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textMuted(context),
                ),
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              'Cancel',
              style: context.sheetItem?.copyWith(color: gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, SearchState state) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildTabButton(
            context,
            'Users',
            SearchTab.users,
            state.activeTab,
            state.userResults.length,
          ),
          const SizedBox(width: 10),
          _buildTabButton(
            context,
            'Posts',
            SearchTab.posts,
            state.activeTab,
            state.postResults.length,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    SearchTab tab,
    SearchTab activeTab,
    int count,
  ) {
    final isActive = tab == activeTab;
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return GestureDetector(
      onTap: () => ref.read(searchProvider.notifier).setActiveTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isActive ? gold : cs.outline,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.bodySmall,
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: context.monoCaption,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialContent(BuildContext context, SearchState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.recentSearches.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'RECENT SEARCHES',
            onClear: () =>
                ref.read(searchProvider.notifier).clearRecentSearches(),
          ),
          const SizedBox(height: 8),
          ...state.recentSearches.map(
            (search) => _buildRecentSearchTile(context, search),
          ),
          const SizedBox(height: 24),
        ],
        if (state.suggestedUsers.isNotEmpty) ...[
          _buildSectionHeader(context, 'SUGGESTED USERS'),
          const SizedBox(height: 8),
          ...state.suggestedUsers.map(
            (user) => _buildUserTile(
              context,
              user.id,
              user.username,
              user.fullName,
              user.profilePictureUrl,
            ),
          ),
        ],
        if (state.recentSearches.isEmpty && state.suggestedUsers.isEmpty)
          _buildEmptyInitialState(context),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onClear,
  }) {
    final gold = AppColors.gold(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.sectionLabel,
        ),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear',
              style: context.link,
            ),
          ),
      ],
    );
  }

  Widget _buildRecentSearchTile(BuildContext context, String search) {
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key('recent_$search'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(searchProvider.notifier).removeRecentSearch(search),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outlined,
          color: Colors.white,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.history,
          color: AppColors.textMuted(context),
        ),
        title: Text(
          search,
          style: context.body,
        ),
        trailing: Icon(
          Icons.north_west,
          size: 16,
          color: AppColors.textMuted(context),
        ),
        onTap: () => _onRecentSearchTap(search),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context, SearchState state) {
    final gold = AppColors.gold(context);

    if (state.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: gold,
        ),
      );
    }

    if (state.showEmptyState) {
      return _buildEmptySearchState(context);
    }

    if (state.activeTab == SearchTab.users) {
      return _buildUserResults(context, state);
    } else {
      return _buildPostResults(context, state);
    }
  }

  Widget _buildUserResults(BuildContext context, SearchState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.userResults.length,
      itemBuilder: (context, index) {
        final user = state.userResults[index];
        return _buildUserTile(
          context,
          user.id,
          user.username,
          user.fullName,
          user.profilePictureUrl,
        );
      },
    );
  }

  Widget _buildUserTile(
    BuildContext context,
    String userId,
    String username,
    String? fullName,
    String? avatarUrl,
  ) {
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: UserAvatar(
        imageUrl: avatarUrl,
        name: username,
        size: 44,
      ),
      title: Text(
        username,
        style: context.body,
      ),
      subtitle: fullName != null
          ? Text(
              fullName,
              style: context.bodySmallLight,
            )
          : null,
      onTap: () {
        ref.read(searchProvider.notifier).addRecentSearch(username);
        context.push('/profile/$userId');
      },
    );
  }

  Widget _buildPostResults(BuildContext context, SearchState state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.postResults.length,
      itemBuilder: (context, index) {
        final post = state.postResults[index];
        return PostCard(
          post: post,
          headerTrailing: PostOverflowMenuButton(post: post),
          onTap: () => context.push('/post/${post.id}'),
          onUserTap: () => context.push('/profile/${post.userId}'),
        );
      },
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.textMuted(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for something else',
              style: context.bodyMedium?.copyWith(color: AppColors.textMuted(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInitialState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outlined,
              size: 64,
              color: AppColors.textMuted(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Find people nearby',
              style: context.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Search for users or posts in your area',
              style: context.bodyMedium?.copyWith(color: AppColors.textMuted(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
