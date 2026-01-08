import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../data/models/post.dart';
import '../../data/models/comment.dart';
import '../../data/models/user.dart';

/// Post detail state
class PostDetailState {
  final Post? post;
  final List<Comment> comments;
  final bool isLoading;
  final bool isSubmittingComment;
  final String? error;

  const PostDetailState({
    this.post,
    this.comments = const [],
    this.isLoading = false,
    this.isSubmittingComment = false,
    this.error,
  });

  PostDetailState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? isLoading,
    bool? isSubmittingComment,
    String? error,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      error: error,
    );
  }
}

/// Post detail notifier
class PostDetailNotifier extends StateNotifier<PostDetailState> {
  final ApiClient _apiClient;
  final String postId;

  PostDetailNotifier(this._apiClient, this.postId)
    : super(const PostDetailState()) {
    loadPost();
    loadComments();
  }

  /// Load post details
  Future<void> loadPost() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiClient.get('${ApiEndpoints.posts}/$postId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Handle mapped response: { "post": {...}, "user": {...} }
        final postJson = data['post'] as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;

        var post = Post.fromJson(postJson);
        final user = User.fromJson(userJson);

        // Attach author to post
        post = post.copyWith(author: user);

        state = state.copyWith(post: post, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to load post');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load comments for the post
  Future<void> loadComments() async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.posts}/$postId/comments',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final commentsList =
            (data['comments'] as List<dynamic>?)
                ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        state = state.copyWith(comments: commentsList);
      }
    } catch (e) {
      // Siltently fail for comments or show error if needed
      print('Error loading comments: $e');
    }
  }

  /// Submit a new comment
  Future<bool> submitComment(String content) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSubmittingComment: true);

    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.posts}/$postId/comments',
        data: {'content': content},
      );

      if (response.statusCode == 201) {
        // Reload comments to show the new one
        await loadComments();
        // Increment comment count on post
        if (state.post != null) {
          state = state.copyWith(
            post: state.post!.copyWith(
              commentCount: state.post!.commentCount + 1,
            ),
          );
        }
        state = state.copyWith(isSubmittingComment: false);
        return true;
      } else {
        state = state.copyWith(isSubmittingComment: false);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isSubmittingComment: false);
      return false;
    }
  }
}

/// Provider for specific post detail
final postDetailProvider =
    StateNotifierProvider.family<PostDetailNotifier, PostDetailState, String>((
      ref,
      postId,
    ) {
      final apiClient = ref.watch(apiClientProvider);
      return PostDetailNotifier(apiClient, postId);
    });
