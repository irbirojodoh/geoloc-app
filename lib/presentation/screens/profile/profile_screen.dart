import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/profile_overflow_menu_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/user_avatar.dart';

/// Material 3 profile screen.
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _scrollController.addListener(_handleScrollEndReached);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider(widget.userId).notifier).loadProfile();
    });
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_activeTabIndex != _tabController.index) {
      setState(() => _activeTabIndex = _tabController.index);
    }
  }

  void _handleScrollEndReached() {
    if (!_scrollController.hasClients) return;
    if (_activeTabIndex != 0) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      ref.read(profileProvider(widget.userId).notifier).loadMorePosts();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;
    final colorScheme = Theme.of(context).colorScheme;

    if (profileState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profileState.error != null) {
      return Scaffold(
        body: ErrorState(
          message: profileState.error!,
          onRetry: () => ref.read(profileProvider(widget.userId).notifier).loadProfile(),
        ),
      );
    }

    final user = profileState.user;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile unavailable',
          message: 'This profile could not be loaded.',
        ),
      );
    }

    final likedPosts = profileState.posts.where((p) => p.isLiked).toList();
    final profileImageUrl = user.profilePictureUrl?.trim();
    final coverImageUrl = user.coverImageUrl?.trim();
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;
    final hasCoverImage = coverImageUrl != null && coverImageUrl.isNotEmpty;

    final activePosts = _activeTabIndex == 0 ? profileState.posts : likedPosts;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
        strokeWidth: 2.2,
        elevation: 1,
        edgeOffset: 86,
        displacement: 28,
        onRefresh: () =>
            ref.read(profileProvider(widget.userId).notifier).refreshProfile(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
                SliverAppBar(
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: Text('@${user.username}'),
                  pinned: true,
                  automaticallyImplyLeading: false,
                  leading: null,
                  actions: [
                    if (!isOwnProfile)
                      ProfileOverflowMenuButton(profileUserId: widget.userId),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _ProfileHeaderSection(
                    hasCoverImage: hasCoverImage,
                    coverImageUrl: coverImageUrl,
                    hasProfileImage: hasProfileImage,
                    profileImageUrl: profileImageUrl,
                    username: user.username,
                    displayName: user.fullName?.isNotEmpty == true
                        ? user.fullName!
                        : user.username,
                    bio: user.bio,
                    postsCount: profileState.posts.length,
                    followersCount: user.followersCount,
                    followingCount: user.followingCount,
                    isOwnProfile: isOwnProfile,
                    isFollowing: user.isFollowing ?? false,
                    isFollowLoading: profileState.isFollowLoading,
                    onEditProfile: () => context.push('/profile/edit'),
                    onToggleFollow: () => ref
                        .read(profileProvider(widget.userId).notifier)
                        .toggleFollow(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarSliverDelegate(
                    colorScheme: colorScheme,
                    tabBar: TabBar(
                      controller: _tabController,
                      onTap: (index) {
                        if (_activeTabIndex != index) {
                          setState(() => _activeTabIndex = index);
                        }
                      },
                      indicatorColor: colorScheme.primary,
                      labelColor: colorScheme.onSurface,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      tabs: const [
                        Tab(text: 'Posts'),
                        Tab(text: 'Likes'),
                        Tab(text: 'Saved'),
                      ],
                    ),
                  ),
                ),
                if (_activeTabIndex == 2)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.bookmark_outline,
                      title: 'No saved posts',
                      message: 'Saved posts will appear here.',
                    ),
                  )
                else if (activePosts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.article_outlined,
                      title:
                          _activeTabIndex == 0 ? 'No posts yet' : 'No liked posts',
                      message: _activeTabIndex == 0
                          ? 'This user has not posted yet.'
                          : 'Liked posts will appear here.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    sliver: SliverList.builder(
                      itemCount: activePosts.length +
                          (_activeTabIndex == 0 && profileState.isLoadingPosts
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index >= activePosts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final post = activePosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: PostCard(
                            post: post,
                            headerTrailing: PostOverflowMenuButton(post: post),
                            onTap: () {
                              // Profile(3) -> Post detail(0.5): slide from left.
                              setShellNavTransitionDirection(-1);
                              context.push('/post/${post.id}');
                            },
                            onComment: () {
                              setShellNavTransitionDirection(-1);
                              context.push('/post/${post.id}');
                            },
                            onUserTap: () => context.push('/profile/${post.userId}'),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderSection extends StatelessWidget {
  const _ProfileHeaderSection({
    required this.hasCoverImage,
    required this.coverImageUrl,
    required this.hasProfileImage,
    required this.profileImageUrl,
    required this.username,
    required this.displayName,
    required this.bio,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.isFollowLoading,
    required this.onEditProfile,
    required this.onToggleFollow,
  });

  final bool hasCoverImage;
  final String? coverImageUrl;
  final bool hasProfileImage;
  final String? profileImageUrl;
  final String username;
  final String displayName;
  final String? bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isOwnProfile;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback onEditProfile;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (hasCoverImage)
                  CachedNetworkImage(
                    imageUrl: coverImageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.secondaryContainer,
                    ),
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest,
                    ),
                  )
                else
                  Container(
                    color: colorScheme.secondaryContainer,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.landscape_outlined,
                      color: colorScheme.onSecondaryContainer,
                      size: 30,
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colorScheme.scrim.withValues(alpha: 0),
                        colorScheme.scrim.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: -40,
                  child: UserAvatar(
                    imageUrl: hasProfileImage ? profileImageUrl : null,
                    name: username,
                    size: 80,
                    showBorder: true,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (bio != null && bio!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    bio!.trim(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _MetricInline(
                      value: '$postsCount',
                      label: 'Posts',
                    ),
                    const SizedBox(width: 24),
                    _MetricInline(
                      value: '$followersCount',
                      label: 'Followers',
                    ),
                    const SizedBox(width: 24),
                    _MetricInline(
                      value: '$followingCount',
                      label: 'Following',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: isOwnProfile
                      ? OutlinedButton(
                          onPressed: onEditProfile,
                          child: const Text('Edit profile'),
                        )
                      : isFollowing
                          ? OutlinedButton(
                              onPressed: isFollowLoading ? null : onToggleFollow,
                              child: const Text('Following'),
                            )
                          : FilledButton(
                              onPressed: isFollowLoading ? null : onToggleFollow,
                              child: const Text('Follow'),
                            ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant,
          ),
        ],
      ),
    );
  }
}

class _MetricInline extends StatelessWidget {
  const _MetricInline({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TabBarSliverDelegate extends SliverPersistentHeaderDelegate {
  _TabBarSliverDelegate({required this.colorScheme, required this.tabBar});

  final ColorScheme colorScheme;
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: colorScheme.surface,
      child: Column(
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: colorScheme.outlineVariant,
          ),
          Expanded(child: tabBar),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarSliverDelegate oldDelegate) {
    return oldDelegate.colorScheme != colorScheme || oldDelegate.tabBar != tabBar;
  }
}
