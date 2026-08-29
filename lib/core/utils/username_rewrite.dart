import '../../data/models/comment.dart';
import '../../data/models/post.dart';

/// Rewrite the author handle on a post when it belongs to [userId].
Post rewritePostAuthorUsername(
  Post post,
  String userId,
  String newUsername,
) {
  final isAuthor = post.userId == userId || post.author?.id == userId;
  if (!isAuthor || post.author == null) return post;
  return post.copyWith(author: post.author!.copyWith(username: newUsername));
}

/// Rewrite flat + nested author handles on a comment tree for [userId].
Comment rewriteCommentAuthorUsername(
  Comment comment,
  String userId,
  String newUsername,
) {
  final isAuthor =
      comment.userId == userId || comment.author?.id == userId;
  var result = comment;
  if (isAuthor) {
    result = result.copyWith(
      username: newUsername,
      author: comment.author?.copyWith(username: newUsername),
    );
  }
  if (result.replies.isEmpty) return result;
  return result.copyWith(
    replies: result.replies
        .map((r) => rewriteCommentAuthorUsername(r, userId, newUsername))
        .toList(),
  );
}
