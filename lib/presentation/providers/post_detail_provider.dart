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

  /// Toggle like state for the current post with optimistic UI update
  Future<void> togglePostLike() async {
    if (state.post == null) return;

    final post = state.post!;
    final wasLiked = post.isLiked;
    final newLikeState = !wasLiked;

    // Optimistic update
    state = state.copyWith(
      post: post.copyWith(
        isLiked: newLikeState,
        likeCount: post.likeCount + (newLikeState ? 1 : -1),
      ),
    );

    try {
      final response = await _apiClient.post(
        ApiEndpoints.togglePostLike(postId),
        data: {'like': newLikeState},
      );

      if (response.statusCode == 200) {
        // Sync with server state
        final data = response.data as Map<String, dynamic>;
        final serverLiked = data['is_liked'] as bool;
        final serverCount = data['like_count'] as int;

        state = state.copyWith(
          post: state.post!.copyWith(
            isLiked: serverLiked,
            likeCount: serverCount,
          ),
        );
      } else {
        // Revert on non-200 response
        state = state.copyWith(
          post: state.post!.copyWith(
            isLiked: wasLiked,
            likeCount: state.post!.likeCount + (wasLiked ? 1 : -1),
          ),
        );
      }
    } catch (e) {
      // Revert on failure
      state = state.copyWith(
        post: state.post!.copyWith(
          isLiked: wasLiked,
          likeCount: state.post!.likeCount + (wasLiked ? 1 : -1),
        ),
      );
    }
  }

  /// Toggle like state for a comment with optimistic UI update
  Future<void> toggleCommentLike(String commentId) async {
    final commentIndex = state.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = state.comments[commentIndex];
    final wasLiked = comment.isLiked;
    final newLikeState = !wasLiked;

    // Optimistic update
    _updateCommentLikeState(commentId, newLikeState);

    try {
      final response = await _apiClient.post(
        ApiEndpoints.toggleCommentLike(commentId),
        data: {'like': newLikeState},
      );

      if (response.statusCode == 200) {
        // Sync with server state
        final data = response.data as Map<String, dynamic>;
        final serverLiked = data['is_liked'] as bool;
        final serverCount = data['like_count'] as int;

        _syncCommentLikeState(commentId, serverLiked, serverCount);
      } else {
        // Revert on non-200 response
        _updateCommentLikeState(commentId, wasLiked);
      }
    } catch (e) {
      // Revert on failure
      _updateCommentLikeState(commentId, wasLiked);
    }
  }

  /// Update comment like state locally (for optimistic updates)
  void _updateCommentLikeState(String commentId, bool isLiked) {
    final updatedComments = _updateCommentsRecursively(
      state.comments,
      commentId,
      (comment) => comment.copyWith(
        isLiked: isLiked,
        likeCount: comment.likeCount + (isLiked ? 1 : -1),
      ),
    );
    state = state.copyWith(comments: updatedComments);
  }

  /// Sync comment like state with server response
  void _syncCommentLikeState(String commentId, bool isLiked, int likeCount) {
    final updatedComments = _updateCommentsRecursively(
      state.comments,
      commentId,
      (comment) => comment.copyWith(isLiked: isLiked, likeCount: likeCount),
    );
    state = state.copyWith(comments: updatedComments);
  }

  /// Recursively update a comment in the tree (handles nested replies)
  List<Comment> _updateCommentsRecursively(
    List<Comment> comments,
    String commentId,
    Comment Function(Comment) updater,
  ) {
    return comments.map((comment) {
      if (comment.id == commentId) {
        return updater(comment);
      }
      if (comment.replies.isNotEmpty) {
        return comment.copyWith(
          replies: _updateCommentsRecursively(
            comment.replies,
            commentId,
            updater,
          ),
        );
      }
      return comment;
    }).toList();
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
