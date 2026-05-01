import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_extensions.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/profile_overflow_menu_button.dart';
import '../../widgets/custom_refresh_indicator.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../core/theme/app_colors.dart';

/// Profile screen — old-money luxury aesthetic
class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider(widget.userId).notifier).loadProfile();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(profileProvider(widget.userId).notifier).loadMorePosts();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: profileState.isLoading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.gold(context),
                ),
              )
            : profileState.error != null
                ? _buildErrorView(context, profileState.error!)
                : _buildContent(context, profileState, isOwnProfile),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ProfileState profileState,
    bool isOwnProfile,
  ) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    if (profileState.user == null) {
      return Center(
        child: Text(
          'User not found',
          style: context.bodyMedium,
        ),
      );
    }

    return CustomRefreshIndicator(
      onRefresh: () async {
        await ref
            .read(profileProvider(widget.userId).notifier)
            .refreshProfile();
      },
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            _buildProfileInfo(context, profileState, isOwnProfile),
            const SizedBox(height: 8),
            _buildPostsHeader(context, profileState.posts.length),
            if (profileState.posts.isEmpty)
              _buildEmptyPosts(context)
            else
              ...profileState.posts.map(
                (post) => PostCard(
                  post: post,
                  headerTrailing: PostOverflowMenuButton(post: post),
                  onTap: () => context.push('/post/${post.id}'),
                  onLike: () {},
                  onComment: () => context.push('/post/${post.id}'),
                  onUserTap: () {},
                ),
              ),
            if (profileState.isLoadingPosts)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: gold,
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(
    BuildContext context,
    ProfileState profileState,
    bool isOwnProfile,
  ) {
    final user = profileState.user!;
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    const double baseCoverHeight = 180;
    const double avatarSize = 80;
    const double avatarOverlap = 40;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final coverHeight = baseCoverHeight + statusBarHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            // Cover
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: user.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: user.coverImageUrl!,
                      fit: BoxFit.cover,
                      cacheManager: PostImageCacheManager.instance,
                      placeholder: (context, url) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              gold.withValues(alpha: 0.1),
                              cs.surface,
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: cs.surface,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            gold.withValues(alpha: 0.1),
                            cs.surface,
                          ],
                        ),
                      ),
                    ),
            ),
            // User info
            Container(
              color: cs.surface,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: avatarOverlap + 8,
                bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (user.fullName != null && user.fullName!.isNotEmpty)
                    Text(
                      user.fullName!,
                      style: context.emptyTitle,
                    ),
                  Text(
                    '@${user.username}',
                    style: context.monoCaption,
                  ),
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      user.bio!,
                      style: context.postContent,
                    ),
                  ],
                  if (user.createdAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textMuted(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Joined ${_formatJoinDate(user.createdAt!)}',
                          style: context.bodySmallLight,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stats
                  Row(
                    children: [
                      _buildStatItem(
                        context,
                        '${user.followingCount}',
                        'Following',
                      ),
                      const SizedBox(width: 24),
                      _buildStatItem(
                        context,
                        '${user.followersCount}',
                        'Followers',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Avatar
        Positioned(
          left: 16,
          top: coverHeight - avatarOverlap,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 4),
              color: cs.surface,
            ),
            child: user.profilePictureUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.profilePictureUrl!,
                      fit: BoxFit.cover,
                      cacheManager: AvatarCacheManager.instance,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: gold,
                        ),
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person_outlined,
                        size: 40,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  )
                : Icon(
                    Icons.person_outlined,
                    size: 40,
                    color: AppColors.textMuted(context),
                  ),
          ),
        ),
        // Edit / Follow button
        Positioned(
          right: 24,
          top: coverHeight - 20,
          child: isOwnProfile
              ? GestureDetector(
                  onTap: () => context.push('/profile/edit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: gold, width: 1),
                    ),
                    child: Text(
                      'Edit profile',
                      style: context.link,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: profileState.isFollowLoading
                      ? null
                      : () {
                          ref
                              .read(profileProvider(widget.userId).notifier)
                              .toggleFollow();
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (profileState.user?.isFollowing ?? false)
                          ? cs.surface
                          : gold,
                      borderRadius: BorderRadius.circular(2),
                      border: (profileState.user?.isFollowing ?? false)
                          ? Border.all(color: gold, width: 1)
                          : null,
                    ),
                    child: profileState.isFollowLoading
                        ? SizedBox(
                            width: 60,
                            height: 18,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: gold,
                              ),
                            ),
                          )
                        : Text(
                            (profileState.user?.isFollowing ?? false)
                                ? 'Following'
                                : 'Follow',
                            style: context.link,
                          ),
                  ),
                ),
        ),
        // Back button
        Positioned(
          left: 16,
          top: statusBarHeight + 8,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (!isOwnProfile)
          Positioned(
            right: 16,
            top: statusBarHeight + 8,
            child: ProfileOverflowMenuButton(profileUserId: widget.userId),
          ),
      ],
    );
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          value,
          style: context.monoCaption,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.bodySmallLight,
        ),
      ],
    );
  }

  Widget _buildPostsHeader(BuildContext context, int postCount) {
    final gold = AppColors.gold(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'POSTS',
            style: context.sectionLabel,
          ),
          const SizedBox(width: 8),
          Text(
            '($postCount)',
            style: context.monoSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPosts(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: context.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: context.bodyMedium,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                ref
                    .read(profileProvider(widget.userId).notifier)
                    .loadProfile();
              },
              child: Text(
                'RETRY',
                style: context.actionLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
