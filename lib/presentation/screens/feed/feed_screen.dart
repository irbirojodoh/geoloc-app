import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/loading_shimmer.dart';
import '../../widgets/post_card.dart';
import '../../widgets/post_overflow_menu_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';
import '../../widgets/states/location_permission_prompt.dart';

/// Material 3 feed screen.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFeed());
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
    super.dispose();
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    final currentUser = ref.read(currentUserProvider);
    final textTheme = Theme.of(context).textTheme;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.35,
            minChildSize: 0.25,
            maxChildSize: 0.6,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  ListTile(
                    title: Text('Account', style: textTheme.titleLarge),
                    subtitle: Text(currentUser?.email ?? ''),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      if (currentUser != null) {
                        context.push('/profile/${currentUser.id}');
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(RoutePaths.settings);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authStateProvider.notifier).logout();
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feedState = ref.watch(feedStateProvider);
    final locationState = ref.watch(locationStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    ref.listen<LocationState>(locationStateProvider, (previous, next) {
      if (previous?.position == null && next.position != null) {
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
          onAction: () => context.push(RoutePaths.createPost),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(locationStateProvider.notifier).refreshLocation();
          await ref.read(feedStateProvider.notifier).refreshFeed();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar.medium(
              backgroundColor: colorScheme.surface,
              title: Text(
                'Home',
                style: textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push(RoutePaths.notifications),
                  icon: const Icon(Icons.notifications_outlined),
                ),
                IconButton(
                  tooltip: 'Account options',
                  onPressed: () => _showAccountSheet(context),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList.builder(
                itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == feedState.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = feedState.posts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: post,
                      headerTrailing: PostOverflowMenuButton(post: post),
                      onTap: () => context.push('/post/${post.id}'),
                      onLike: () =>
                          ref.read(feedStateProvider.notifier).toggleLike(post.id),
                      onComment: () => context.push('/post/${post.id}'),
                      onUserTap: () => context.push('/profile/${post.userId}'),
                    ),
                  );
                }
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
