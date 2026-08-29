import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/cache/feed_post_merge.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/username_rewrite.dart';
import '../../data/models/post.dart';
import '../../data/models/comment.dart';
import '../../data/models/user.dart';
import 'post_preview_cache.dart';
import '../../../core/logging/app_logger.dart';

List<Comment> _filterCommentsWithoutUser(List<Comment> list, String userId) {
  return list
      .where((c) => c.userId != userId)
      .map(
        (c) => c.copyWith(
          replies: _filterCommentsWithoutUser(c.replies, userId),
        ),
      )
      .toList();
}

Comment? _findCommentById(List<Comment> list, String id) {
  for (final c in list) {
    if (c.id == id) return c;
    final nested = _findCommentById(c.replies, id);
    if (nested != null) return nested;
  }
  return null;
}

List<Comment> _mergeRepliesIntoThread(
  List<Comment> list,
  String commentId,
  List<Comment> newReplies,
  bool hasMore,
  String? nextCursor,
) {
  return list.map((c) {
    if (c.id == commentId) {
      return c.copyWith(
        replies: [...c.replies, ...newReplies],
        hasMoreReplies: hasMore,
        repliesNextCursor: nextCursor,
        clearRepliesNextCursor: !hasMore,
      );
    }
    if (c.replies.isNotEmpty) {
      return c.copyWith(
        replies: _mergeRepliesIntoThread(
          c.replies,
          commentId,
          newReplies,
          hasMore,
          nextCursor,
        ),
      );
    }
    return c;
  }).toList();
}

List<Comment> _updateCommentInTree(
  List<Comment> list,
  String commentId,
  Comment Function(Comment) updater,
) {
  return list.map((c) {
    if (c.id == commentId) {
      return updater(c);
    }
    if (c.replies.isNotEmpty) {
      return c.copyWith(
        replies: _updateCommentInTree(c.replies, commentId, updater),
      );
    }
    return c;
  }).toList();
}

/// Post detail state
class PostDetailState {
  final Post? post;
  final List<Comment> comments;
  final bool isLoading;
  final bool isSubmittingComment;
  final String? error;

  final bool commentsHasMore;
  final String? commentsNextCursor;
  final bool isLoadingMoreComments;
  final Set<String> loadingMoreRepliesIds;

  const PostDetailState({
    this.post,
    this.comments = const [],
    this.isLoading = false,
    this.isSubmittingComment = false,
    this.error,
    this.commentsHasMore = false,
    this.commentsNextCursor,
    this.isLoadingMoreComments = false,
    this.loadingMoreRepliesIds = const {},
  });

  PostDetailState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? isLoading,
    bool? isSubmittingComment,
    String? error,
    bool? commentsHasMore,
    String? commentsNextCursor,
    bool clearCommentsNextCursor = false,
    bool? isLoadingMoreComments,
    Set<String>? loadingMoreRepliesIds,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSubmittingComment: isSubmittingComment ?? this.isSubmittingComment,
      error: error,
      commentsHasMore: commentsHasMore ?? this.commentsHasMore,
      commentsNextCursor: clearCommentsNextCursor
          ? null
          : (commentsNextCursor ?? this.commentsNextCursor),
      isLoadingMoreComments: isLoadingMoreComments ?? this.isLoadingMoreComments,
      loadingMoreRepliesIds:
          loadingMoreRepliesIds ?? this.loadingMoreRepliesIds,
    );
  }
}

/// Post detail notifier
class PostDetailNotifier extends StateNotifier<PostDetailState> {
  final ApiClient _apiClient;
  final Ref _ref;
  final String postId;

  PostDetailNotifier(this._apiClient, this._ref, this.postId)
      : super(PostDetailState(post: findPostForDetail(_ref, postId))) {
    loadPost();
    loadComments();
  }

  /// Load post details — uses preview data instantly, refreshes in background.
  Future<void> loadPost() async {
    final hasPreview = state.post != null;
    if (!hasPreview) {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final response = await _apiClient.get('${ApiEndpoints.posts}/$postId');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        AppLogger.debug(
          '📍 [GET /posts/:id] envelopeKeys=${data.keys.toList()}',
        );

        final postJson = data['post'] as Map<String, dynamic>;
        final userJson = data['user'] as Map<String, dynamic>;

        var post = Post.fromJson(postJson);
        final user = User.fromJson(userJson);

        post = FeedPostMerge.mergePost(
          post.copyWith(author: user),
          state.post,
        );

        _ref.read(postPreviewCacheProvider.notifier).seed(post);

        state = state.copyWith(post: post, isLoading: false);
      } else if (!hasPreview) {
        state = state.copyWith(isLoading: false, error: 'Failed to load post');
      }
    } catch (e) {
      if (!hasPreview) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// Initial / pull-to-refresh: replace the first page.
  Future<void> loadComments() async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.getComments(postId),
        queryParameters: {
          'limit': AppConfig.defaultPageSize,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawList =
            data['data'] as List<dynamic>? ??
            data['comments'] as List<dynamic>? ??
            [];
        final totalCount = (data['total_count'] as num?)?.toInt();
        final commentsList = rawList
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();

        final hasMore = data['has_more'] as bool? ?? false;
        final next = data['next_cursor'] as String?;

        state = state.copyWith(
          comments: commentsList,
          commentsHasMore: hasMore,
          commentsNextCursor: hasMore ? next : null,
          clearCommentsNextCursor: !hasMore,
          isLoadingMoreComments: false,
          post: (state.post != null && totalCount != null)
              ? state.post!.copyWith(commentCount: totalCount)
              : state.post,
        );
      }
    } catch (e) {
      AppLogger.debug('Error loading comments: $e');
    }
  }

  /// Infinite scroll — next top-level page.
  Future<void> loadMoreComments() async {
    if (!state.commentsHasMore ||
        state.isLoadingMoreComments ||
        state.commentsNextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMoreComments: true);

    try {
      final response = await _apiClient.get(
        ApiEndpoints.getComments(postId),
        queryParameters: {
          'limit': AppConfig.defaultPageSize,
          'cursor': state.commentsNextCursor,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawList =
            data['data'] as List<dynamic>? ??
            data['comments'] as List<dynamic>? ??
            [];
        final page = rawList
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();

        final hasMore = data['has_more'] as bool? ?? false;
        final next = data['next_cursor'] as String?;

        final existingIds = state.comments.map((c) => c.id).toSet();
        final merged = [
          ...state.comments,
          ...page.where((c) => !existingIds.contains(c.id)),
        ];

        state = state.copyWith(
          comments: merged,
          commentsHasMore: hasMore,
          commentsNextCursor: hasMore ? next : null,
          clearCommentsNextCursor: !hasMore,
          isLoadingMoreComments: false,
        );
      } else {
        state = state.copyWith(isLoadingMoreComments: false);
      }
    } catch (e) {
      AppLogger.debug('Error loading more comments: $e');
      state = state.copyWith(isLoadingMoreComments: false);
    }
  }

  /// Older replies for a thread (GET /comments/:id/replies).
  Future<void> loadMoreReplies(String commentId) async {
    final parent = _findCommentById(state.comments, commentId);
    if (parent == null ||
        !parent.hasMoreReplies ||
        state.loadingMoreRepliesIds.contains(commentId)) {
      return;
    }

    state = state.copyWith(
      loadingMoreRepliesIds: {...state.loadingMoreRepliesIds, commentId},
    );

    try {
      final qp = <String, dynamic>{
        'limit': 10,
        if (parent.repliesNextCursor != null)
          'cursor': parent.repliesNextCursor,
      };

      final response = await _apiClient.get(
        ApiEndpoints.getCommentReplies(commentId),
        queryParameters: qp,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final rawList = data['data'] as List<dynamic>? ?? [];
        final chunk = rawList
            .map((e) => Comment.fromJson(e as Map<String, dynamic>))
            .toList();
        final hasMore = data['has_more'] as bool? ?? false;
        final next = data['next_cursor'] as String?;

        final updated = _mergeRepliesIntoThread(
          state.comments,
          commentId,
          chunk,
          hasMore,
          next,
        );

        state = state.copyWith(
          comments: updated,
          loadingMoreRepliesIds: Set.from(state.loadingMoreRepliesIds)
            ..remove(commentId),
        );
      } else {
        state = state.copyWith(
          loadingMoreRepliesIds: Set.from(state.loadingMoreRepliesIds)
            ..remove(commentId),
        );
      }
    } catch (e) {
      AppLogger.debug('Error loading replies: $e');
      state = state.copyWith(
        loadingMoreRepliesIds: Set.from(state.loadingMoreRepliesIds)
          ..remove(commentId),
      );
    }
  }

  /// Top-level comment.
  Future<bool> submitComment(String content) async {
    if (content.trim().isEmpty) return false;

    final previousCount = state.post?.commentCount ?? 0;
    state = state.copyWith(
      isSubmittingComment: true,
      post: state.post?.copyWith(commentCount: previousCount + 1),
    );

    try {
      final response = await _apiClient.post(
        ApiEndpoints.addComment(postId),
        data: {'content': content.trim()},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await loadComments();
        state = state.copyWith(isSubmittingComment: false);
        return true;
      }
      state = state.copyWith(
        isSubmittingComment: false,
        post: state.post?.copyWith(commentCount: previousCount),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmittingComment: false,
        post: state.post?.copyWith(commentCount: previousCount),
      );
      return false;
    }
  }

  /// Nested reply under [parentCommentId].
  Future<bool> submitReply(String parentCommentId, String content) async {
    if (content.trim().isEmpty) return false;

    final previousCount = state.post?.commentCount ?? 0;
    state = state.copyWith(
      isSubmittingComment: true,
      post: state.post?.copyWith(commentCount: previousCount + 1),
    );

    try {
      final response = await _apiClient.post(
        ApiEndpoints.replyToComment(parentCommentId),
        data: {'content': content.trim()},
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await loadComments();
        state = state.copyWith(isSubmittingComment: false);
        return true;
      }
      state = state.copyWith(
        isSubmittingComment: false,
        post: state.post?.copyWith(commentCount: previousCount),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmittingComment: false,
        post: state.post?.copyWith(commentCount: previousCount),
      );
      return false;
    }
  }

  /// PUT /comments/:id
  Future<bool> editComment(String commentId, String newContent) async {
    final trimmed = newContent.trim();
    if (trimmed.isEmpty) return false;

    try {
      final response = await _apiClient.put(
        ApiEndpoints.updateComment(commentId),
        data: {'content': trimmed},
      );

      if (response.statusCode == 200) {
        final body = response.data;
        DateTime? serverUpdatedAt;
        String resolvedContent = trimmed;

        if (body is Map<String, dynamic>) {
          final inner =
              body['comment'] as Map<String, dynamic>? ??
              body['data'] as Map<String, dynamic>? ??
              body;
          if (inner['content'] != null) {
            resolvedContent = inner['content'] as String;
          }
          final u = inner['updated_at'] as String?;
          if (u != null) {
            serverUpdatedAt = DateTime.tryParse(u);
          }
        }

        final updatedAt = serverUpdatedAt ?? DateTime.now();
        final newTree = _updateCommentInTree(
          state.comments,
          commentId,
          (c) => c.copyWith(content: resolvedContent, updatedAt: updatedAt),
        );
        state = state.copyWith(comments: newTree);
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.debug('Error editing comment: $e');
      return false;
    }
  }

  /// Toggle like state for the current post with optimistic UI update
  Future<void> togglePostLike() async {
    if (state.post == null) return;

    final post = state.post!;
    final wasLiked = post.isLiked;
    final newLikeState = !wasLiked;

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
        state = state.copyWith(
          post: state.post!.copyWith(
            isLiked: wasLiked,
            likeCount: state.post!.likeCount + (wasLiked ? 1 : -1),
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(
        post: state.post!.copyWith(
          isLiked: wasLiked,
          likeCount: state.post!.likeCount + (wasLiked ? 1 : -1),
        ),
      );
    }
  }

  /// Toggle like on a comment (nested supported); skips soft-deleted.
  Future<void> toggleCommentLike(String commentId) async {
    final target = _findCommentById(state.comments, commentId);
    if (target == null || target.isSoftDeleted) return;

    final wasLiked = target.isLiked;
    final newLikeState = !wasLiked;

    _updateCommentLikeState(commentId, newLikeState);

    try {
      final response = await _apiClient.post(
        ApiEndpoints.toggleCommentLike(commentId),
        data: {'like': newLikeState},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final serverLiked = data['is_liked'] as bool;
        final serverCount = data['like_count'] as int;

        _syncCommentLikeState(commentId, serverLiked, serverCount);
      } else {
        _updateCommentLikeState(commentId, wasLiked);
      }
    } catch (e) {
      _updateCommentLikeState(commentId, wasLiked);
    }
  }

  void _updateCommentLikeState(String commentId, bool isLiked) {
    final target = _findCommentById(state.comments, commentId);
    if (target == null) return;
    final delta = isLiked && !target.isLiked
        ? 1
        : (!isLiked && target.isLiked)
            ? -1
            : 0;

    final updatedComments = _updateCommentInTree(
      state.comments,
      commentId,
      (comment) => comment.copyWith(
        isLiked: isLiked,
        likeCount: (comment.likeCount + delta).clamp(0, 1 << 30),
      ),
    );
    state = state.copyWith(comments: updatedComments);
  }

  void _syncCommentLikeState(String commentId, bool isLiked, int likeCount) {
    final updatedComments = _updateCommentInTree(
      state.comments,
      commentId,
      (comment) => comment.copyWith(isLiked: isLiked, likeCount: likeCount),
    );
    state = state.copyWith(comments: updatedComments);
  }

  /// Remove comments and nested replies authored by [userId] (block/mute)
  void removeCommentsByAuthor(String userId) {
    state = state.copyWith(
      comments: _filterCommentsWithoutUser(state.comments, userId),
    );
  }

  /// Rewrite post + comment author handles after a username change.
  void rewriteAuthorUsername(String userId, String newUsername) {
    final post = state.post;
    state = state.copyWith(
      post: post == null
          ? null
          : rewritePostAuthorUsername(post, userId, newUsername),
      comments: state.comments
          .map((c) => rewriteCommentAuthorUsername(c, userId, newUsername))
          .toList(),
    );
  }
}

/// Provider for specific post detail
final postDetailProvider = StateNotifierProvider.autoDispose
    .family<PostDetailNotifier, PostDetailState, String>((
  ref,
  postId,
) {
  final apiClient = ref.watch(apiClientProvider);
  return PostDetailNotifier(apiClient, ref, postId);
});
