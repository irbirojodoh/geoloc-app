import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            // Header with gradient
            _buildHeader(context, profileState, isOwnProfile),
            // Content
            Expanded(
              child: profileState.isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : profileState.error != null
                  ? _buildErrorView(context, profileState.error!)
                  : _buildContent(context, profileState, isOwnProfile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProfileState profileState,
    bool isOwnProfile,
  ) {
    final iconColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );

    return Container(
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
      child: Column(
        children: [
          // Status bar area
          SizedBox(height: MediaQuery.of(context).padding.top),
          // Top bar with back button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                // Back button
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.systemGrey5,
                        context,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.back,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Title
                Text(
                  'Profile',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const Spacer(),
                // Settings button (only for own profile)
                if (isOwnProfile)
                  GestureDetector(
                    onTap: () => context.push('/profile/edit'),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CupertinoDynamicColor.resolve(
                          CupertinoColors.systemGrey5,
                          context,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.pencil,
                        size: 18,
                        color: iconColor,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 35),
              ],
            ),
          ),
        ],
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

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
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
                        size: 45,
                        color: secondaryColor,
                      ),
                    ),
                  )
                : Icon(
                    CupertinoIcons.person_fill,
                    size: 45,
                    color: secondaryColor,
                  ),
          ),
          const SizedBox(height: 12),
          // Username
          Text(
            '@${user.username}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          // Full name
          if (user.fullName != null && user.fullName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.fullName!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: secondaryColor,
              ),
            ),
          ],
          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem(context, '${user.followersCount}', 'Followers'),
              Container(
                height: 30,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.separator,
                  context,
                ),
              ),
              _buildStatItem(context, '${user.followingCount}', 'Following'),
            ],
          ),
          const SizedBox(height: 16),
          // Action button
          if (!isOwnProfile) _buildFollowButton(context, profileState),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    final textColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final secondaryColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(BuildContext context, ProfileState profileState) {
    final isFollowing = profileState.user?.isFollowing ?? false;

    return GestureDetector(
      onTap: () {
        ref.read(profileProvider(widget.userId).notifier).toggleFollow();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: isFollowing
              ? CupertinoDynamicColor.resolve(
                  CupertinoColors.systemGrey5,
                  context,
                )
              : CupertinoColors.systemBlue,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isFollowing
                ? CupertinoDynamicColor.resolve(CupertinoColors.label, context)
                : CupertinoColors.white,
          ),
        ),
      ),
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
