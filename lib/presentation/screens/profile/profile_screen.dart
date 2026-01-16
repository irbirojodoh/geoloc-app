import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/custom_refresh_indicator.dart';
import '../../../core/cache/image_cache_manager.dart';

// ============================================================================
// Dynamic Colors for Light/Dark Mode Adaptation (consistent with feed screen)
// ============================================================================

const _cardBackgroundStart = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF0F4F8), // Light mode: Very light blue-gray
  darkColor: Color(0xFF2C2C2E), // Dark mode: iOS dark secondary
);

const _cardBackgroundEnd = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF), // Light mode: White
  darkColor: Color(0xFF1C1C1E), // Dark mode: iOS dark card
);

/// Profile screen showing user details and their posts
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
    // Load profile when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider(widget.userId).notifier).loadProfile();
    });

    // Listen for scroll to load more posts
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

  Color _resolveColor(
    BuildContext context,
    CupertinoDynamicColor dynamicColor,
  ) {
    return CupertinoDynamicColor.resolve(dynamicColor, context);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.id == widget.userId;

    final backgroundColor = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors.systemGrey6,
        darkColor: CupertinoColors.darkBackgroundGray,
      ),
      context,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: profileState.isLoading
            ? const Center(child: CupertinoActivityIndicator())
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
    if (profileState.user == null) {
      return const Center(child: Text('User not found'));
    }

    return CustomRefreshIndicator(
      onRefresh: () async {
        await ref
            .read(profileProvider(widget.userId).notifier)
            .refreshProfile();
      },
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            // Profile info section
            _buildProfileInfo(context, profileState, isOwnProfile),
            const SizedBox(height: 8),
            // Posts section header
            _buildPostsHeader(context, profileState.posts.length),
            // Posts list
            if (profileState.posts.isEmpty)
              _buildEmptyPosts(context)
            else
              ...profileState.posts.map(
                (post) => PostCard(
                  post: post,
                  onTap: () => context.push('/post/${post.id}'),
                  onLike: () {},
                  onComment: () => context.push('/post/${post.id}'),
                  onUserTap: () {}, // Already on profile
                ),
              ),
            // Loading indicator for pagination
            if (profileState.isLoadingPosts)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CupertinoActivityIndicator()),
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
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondaryColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final cardBg = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: Color(0xFFFFFFFF),
        darkColor: Color(0xFF1C1C1E),
      ),
      context,
    );

    const double baseCoverHeight = 180;
    const double avatarSize = 80;
    const double avatarOverlap = 40;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final coverHeight = baseCoverHeight + statusBarHeight;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main content column (rendered first, behind)
        Column(
          children: [
            // Cover image (extends behind status bar)
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
                            stops: const [0.14, 0.67],
                            colors: [
                              _resolveColor(context, _cardBackgroundStart),
                              _resolveColor(context, _cardBackgroundEnd),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.systemGrey4,
                          context,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.14, 0.67],
                          colors: [
                            _resolveColor(context, _cardBackgroundStart),
                            _resolveColor(context, _cardBackgroundEnd),
                          ],
                        ),
                      ),
                    ),
            ),
            // User info section with top padding for avatar overlap
            Container(
              color: cardBg,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: avatarOverlap + 8,
                bottom: 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full name
                  if (user.fullName != null && user.fullName!.isNotEmpty)
                    Text(
                      user.fullName!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  // Username
                  Text(
                    '@${user.username}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: secondaryColor,
                    ),
                  ),
                  // Bio
                  if (user.bio != null && user.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      user.bio!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                  // Joined date
                  if (user.createdAt != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.calendar,
                          size: 16,
                          color: secondaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Joined ${_formatJoinDate(user.createdAt!)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Stats row
                  Row(
                    children: [
                      _buildStatItemHorizontal(
                        context,
                        '${user.followingCount}',
                        'Following',
                      ),
                      const SizedBox(width: 20),
                      _buildStatItemHorizontal(
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
        // Avatar positioned at bottom of cover, overlapping into user info (rendered on top)
        Positioned(
          left: 16,
          top: coverHeight - avatarOverlap,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cardBg, width: 4),
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemGrey5,
                context,
              ),
            ),
            child: user.profilePictureUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: user.profilePictureUrl!,
                      fit: BoxFit.cover,
                      cacheManager: AvatarCacheManager.instance,
                      placeholder: (context, url) =>
                          const Center(child: CupertinoActivityIndicator()),
                      errorWidget: (context, url, error) => Icon(
                        CupertinoIcons.person_fill,
                        size: 40,
                        color: secondaryColor,
                      ),
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_fill,
                    size: 40,
                    color: secondaryColor,
                  ),
          ),
        ),
        // Edit profile / Follow button (rendered on top)
        Positioned(
          right: 24,
          top: coverHeight - 20,
          child: isOwnProfile
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.push('/profile/edit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: textColor, width: 1.5),
                    ),
                    child: Text(
                      'Edit profile',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
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
                          ? cardBg
                          : CupertinoColors.systemBlue,
                      borderRadius: BorderRadius.circular(20),
                      border: (profileState.user?.isFollowing ?? false)
                          ? Border.all(color: textColor, width: 1.5)
                          : null,
                    ),
                    child: Text(
                      (profileState.user?.isFollowing ?? false)
                          ? 'Following'
                          : 'Follow',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (profileState.user?.isFollowing ?? false)
                            ? textColor
                            : CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
        ),
        // Back button overlay on cover image
        Positioned(
          left: 16,
          top: statusBarHeight + 8,
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.3),
              ),
              child: const Icon(
                CupertinoIcons.back,
                size: 20,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatJoinDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildStatItemHorizontal(
    BuildContext context,
    String value,
    String label,
  ) {
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondaryColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Row(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsHeader(BuildContext context, int postCount) {
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(CupertinoIcons.square_grid_2x2, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            'Posts',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($postCount)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.secondaryLabel,
                context,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPosts(BuildContext context) {
    final secondaryColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.square_stack_3d_up,
            size: 48,
            color: secondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle,
              size: 48,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemRed,
                context,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton(
              onPressed: () {
                ref.read(profileProvider(widget.userId).notifier).loadProfile();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
