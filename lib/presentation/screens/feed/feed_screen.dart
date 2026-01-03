import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/loading_shimmer.dart';

/// Main feed screen showing location-based posts
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

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
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Geoloc'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push(RoutePaths.search),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(RoutePaths.notifications),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'profile') {
                final userId = ref.read(currentUserProvider)?.id;
                if (userId != null) {
                  context.push('/profile/$userId');
                }
              } else if (value == 'logout') {
                await ref.read(authStateProvider.notifier).logout();
                if (mounted) {
                  context.go(RoutePaths.login);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(feedState, locationState, theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.createPost),
        child: const Icon(Icons.add),
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
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(locationStateProvider.notifier).refreshLocation();
        await ref.read(feedStateProvider.notifier).refreshFeed();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == feedState.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
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
              Icons.location_off,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Location Access Required',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Geoloc needs your location to show posts from people near you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(locationStateProvider.notifier).requestPermission();
              },
              icon: const Icon(Icons.location_on),
              label: const Text('Enable Location'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(locationStateProvider.notifier).openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(feedStateProvider.notifier).loadFeed();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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
              Icons.explore_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts nearby',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share something in your area!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(RoutePaths.createPost),
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
          ],
        ),
      ),
    );
  }
}
