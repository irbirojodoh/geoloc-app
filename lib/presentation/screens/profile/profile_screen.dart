import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/routes.dart';
import '../../../data/models/post.dart';
import '../../helpers/open_post_detail.dart';
import '../../widgets/auth_network_image.dart';

import '../../../core/errors/dm_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dm_provider.dart';
import '../../providers/moderation_lists_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/profile_overflow_menu_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/top_bar_backdrop.dart';
import '../../widgets/user_avatar.dart';

/// Own-profile tab. Other users open [ProfileScreen] as an overlay via `/profile/:id`.
class CurrentUserProfileTab extends ConsumerWidget {
  const CurrentUserProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider)?.id;
    if (userId == null || userId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return ProfileScreen(userId: userId);
  }
}

/// Material 3 profile screen.
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
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
      final current = ref.read(profileProvider(widget.userId));
      if (current.user != null) return;
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

  Future<void> _openMessage(BuildContext context, String peerUserId) async {
    try {
      final conversation = await ref
          .read(dmInboxProvider.notifier)
          .openConversationWith(peerUserId);
      if (!context.mounted || conversation == null) return;
      setShellNavTransitionDirection(1);
      context.push(
        RoutePaths.chatPath(conversation.conversationId, peerUserId),
      );
    } on DmException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open chat: $e')),
      );
    }
  }

  void _openPost(Post post) {
    // Match feed: slide detail in from the right.
    setShellNavTransitionDirection(1);
    openPostDetail(context, ref, post).then((value) {
      if (value is Post) {
        ref.read(profileProvider(widget.userId).notifier).updatePost(value);
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  PreferredSizeWidget? _backOnlyAppBar(BuildContext context) {
    if (!context.canPop()) return null;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final profileState = ref.watch(profileProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;
    final colorScheme = Theme.of(context).colorScheme;

    if (profileState.isLoading && profileState.user == null) {
      return Scaffold(
        appBar: _backOnlyAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (profileState.error != null &&
        profileState.user == null &&
        profileState.posts.isEmpty) {
      return Scaffold(
        appBar: _backOnlyAppBar(context),
        body: ErrorState(
          message: profileState.error!,
          onRetry: () => ref
              .read(profileProvider(widget.userId).notifier)
              .loadProfile(force: true),
        ),
      );
    }

    final user = profileState.user;
    if (user == null) {
      return Scaffold(
        appBar: _backOnlyAppBar(context),
        body: const EmptyState(
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
        (profileImageUrl != null && profileImageUrl.isNotEmpty) ||
            user.avatarKey != null;
    final hasCoverImage =
        (coverImageUrl != null && coverImageUrl.isNotEmpty) ||
            user.coverKey != null;

    final activePosts = _activeTabIndex == 0 ? profileState.posts : likedPosts;
    final blockedUsers = ref.watch(blockedUsersListProvider).valueOrNull ?? [];
    final isBlocked =
        blockedUsers.any((blockedUser) => blockedUser.id == widget.userId);

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
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  centerTitle: false,
                  titleSpacing: 16,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  flexibleSpace: TopBarBackdrop(
                    blurTintColor: colorScheme.surface,
                    blendColor: colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  title: Text('@${user.username}'),
                  pinned: true,
                  automaticallyImplyLeading: false,
                  leading: context.canPop()
                      ? IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back),
                        )
                      : null,
                  actions: [
                    if (!isOwnProfile)
                      ProfileOverflowMenuButton(profileUserId: widget.userId),
                  ],
                ),
                SliverToBoxAdapter(
                  child: _ProfileHeaderSection(
                    hasCoverImage: hasCoverImage,
                    coverImageUrl: coverImageUrl,
                    coverImageKey: user.coverKey,
                    hasProfileImage: hasProfileImage,
                    profileImageUrl: profileImageUrl,
                    profileImageKey: user.avatarKey,
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
                    onEditProfile: () {
                      setShellNavTransitionDirection(1);
                      context.push(RoutePaths.editProfile);
                    },
                    onToggleFollow: () => ref
                        .read(profileProvider(widget.userId).notifier)
                        .toggleFollow(),
                    isBlocked: isBlocked,
                    onMessage: isBlocked
                        ? null
                        : () => _openMessage(context, widget.userId),
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
                            key: ValueKey(post.id),
                            post: post,
                            headerTrailing: PostOverflowMenuButton(post: post),
                            onTap: () => _openPost(post),
                            onComment: () => _openPost(post),
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
    this.coverImageKey,
    required this.hasProfileImage,
    required this.profileImageUrl,
    this.profileImageKey,
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
    this.isBlocked = false,
    this.onMessage,
  });

  final bool hasCoverImage;
  final String? coverImageUrl;
  final String? coverImageKey;
  final bool hasProfileImage;
  final String? profileImageUrl;
  final String? profileImageKey;
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
  final bool isBlocked;
  final VoidCallback? onMessage;

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
                  AuthNetworkImage(
                    imageUrl: coverImageUrl ?? '',
                    mediaKey: coverImageKey,
                    fit: BoxFit.cover,
                    memCacheWidth:
                        (MediaQuery.sizeOf(context).width *
                                MediaQuery.devicePixelRatioOf(context))
                            .round(),
                    memCacheHeight:
                        (200 * MediaQuery.devicePixelRatioOf(context)).round(),
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
                    imageKey: profileImageKey,
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
                      : isBlocked
                          ? OutlinedButton(
                              onPressed: null,
                              child: const Text('Message unavailable'),
                            )
                          : Row(
                              children: [
                                if (onMessage != null)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: onMessage,
                                      child: const Text('Message'),
                                    ),
                                  ),
                                if (onMessage != null) const SizedBox(width: 8),
                                Expanded(
                                  child: isFollowing
                                      ? OutlinedButton(
                                          onPressed: isFollowLoading
                                              ? null
                                              : onToggleFollow,
                                          child: const Text('Following'),
                                        )
                                      : FilledButton(
                                          onPressed: isFollowLoading
                                              ? null
                                              : onToggleFollow,
                                          child: const Text('Follow'),
                                        ),
                                ),
                              ],
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
