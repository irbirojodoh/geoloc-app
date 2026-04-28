import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/routes.dart';
import '../../../core/cache/image_cache_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/hairline_divider.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/post_card.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/states/location_permission_prompt.dart';
import '../../widgets/wordmark.dart';

/// Main feed screen — old-money luxury aesthetic
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

  void _showLogoutSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.xxl,
          top: AppSpacing.xxl,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ACCOUNT',
              style: GoogleFonts.ptSerif(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: gold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              ref.read(currentUserProvider)?.email ?? 'Logged in',
              style: GoogleFonts.firaCode(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const HairlineDivider(),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                final userId = ref.read(currentUserProvider)?.id;
                if (userId != null) {
                  context.push('/profile/$userId');
                }
              },
              child: Text(
                'View Profile',
                style: GoogleFonts.plusJakartaSans(fontSize: 15, color: gold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(authStateProvider.notifier).logout();
              },
              child: Text(
                'Log Out',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedStateProvider);
    final locationState = ref.watch(locationStateProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gold = AppColors.gold(context);

    ref.listen<LocationState>(locationStateProvider, (previous, next) {
      if (previous?.position == null && next.position != null) {
        ref.read(feedStateProvider.notifier).loadFeed();
      }
    });

    return Scaffold(
      body: Column(
        children: [
          GeolocAppBar(
            titleWidget: const Wordmark(),
            leading: _buildProfileLeading(context),
            trailing: IconSquareButton(
              icon: Icons.notifications_outlined,
              iconColor: gold,
              semanticLabel: 'Notifications',
              tooltip: 'Notifications',
              onTap: () => context.push(RoutePaths.notifications),
            ),
          ),
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                bottom: BorderSide(color: cs.outline, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Nearby'),
                Tab(text: 'Following'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBody(feedState, locationState, theme),
                const EmptyState(
                  icon: Icons.construction_outlined,
                  title: 'Still under construction',
                  message: 'This feature is coming soon!',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: FloatingActionButton(
          onPressed: () => context.push(RoutePaths.createPost),
          backgroundColor: gold,
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.sharpAll),
          elevation: 0,
          tooltip: 'Create post',
          child: Icon(Icons.add, color: cs.onPrimary, size: AppIconSize.lg),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  /// Leading widget in the top bar — a 44pt avatar tap target.
  Widget _buildProfileLeading(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Builder(
      builder: (context) {
        final currentUser = ref.watch(currentUserProvider);
        final hasAvatar = currentUser?.profilePictureUrl != null;
        return Semantics(
          label: 'Profile (long-press for account menu)',
          button: true,
          child: GestureDetector(
            onTap: () {
              final userId = ref.read(currentUserProvider)?.id;
              if (userId != null) context.push('/profile/$userId');
            },
            onLongPress: () => _showLogoutSheet(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: AppTapTarget.iosMinimum,
              height: AppTapTarget.iosMinimum,
              alignment: Alignment.center,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.sharpAll,
                  border: Border.all(color: cs.outline, width: 1),
                ),
                child: hasAvatar
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: Builder(
                          builder: (context) {
                            final dpr =
                                MediaQuery.devicePixelRatioOf(context);
                            return CachedNetworkImage(
                              imageUrl: currentUser!.profilePictureUrl!,
                              fit: BoxFit.cover,
                              width: 34,
                              height: 34,
                              cacheManager: AvatarCacheManager.instance,
                              memCacheWidth: (34 * dpr).round(),
                              memCacheHeight: (34 * dpr).round(),
                              placeholder: (c, _) => Icon(
                                Icons.person_outlined,
                                size: 18,
                                color: AppColors.textMuted(c),
                              ),
                              errorWidget: (c, url, error) => Icon(
                                Icons.person_outlined,
                                size: 18,
                                color: AppColors.textMuted(c),
                              ),
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.person_outlined,
                        size: 18,
                        color: AppColors.textMuted(context),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    FeedState feedState,
    LocationState locationState,
    ThemeData theme,
  ) {
    if (!locationState.hasPermission && !locationState.isLoading) {
      return LocationPermissionPrompt(
        onRequest: () =>
            ref.read(locationStateProvider.notifier).requestPermission(),
        onOpenSettings: () =>
            ref.read(locationStateProvider.notifier).openAppSettings(),
      );
    }

    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const FeedShimmer();
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return ErrorState(
        message: feedState.error!,
        onRetry: () => ref.read(feedStateProvider.notifier).loadFeed(),
      );
    }

    if (feedState.posts.isEmpty) {
      return _buildEmptyView();
    }

    final gold = AppColors.gold(context);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(locationStateProvider.notifier).refreshLocation();
        await ref.read(feedStateProvider.notifier).refreshFeed();
      },
      color: gold,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == feedState.posts.length) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: gold,
                  ),
                ),
              );
            }

            final post = feedState.posts[index];
            return PostCard(
              post: post,
              onTap: () => context.push('/post/${post.id}'),
              onLike: () =>
                  ref.read(feedStateProvider.notifier).toggleLike(post.id),
              onComment: () => context.push('/post/${post.id}'),
              onUserTap: () => context.push('/profile/${post.userId}'),
            );
          },
        ),
      ),
    );
  }

  /// Empty-feed view: keep the [RefreshIndicator] wrapper so users can pull
  /// even when the list is empty.
  Widget _buildEmptyView() {
    final gold = AppColors.gold(context);
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(locationStateProvider.notifier).refreshLocation();
        await ref.read(feedStateProvider.notifier).refreshFeed();
      },
      color: gold,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: EmptyState(
                icon: Icons.explore_outlined,
                title: 'No posts nearby',
                message: 'Be the first to share something in your area!',
                actionLabel: 'CREATE POST',
                actionIcon: Icons.add,
                onAction: () => context.push(RoutePaths.createPost),
              ),
            ),
          );
        },
      ),
    );
  }
}
