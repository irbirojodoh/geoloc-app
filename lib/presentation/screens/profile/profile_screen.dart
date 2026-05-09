import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/profile_overflow_menu_button.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../data/models/post.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider(widget.userId).notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(profileProvider(widget.userId).notifier).refreshProfile(),
        child: DefaultTabController(
          length: 3,
          child: Builder(
            builder: (context) {
              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                      context,
                    ),
                    sliver: SliverAppBar.large(
                      backgroundColor: colorScheme.surface,
                      title: Text('@${user.username}'),
                      pinned: true,
                      leading: IconButton(
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      actions: [
                        if (!isOwnProfile)
                          ProfileOverflowMenuButton(profileUserId: widget.userId),
                      ],
                      bottom: TabBar(
                        controller: _tabController,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: colorScheme.secondaryContainer,
                            backgroundImage: user.profilePictureUrl != null
                                ? CachedNetworkImageProvider(
                                    user.profilePictureUrl!,
                                    cacheManager: AvatarCacheManager.instance,
                                  )
                                : null,
                            child: user.profilePictureUrl == null
                                ? Icon(
                                    Icons.person_outline,
                                    size: 32,
                                    color: colorScheme.onSecondaryContainer,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.fullName?.isNotEmpty == true
                                      ? user.fullName!
                                      : user.username,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${user.username}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _MetricTile(
                              label: 'Posts',
                              value: '${profileState.posts.length}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricTile(
                              label: 'Followers',
                              value: '${user.followersCount}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _MetricTile(
                              label: 'Following',
                              value: '${user.followingCount}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: isOwnProfile
                            ? OutlinedButton(
                                onPressed: () => context.push('/profile/edit'),
                                child: const Text('Edit profile'),
                              )
                            : (user.isFollowing ?? false)
                            ? OutlinedButton(
                                onPressed: profileState.isFollowLoading
                                    ? null
                                    : () => ref
                                        .read(
                                          profileProvider(widget.userId)
                                              .notifier,
                                        )
                                        .toggleFollow(),
                                child: Text(
                                  'Following',
                                ),
                              )
                            : FilledButton(
                                onPressed: profileState.isFollowLoading
                                    ? null
                                    : () => ref
                                        .read(
                                          profileProvider(widget.userId)
                                              .notifier,
                                        )
                                        .toggleFollow(),
                                child: Text(
                                  'Follow',
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _ProfilePostsTab(
                      posts: profileState.posts,
                      onEndReached: () => ref
                          .read(profileProvider(widget.userId).notifier)
                          .loadMorePosts(),
                    ),
                    _ProfilePostsTab(
                      posts: likedPosts,
                      onEndReached: () {},
                    ),
                    const _SavedTab(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfilePostsTab extends StatefulWidget {
  const _ProfilePostsTab({required this.posts, required this.onEndReached});

  final List<Post> posts;
  final VoidCallback onEndReached;

  @override
  State<_ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends State<_ProfilePostsTab> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.pixels >=
          _controller.position.maxScrollExtent - 200) {
        widget.onEndReached();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: 'No content',
        message: 'Nothing to show in this tab yet.',
      );
    }

    return CustomScrollView(
      controller: _controller,
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          sliver: SliverList.builder(
            itemCount: widget.posts.length,
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  headerTrailing: PostOverflowMenuButton(post: post),
                  onTap: () => context.push('/post/${post.id}'),
                  onComment: () => context.push('/post/${post.id}'),
                  onUserTap: () => context.push('/profile/${post.userId}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.bookmark_outline,
            title: 'No saved posts',
            message: 'Saved posts will appear here.',
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          children: [
            Text(value, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
