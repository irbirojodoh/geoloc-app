import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/post.dart';
import '../../helpers/open_post_detail.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/states/location_permission_prompt.dart';
import '../../widgets/top_bar_backdrop.dart';

/// Material 3 feed screen.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFeed());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(locationStateProvider).hasLocation) {
      ref.read(feedStateProvider.notifier).refreshIfStale();
    }
  }

  Future<void> _initializeFeed() async {
    final locationState = ref.read(locationStateProvider);

    if (!locationState.hasLocation && !locationState.isLoading) {
      await ref.read(locationStateProvider.notifier).requestPermission();
    }

    if (!ref.read(locationStateProvider).hasLocation) return;

    final feedNotifier = ref.read(feedStateProvider.notifier);
    if (ref.read(feedStateProvider).hasCachedContent) {
      await feedNotifier.refreshIfStale();
      return;
    }
    await feedNotifier.loadFeed();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedStateProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(feedStateProvider);
    final locationState = ref.watch(locationStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen<LocationState>(locationStateProvider, (previous, next) {
      if (previous?.position == null &&
          next.position != null &&
          !ref.read(feedStateProvider).hasCachedContent) {
        ref.read(feedStateProvider.notifier).loadFeed();
      }
    });

    if (!locationState.hasPermission && !locationState.isLoading) {
      return Scaffold(
        body: LocationPermissionPrompt(
          onRequest: () =>
              ref.read(locationStateProvider.notifier).requestPermission(),
          onOpenSettings: () =>
              ref.read(locationStateProvider.notifier).openAppSettings(),
        ),
      );
    }

    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const Scaffold(body: FeedShimmer());
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return Scaffold(
        body: ErrorState(
          message: feedState.error!,
          onRetry: () => ref.read(feedStateProvider.notifier).loadFeed(),
        ),
      );
    }

    if (feedState.posts.isEmpty) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.explore_outlined,
          title: 'No posts nearby',
          message: 'Be the first to post in your area.',
          actionLabel: 'Post',
          onAction: () {
            // Home(0) -> Create post(5): slide from right.
            setShellNavTransitionDirection(1);
            context.push(RoutePaths.createPost);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
        strokeWidth: 2.2,
        elevation: 1,
        edgeOffset: 86,
        displacement: 28,
        onRefresh: () async {
          await ref.read(locationStateProvider.notifier).refreshLocation();
          await ref.read(feedStateProvider.notifier).refreshFeed();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  pinned: true,
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
                  title: Text(
                    'Near you',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  actions: const [],
                ),
                if (feedState.isFromCache)
                  SliverToBoxAdapter(
                    child: MaterialBanner(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      content: Text(
                        'Showing saved posts — connect to refresh images',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      leading: Icon(
                        Icons.cloud_off_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(feedStateProvider.notifier)
                                .refreshFeed();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      96,
                    ),
                  sliver: SliverList.builder(
                    itemCount:
                        feedState.posts.length + (feedState.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == feedState.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final post = feedState.posts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          headerTrailing: PostOverflowMenuButton(post: post),
                          onTap: () {
                            // Home(0) -> Post detail(0.5): slide from right.
                            setShellNavTransitionDirection(1);
                            openPostDetail(context, ref, post).then((value) {
                              if (value is Post) {
                                ref.read(feedStateProvider.notifier).updatePost(value);
                              }
                            });
                          },
                          onLike: () => ref
                              .read(feedStateProvider.notifier)
                              .toggleLike(post.id),
                          onComment: () {
                            setShellNavTransitionDirection(1);
                            openPostDetail(context, ref, post).then((value) {
                              if (value is Post) {
                                ref.read(feedStateProvider.notifier).updatePost(value);
                              }
                            });
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

  @override
  bool get wantKeepAlive => true;
}
