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
      final posts = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      state = state.copyWith(
        posts: posts,
        isLoading: false,
        hasMore: posts.length >= AppConfig.defaultPageSize,
        cursor: posts.isNotEmpty ? posts.last.id : null,
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
      final posts = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
      );

      state = state.copyWith(
        posts: posts,
        isRefreshing: false,
        hasMore: posts.length >= AppConfig.defaultPageSize,
        cursor: posts.isNotEmpty ? posts.last.id : null,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false, error: _getErrorMessage(e));
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    final locationState = _ref.read(locationStateProvider);

    if (!locationState.hasLocation) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final posts = await _fetchPosts(
        latitude: locationState.latitude!,
        longitude: locationState.longitude!,
        cursor: state.cursor,
      );

      state = state.copyWith(
        posts: [...state.posts, ...posts],
        isLoading: false,
        hasMore: posts.length >= AppConfig.defaultPageSize,
        cursor: posts.isNotEmpty ? posts.last.id : state.cursor,
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

  /// Fetch posts from API
  Future<List<Post>> _fetchPosts({
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
      final postsJson = data['posts'] as List<dynamic>? ?? [];
      return postsJson
          .map((json) => Post.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Failed to load feed');
  }

  /// Like a post
  Future<void> likePost(String postId) async {
    // Optimistic update
    _updatePostLike(postId, true);

    try {
      await _apiClient.post(ApiEndpoints.likePost(postId));
    } catch (e) {
      // Revert on failure
      _updatePostLike(postId, false);
    }
  }

  /// Unlike a post
  Future<void> unlikePost(String postId) async {
    // Optimistic update
    _updatePostLike(postId, false);

    try {
      await _apiClient.delete(ApiEndpoints.unlikePost(postId));
    } catch (e) {
      // Revert on failure
      _updatePostLike(postId, true);
    }
  }

  /// Update post like state locally
  void _updatePostLike(String postId, bool isLiked) {
    final updatedPosts = state.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(
          isLiked: isLiked,
          likeCount: post.likeCount + (isLiked ? 1 : -1),
        );
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
