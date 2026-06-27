import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/cache/feed_post_merge.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/post.dart';
import '../../../services/feed_cache_service.dart';
import '../../../services/media_service.dart';
import 'location_provider.dart';

/// Feed state
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? error;
  final double radiusKm;
  final String? cursor;
  final bool isFromCache;
  final DateTime? lastFetchedAt;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.error,
    this.radiusKm = AppConfig.defaultFeedRadiusKm,
    this.cursor,
    this.isFromCache = false,
    this.lastFetchedAt,
  });

  bool get hasCachedContent => posts.isNotEmpty;

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? error,
    double? radiusKm,
    String? cursor,
    bool? isFromCache,
    DateTime? lastFetchedAt,
    bool clearError = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      radiusKm: radiusKm ?? this.radiusKm,
      cursor: cursor ?? this.cursor,
      isFromCache: isFromCache ?? this.isFromCache,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }
}

/// Feed state notifier provider
final feedStateProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(ref.watch(apiClientProvider), ref);
});

/// Feed notifier for managing feed state
class FeedNotifier extends StateNotifier<FeedState> {
  final ApiClient _apiClient;
  final Ref _ref;

  FeedNotifier(this._apiClient, this._ref) : super(const FeedState());

  FeedCacheService get _feedCache => _ref.read(feedCacheServiceProvider);
  MediaService get _mediaService => _ref.read(mediaServiceProvider);

  /// Show cached feed instantly, then fetch fresh data in the background.
  Future<void> loadFeed({bool force = false}) async {
    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      state = state.copyWith(
        isLoading: false,
        error: 'Location not available. Please enable location services.',
      );
      return;
    }

    if (!force && state.hasCachedContent) {
      await refreshIfStale();
      return;
    }

    if (!state.hasCachedContent) {
      await _showDiskCacheIfAvailable();
    }

    final showBackgroundRefresh = state.hasCachedContent;
    state = state.copyWith(
      isLoading: !showBackgroundRefresh,
      isRefreshing: showBackgroundRefresh,
      clearError: true,
      isFromCache: showBackgroundRefresh ? state.isFromCache : false,
    );

    try {
      final result = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      final merged = FeedPostMerge.mergeFeedPage(result.posts, state.posts);

      await _persistFeed(
        posts: merged,
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );

      state = state.copyWith(
        posts: merged,
        isLoading: false,
        isRefreshing: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
        isFromCache: false,
        lastFetchedAt: DateTime.now(),
      );
    } catch (e) {
      if (state.hasCachedContent) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: _getErrorMessage(e),
        );
        return;
      }
      await _loadFromCacheOrError(e, isLoading: true);
    }
  }

  /// Pull-to-refresh — keeps visible posts and merges updates in place.
  Future<void> refreshFeed() async {
    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      return;
    }

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final result = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      final merged = FeedPostMerge.mergeFeedPage(result.posts, state.posts);

      await _persistFeed(
        posts: merged,
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );

      state = state.copyWith(
        posts: merged,
        isRefreshing: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
        isFromCache: false,
        lastFetchedAt: DateTime.now(),
      );
    } catch (e) {
      if (state.hasCachedContent) {
        state = state.copyWith(
          isRefreshing: false,
          error: _getErrorMessage(e),
        );
        return;
      }
      await _loadFromCacheOrError(e, isRefreshing: true);
    }
  }

  /// Background refresh used on app resume — skipped when data is still fresh.
  Future<void> refreshIfStale({
    Duration maxAge = AppConfig.feedRefreshTtl,
    bool force = false,
  }) async {
    if (!force &&
        state.lastFetchedAt != null &&
        DateTime.now().difference(state.lastFetchedAt!) < maxAge) {
      return;
    }

    if (!state.hasCachedContent) {
      await loadFeed(force: true);
      return;
    }

    await refreshFeed();
  }

  /// Load more posts (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || state.isRefreshing || !state.hasMore) return;
    if (state.cursor == null) return;

    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final result = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
        cursor: state.cursor,
      );

      final mergedPosts = FeedPostMerge.appendUnique(state.posts, result.posts);

      await _persistFeed(
        posts: mergedPosts,
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );

      state = state.copyWith(
        posts: mergedPosts,
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
        isFromCache: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  /// Change feed radius
  Future<void> setRadius(double radiusKm) async {
    state = state.copyWith(radiusKm: radiusKm);
    await refreshFeed();
  }

  Future<void> _showDiskCacheIfAvailable() async {
    try {
      final cached = await _feedCache.loadFeed();
      if (cached == null || cached.posts.isEmpty) return;

      final hydrated = await _mediaService.hydratePostsMediaUrls(cached.posts);
      state = state.copyWith(
        posts: hydrated,
        hasMore: cached.hasMore,
        cursor: cached.cursor,
        isFromCache: true,
      );
    } catch (_) {
      // Ignore cache read failures and fall back to network.
    }
  }

  Future<void> _persistFeed({
    required List<Post> posts,
    required double latitude,
    required double longitude,
    required bool hasMore,
    String? cursor,
  }) async {
    try {
      await _feedCache.saveFeed(
        posts: posts,
        latitude: latitude,
        longitude: longitude,
        radiusKm: state.radiusKm,
        cursor: cursor,
        hasMore: hasMore,
      );
    } catch (_) {
      // Cache write failure should not block the feed.
    }
  }

  Future<void> _loadFromCacheOrError(
    dynamic error, {
    bool isLoading = false,
    bool isRefreshing = false,
  }) async {
    try {
      final cached = await _feedCache.loadFeed();
      if (cached != null && cached.posts.isNotEmpty) {
        final hydrated = await _mediaService.hydratePostsMediaUrls(
          cached.posts,
        );
        state = state.copyWith(
          posts: hydrated,
          isLoading: false,
          isRefreshing: false,
          hasMore: cached.hasMore,
          cursor: cached.cursor,
          clearError: true,
          isFromCache: true,
        );
        return;
      }
    } catch (_) {
      // Fall through to network error.
    }

    state = state.copyWith(
      isLoading: isLoading ? false : state.isLoading,
      isRefreshing: isRefreshing ? false : state.isRefreshing,
      error: _getErrorMessage(error),
    );
  }

  /// Fetch posts from API with cursor-based pagination
  /// Returns a record containing posts, hasMore flag, and next cursor
  Future<({List<Post> posts, bool hasMore, String? nextCursor})> _fetchPosts({
    required double latitude,
    required double longitude,
    String? cursor,
  }) async {
    final response = await _apiClient.get(
      ApiEndpoints.feed,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': state.radiusKm,
        'limit': AppConfig.defaultPageSize,
        if (cursor != null) 'cursor': cursor,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final postsJson =
          data['data'] as List<dynamic>? ??
          data['posts'] as List<dynamic>? ??
          [];
      final posts = postsJson
          .map((json) => Post.fromJson(json as Map<String, dynamic>))
          .toList();

      for (final post in posts) {
        for (final url in post.mediaUrls) {
          _mediaService.cache.seedFromPresignedUrl(url);
        }
        final avatarUrl = post.author?.profilePictureUrl;
        if (avatarUrl != null) {
          _mediaService.cache.seedFromPresignedUrl(avatarUrl);
        }
      }

      // Read pagination info from response
      final hasMore = data['has_more'] as bool? ?? false;
      final nextCursor = data['next_cursor'] as String?;

      return (posts: posts, hasMore: hasMore, nextCursor: nextCursor);
    }

    throw Exception('Failed to load feed');
  }

  /// Toggle like state for a post with optimistic UI update
  ///
  /// Immediately updates UI, then calls API in background.
  /// Reverts if API call fails.
  Future<void> toggleLike(String postId) async {
    // Find current post to get its state
    final postIndex = state.posts.indexWhere((p) => p.id == postId);
    if (postIndex == -1) return;

    final post = state.posts[postIndex];
    final wasLiked = post.isLiked;
    final newLikeState = !wasLiked;

    // Optimistic update - immediately show the change
    _updatePostLikeState(postId, newLikeState);

    try {
      // Call the toggle-like endpoint with desired state
      final response = await _apiClient.post(
        ApiEndpoints.togglePostLike(postId),
        data: {'like': newLikeState},
      );

      if (response.statusCode == 200) {
        // Sync with server state to ensure consistency
        final data = response.data as Map<String, dynamic>;
        final serverLiked = data['is_liked'] as bool;
        final serverCount = data['like_count'] as int;

        // Update with server's authoritative state
        _syncPostLikeState(postId, serverLiked, serverCount);
      } else {
        // Revert on non-200 response
        _updatePostLikeState(postId, wasLiked);
      }
    } catch (e) {
      // Revert on failure
      _updatePostLikeState(postId, wasLiked);
    }
  }

  /// Update post like state locally (optimistic update)
  void _updatePostLikeState(String postId, bool isLiked) {
    final updatedPosts = state.posts.map((post) {
      if (post.id == postId) {
        final currentLiked = post.isLiked;
        if (currentLiked == isLiked) return post; // No change needed

        return post.copyWith(
          isLiked: isLiked,
          likeCount: post.likeCount + (isLiked ? 1 : -1),
        );
      }
      return post;
    }).toList();

    state = state.copyWith(posts: updatedPosts);
  }

  /// Sync post like state with server response
  void _syncPostLikeState(String postId, bool isLiked, int likeCount) {
    final updatedPosts = state.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(isLiked: isLiked, likeCount: likeCount);
      }
      return post;
    }).toList();

    state = state.copyWith(posts: updatedPosts);
  }

  /// Update a post in the feed (used for syncing state from post detail)
  void updatePost(Post updatedPost) {
    final updatedPosts = state.posts.map((post) {
      if (post.id == updatedPost.id) {
        return FeedPostMerge.mergePost(updatedPost, post);
      }
      return post;
    }).toList();

    state = state.copyWith(posts: updatedPosts);
  }

  /// Add a new post to the top of the feed
  void addPost(Post post) {
    state = state.copyWith(posts: [post, ...state.posts]);
  }

  /// Remove a post from the feed
  void removePost(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );
  }

  /// Remove every post authored by [userId] (after block/mute)
  void removePostsByAuthor(String userId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.userId != userId).toList(),
    );
  }

  /// Get error message from exception
  String _getErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError) {
        return 'No internet connection';
      }
      return e.message ?? 'Network error';
    }
    return e.toString();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
