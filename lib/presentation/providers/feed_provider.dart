import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../data/models/post.dart';
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

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.error,
    this.radiusKm = AppConfig.defaultFeedRadiusKm,
    this.cursor,
  });

  FeedState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    String? error,
    double? radiusKm,
    String? cursor,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      radiusKm: radiusKm ?? this.radiusKm,
      cursor: cursor ?? this.cursor,
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

  /// Load initial feed
  Future<void> loadFeed() async {
    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      state = state.copyWith(
        isLoading: false,
        error: 'Location not available. Please enable location services.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      state = state.copyWith(
        posts: result.posts,
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  /// Refresh feed (pull to refresh)
  Future<void> refreshFeed() async {
    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      return;
    }

    state = state.copyWith(isRefreshing: true, error: null);

    try {
      final result = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      state = state.copyWith(
        posts: result.posts,
        isRefreshing: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false, error: _getErrorMessage(e));
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.cursor == null) return;

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

      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
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
        return updatedPost;
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
    state = state.copyWith(error: null);
  }
}
