import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cache/feed_post_merge.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';

/// Profile state
class ProfileState {
  final User? user;
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingPosts;
  final bool isRefreshing;
  final bool isFollowLoading;
  final String? error;
  final bool hasMorePosts;
  final String? postsCursor;

  const ProfileState({
    this.user,
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingPosts = false,
    this.isRefreshing = false,
    this.isFollowLoading = false,
    this.error,
    this.hasMorePosts = true,
    this.postsCursor,
  });

  ProfileState copyWith({
    User? user,
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingPosts,
    bool? isRefreshing,
    bool? isFollowLoading,
    String? error,
    bool? hasMorePosts,
    String? postsCursor,
    bool clearError = false,
  }) {
    return ProfileState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingPosts: isLoadingPosts ?? this.isLoadingPosts,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isFollowLoading: isFollowLoading ?? this.isFollowLoading,
      error: clearError ? null : (error ?? this.error),
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      postsCursor: postsCursor ?? this.postsCursor,
    );
  }
}

/// Profile notifier for managing profile state
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ApiClient _apiClient;
  final String userId;

  ProfileNotifier(this._apiClient, this.userId) : super(const ProfileState());

  /// Load user profile and posts
  Future<void> loadProfile({bool force = false}) async {
    if (!force && state.user != null && state.posts.isNotEmpty) {
      await refreshProfile();
      return;
    }

    final showBackgroundRefresh = state.user != null || state.posts.isNotEmpty;
    state = state.copyWith(
      isLoading: !showBackgroundRefresh,
      isRefreshing: showBackgroundRefresh,
      clearError: true,
    );

    try {
      // Fetch user data
      final userResponse = await _apiClient.get(ApiEndpoints.getUser(userId));

      if (userResponse.statusCode == 200) {
        final userData = userResponse.data as Map<String, dynamic>;
        // Handle nested 'user' or 'data' field, or direct data
        final userJson =
            userData['user'] as Map<String, dynamic>? ??
            userData['data'] as Map<String, dynamic>? ??
            userData;
        final user = User.fromJson(userJson);
        state = state.copyWith(
          user: FeedPostMerge.mergeUser(user, state.user),
        );
      }

      // Fetch user posts
      await _loadPosts();

      state = state.copyWith(isLoading: false, isRefreshing: false);
    } catch (e) {
      if (state.user != null || state.posts.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: _getErrorMessage(e),
        );
        return;
      }
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
    }
  }

  /// Load user posts
  Future<void> _loadPosts({String? cursor}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.getUserPosts(userId),
        queryParameters: {'limit': 20, if (cursor != null) 'cursor': cursor},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Parse user info from response
        User? responseUser;
        if (data['user'] != null) {
          responseUser = User.fromJson(data['user'] as Map<String, dynamic>);
          // Update profile user if not already loaded
          if (state.user == null) {
            state = state.copyWith(user: responseUser);
          }
        }

        final postsJson =
            data['data'] as List<dynamic>? ??
            data['posts'] as List<dynamic>? ??
            [];

        // Parse posts and attach user as author
        final authorUser = responseUser ?? state.user;
        final posts = postsJson.map((json) {
          final post = Post.fromJson(json as Map<String, dynamic>);
          // Attach user as author if post doesn't have one
          if (post.author == null && authorUser != null) {
            return post.copyWith(author: authorUser);
          }
          return post;
        }).toList();

        final hasMore = data['has_more'] as bool? ?? false;
        final nextCursor = data['next_cursor'] as String?;

        if (cursor == null) {
          final merged = FeedPostMerge.mergeFeedPage(posts, state.posts);
          state = state.copyWith(
            posts: merged,
            hasMorePosts: hasMore,
            postsCursor: nextCursor,
          );
        } else {
          state = state.copyWith(
            posts: FeedPostMerge.appendUnique(state.posts, posts),
            hasMorePosts: hasMore,
            postsCursor: nextCursor,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Posts loading failed: $e');
      state = state.copyWith(isLoadingPosts: false);
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (state.isLoadingPosts || !state.hasMorePosts) return;

    state = state.copyWith(isLoadingPosts: true);
    await _loadPosts(cursor: state.postsCursor);
    state = state.copyWith(isLoadingPosts: false);
  }

  /// Refresh profile and posts
  Future<void> refreshProfile() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      // Fetch user data
      final userResponse = await _apiClient.get(ApiEndpoints.getUser(userId));

      if (userResponse.statusCode == 200) {
        final userData = userResponse.data as Map<String, dynamic>;
        // Handle nested 'user' or 'data' field, or direct data
        final userJson =
            userData['user'] as Map<String, dynamic>? ??
            userData['data'] as Map<String, dynamic>? ??
            userData;
        final user = User.fromJson(userJson);
        state = state.copyWith(
          user: FeedPostMerge.mergeUser(user, state.user),
        );
      }

      // Fetch fresh posts
      await _loadPosts();

      state = state.copyWith(isRefreshing: false);
    } catch (e) {
      state = state.copyWith(isRefreshing: false, error: _getErrorMessage(e));
    }
  }

  /// Follow or unfollow user
  Future<void> toggleFollow() async {
    if (state.user == null || state.isFollowLoading) return;

    final isCurrentlyFollowing = state.user!.isFollowing ?? false;

    // Optimistic update
    state = state.copyWith(
      isFollowLoading: true,
      user: state.user!.copyWith(
        isFollowing: !isCurrentlyFollowing,
        followersCount: state.user!.followersCount + (isCurrentlyFollowing ? -1 : 1),
      ),
    );

    try {
      if (isCurrentlyFollowing) {
        await _apiClient.delete(ApiEndpoints.unfollowUser(userId));
      } else {
        await _apiClient.post(ApiEndpoints.followUser(userId));
      }
      state = state.copyWith(isFollowLoading: false);
    } catch (e) {
      // Revert on failure
      state = state.copyWith(
        isFollowLoading: false,
        user: state.user!.copyWith(
          isFollowing: isCurrentlyFollowing,
          followersCount: state.user!.followersCount + (isCurrentlyFollowing ? 1 : -1),
        ),
        error: _getErrorMessage(e),
      );
    }
  }

  String _getErrorMessage(dynamic error) {
    return error.toString().replaceAll('Exception: ', '');
  }

  /// Sync a post after returning from detail (likes, comment counts, etc.).
  void updatePost(Post updatedPost) {
    state = state.copyWith(
      posts: state.posts
          .map(
            (post) => post.id == updatedPost.id
                ? FeedPostMerge.mergePost(updatedPost, post)
                : post,
          )
          .toList(),
    );
  }
}

/// Profile provider family - creates a provider for each userId
final profileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileState, String>((
      ref,
      userId,
    ) {
      final apiClient = ref.read(apiClientProvider);
      return ProfileNotifier(apiClient, userId);
    });
