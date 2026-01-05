import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/custom_refresh_indicator.dart';

// ============================================================================
// Dynamic Colors for Light/Dark Mode Adaptation (consistent with login screen)
// ============================================================================

/// Card background colors
const CupertinoDynamicColor _cardBackgroundStart =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFFFFFFF), // Light mode: White
      darkColor: Color(0xFF3B3B3B), // Dark mode: Dark gray
    );

const CupertinoDynamicColor _cardBackgroundEnd =
    CupertinoDynamicColor.withBrightness(
      color: Color(0xFFF8F8F8), // Light mode: Off-white
      darkColor: Color(0xFF262525), // Dark mode: Darker gray
    );

/// Shadow color
const CupertinoDynamicColor _shadowColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x1A000000), // Light mode: Subtle shadow
  darkColor: Color(0x80000000), // Dark mode: Stronger shadow
);

/// Text colors
const CupertinoDynamicColor _primaryText = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF000000), // Light mode: Black
  darkColor: Color(0xFFFFFFFF), // Dark mode: White
);

// ============================================================================
// Feed Screen Widget
// ============================================================================

/// Main feed screen showing location-based posts
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);

    // Load feed after location is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeed();
    });
  }

  Future<void> _initializeFeed() async {
    final locationState = ref.read(locationStateProvider);

    if (!locationState.hasLocation && !locationState.isLoading) {
      await ref.read(locationStateProvider.notifier).requestPermission();
    }

    if (ref.read(locationStateProvider).hasLocation) {
      await ref.read(feedStateProvider.notifier).loadFeed();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedStateProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Resolve a CupertinoDynamicColor to its current brightness value
  Color _resolveColor(
    BuildContext context,
    CupertinoDynamicColor dynamicColor,
  ) {
    return CupertinoDynamicColor.resolve(dynamicColor, context);
  }

  /// Show logout action sheet
  void _showLogoutSheet(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(
          'Account',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel,
              context,
            ),
          ),
        ),
        message: Text(
          ref.read(currentUserProvider)?.email ?? 'Logged in',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.tertiaryLabel,
              context,
            ),
          ),
        ),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              final userId = ref.read(currentUserProvider)?.id;
              if (userId != null) {
                context.push('/profile/$userId');
              }
            },
            child: Text(
              'View Profile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.systemBlue,
                  context,
                ),
              ),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateProvider.notifier).logout();
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBlue,
                context,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedStateProvider);
    final locationState = ref.watch(locationStateProvider);
    final theme = Theme.of(context);

    // Listen to location changes and reload feed
    ref.listen<LocationState>(locationStateProvider, (previous, next) {
      if (previous?.position == null && next.position != null) {
        ref.read(feedStateProvider.notifier).loadFeed();
      }
    });

    // Background color - light gray for card contrast
    final backgroundColor = CupertinoDynamicColor.resolve(
      const CupertinoDynamicColor.withBrightness(
        color: CupertinoColors
            .systemGrey6, // Light mode: iOS grouped background gray
        darkColor: CupertinoColors.darkBackgroundGray, // Dark mode: Pure black
      ),
      context,
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: false, // Don't add padding at top, we'll color the status bar area
        bottom: false, // Allow content to scroll to the bottom of screen
        child: Column(
          children: [
            // Status bar colored area - same gradient as top bar
            Container(
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
              height: MediaQuery.of(context).padding.top,
            ),
            // Custom top bar matching Figma design
            _buildTopBar(context),
            // Tab bar for Nearby/Trending
            _buildTabBar(context),
            // Feed content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Nearby tab
                  _buildBody(feedState, locationState, theme),
                  // Following tab (under construction)
                  _buildUnderConstructionView(context),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 0, right: 10),
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: () => context.push(RoutePaths.createPost),
          backgroundColor: CupertinoColors.systemBlue,
          shape: const CircleBorder(),
          elevation: 4,
          child: const Icon(
            CupertinoIcons.add,
            color: CupertinoColors.white,
            size: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  /// Builds the custom top bar with profile, logo, and notification bell
  Widget _buildTopBar(BuildContext context) {
    final iconColor = CupertinoDynamicColor.resolve(
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile icon (left)
          GestureDetector(
            onTap: () {
              final userId = ref.read(currentUserProvider)?.id;
              if (userId != null) {
                context.push('/profile/$userId');
              }
            },
            onLongPress: () => _showLogoutSheet(context),
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
                CupertinoIcons.person_fill,
                size: 20,
                color: iconColor,
              ),
            ),
          ),

          // App logo (center) - using FlutterLogo as placeholder
          const SizedBox(width: 35, height: 35, child: FlutterLogo(size: 35)),

          // Notification bell (right)
          GestureDetector(
            onTap: () => context.push(RoutePaths.notifications),
            child: SizedBox(
              width: 35,
              height: 35,
              child: Icon(CupertinoIcons.bell_fill, size: 24, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the tab bar for Nearby/Trending
  Widget _buildTabBar(BuildContext context) {
    final activeColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBlue,
      context,
    );
    final inactiveColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Container(
      decoration: BoxDecoration(
        // Same gradient as the top bar
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.14, 0.67],
          colors: [
            _resolveColor(context, _cardBackgroundStart),
            _resolveColor(context, _cardBackgroundEnd),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.separator,
              context,
            ),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: activeColor,
        unselectedLabelColor: inactiveColor,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: activeColor,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Nearby'),
          Tab(text: 'Following'),
        ],
      ),
    );
  }

  Widget _buildBody(
    FeedState feedState,
    LocationState locationState,
    ThemeData theme,
  ) {
    // Show location permission request
    if (!locationState.hasPermission && !locationState.isLoading) {
      return _buildLocationPermissionView(theme);
    }

    // Show loading state
    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const FeedShimmer();
    }

    // Show error state
    if (feedState.error != null && feedState.posts.isEmpty) {
      return _buildErrorView(feedState.error!, theme);
    }

    // Show empty state
    if (feedState.posts.isEmpty) {
      return _buildEmptyView(theme);
    }

    // Show feed
    return CustomRefreshIndicator(
      onRefresh: () async {
        await ref.read(locationStateProvider.notifier).refreshLocation();
        await ref.read(feedStateProvider.notifier).refreshFeed();
      },
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == feedState.posts.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CupertinoActivityIndicator()),
              );
            }

            final post = feedState.posts[index];
            return PostCard(
              post: post,
              onTap: () => context.push('/post/${post.id}'),
              onLike: () {
                if (post.isLiked) {
                  ref.read(feedStateProvider.notifier).unlikePost(post.id);
                } else {
                  ref.read(feedStateProvider.notifier).likePost(post.id);
                }
              },
              onComment: () => context.push('/post/${post.id}'),
              onUserTap: () => context.push('/profile/${post.userId}'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationPermissionView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.location_slash_fill,
              size: 80,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBlue,
                context,
              ).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Location Access Required',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _resolveColor(context, _primaryText),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Geoloc needs your location to show posts from people near you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () {
                ref.read(locationStateProvider.notifier).requestPermission();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.location_fill, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Enable Location',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: () {
                ref.read(locationStateProvider.notifier).openAppSettings();
              },
              child: Text(
                'Open Settings',
                style: GoogleFonts.plusJakartaSans(
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.systemBlue,
                    context,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, ThemeData theme) {
    final errorColor = CupertinoDynamicColor.resolve(
      CupertinoColors.systemRed,
      context,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              size: 64,
              color: errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _resolveColor(context, _primaryText),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: () {
                ref.read(feedStateProvider.notifier).loadFeed();
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.refresh, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.compass,
              size: 80,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBlue,
                context,
              ).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts nearby',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _resolveColor(context, _primaryText),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share something in your area!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: () => context.push(RoutePaths.createPost),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.add, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Create Post',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderConstructionView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.hammer,
              size: 80,
              color: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBlue,
                context,
              ).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Still under construction',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.label,
                  context,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This feature is coming soon!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: CupertinoDynamicColor.resolve(
                  CupertinoColors.secondaryLabel,
                  context,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
