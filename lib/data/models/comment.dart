import 'user.dart';

/// Comment model with nested replies support (max depth: 3)
class Comment {
  final String id;
  final String postId;
  final String? parentId;
  final String userId;
  final String content;
  final int depth;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final User? author;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.userId,
    required this.content,
    this.depth = 1,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.author,
    this.replies = const [],
  });

  /// Whether this comment can have replies (depth < 3)
  bool get canReply => depth < 3;

  /// Whether this is a top-level comment
  bool get isTopLevel => parentId == null;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      parentId: json['parent_id'] as String?,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      depth: json['depth'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      author: json['author'] != null
          ? User.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      replies:
          (json['replies'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'parent_id': parentId,
      'user_id': userId,
      'content': content,
      'depth': depth,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
      'is_liked': isLiked,
      'author': author?.toJson(),
      'replies': replies.map((r) => r.toJson()).toList(),
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? parentId,
    String? userId,
    String? content,
    int? depth,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    User? author,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      author: author ?? this.author,
      replies: replies ?? this.replies,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
