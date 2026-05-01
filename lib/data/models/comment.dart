import 'user.dart';

/// Backend marks removed comments this way so clients can hide content safely.
const String commentDeletedMarker = '[deleted]';

/// Comment model — enriched payload from GET comments; nested replies (partial + paginated).
class Comment {
  final String id;
  final String postId;
  final String? parentId;
  final String userId;
  final String content;
  final int depth;
  final DateTime createdAt;

  /// Populated when the editor changed the comment.
  final DateTime? updatedAt;

  /// Flat enrichment (preferred when present); [author] is built from nested or flat fields.
  final String? username;
  final String? profilePictureUrl;

  final int likeCount;
  final bool isLiked;

  /// Nested author — may be synthesized from flat `username` / `profile_picture_url`.
  final User? author;

  final List<Comment> replies;

  /// More sibling replies exist for this thread (GET …/comments/:id/replies).
  final bool hasMoreReplies;

  /// Cursor for GET /comments/:id/replies.
  final String? repliesNextCursor;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.userId,
    required this.content,
    this.depth = 1,
    required this.createdAt,
    this.updatedAt,
    this.username,
    this.profilePictureUrl,
    this.likeCount = 0,
    this.isLiked = false,
    this.author,
    this.replies = const [],
    this.hasMoreReplies = false,
    this.repliesNextCursor,
  });

  /// Backend soft-delete — hide body and disable interactions.
  bool get isSoftDeleted =>
      content == commentDeletedMarker || content.trim() == commentDeletedMarker;

  /// Avatar resolution: nested author wins, then flat URL.
  String? get effectiveProfilePictureUrl =>
      author?.profilePictureUrl ?? profilePictureUrl;

  /// Display handle: nested author wins, then flat username.
  String get effectiveUsername => author?.username ?? username ?? 'User';

  /// Whether this comment can have replies (depth < 3) and isn't removed.
  bool get canReply => depth < 3 && !isSoftDeleted;

  /// Whether this is a top-level comment
  bool get isTopLevel => parentId == null;

  static User? _parseAuthor(Map<String, dynamic> json) {
    if (json['author'] != null) {
      return User.fromJson(json['author'] as Map<String, dynamic>);
    }
    final uid = json['user_id'] as String?;
    if (uid == null || uid.isEmpty) return null;

    final un = json['username'] as String?;
    final ppu =
        json['profile_picture_url'] as String? ??
        json['profilePictureUrl'] as String?;

    return User(
      id: uid,
      username: (un != null && un.isNotEmpty) ? un : 'user',
      email: '',
      profilePictureUrl: ppu,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static List<Comment> _parseReplies(Map<String, dynamic> json) {
    final raw = json['replies'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static bool _parseRepliesHasMore(Map<String, dynamic> json) {
    return json['replies_has_more'] as bool? ??
        json['has_more_replies'] as bool? ??
        false;
  }

  static String? _parseRepliesNextCursor(Map<String, dynamic> json) {
    return json['replies_next_cursor'] as String? ??
        json['next_replies_cursor'] as String?;
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    final author = _parseAuthor(json);
    final flatUsername =
        json['username'] as String? ?? json['Username'] as String?;
    final flatPpu =
        json['profile_picture_url'] as String? ??
        json['profilePictureUrl'] as String?;

    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      userId:
          json['user_id'] as String? ??
          author?.id ??
          '',
      content: json['content'] as String? ?? '',
      depth: json['depth'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      username: flatUsername,
      profilePictureUrl: flatPpu,
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      author: author,
      replies: _parseReplies(json),
      hasMoreReplies: _parseRepliesHasMore(json),
      repliesNextCursor: _parseRepliesNextCursor(json),
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
      'updated_at': updatedAt?.toIso8601String(),
      'username': username,
      'profile_picture_url': profilePictureUrl,
      'like_count': likeCount,
      'is_liked': isLiked,
      'author': author?.toJson(),
      'replies': replies.map((r) => r.toJson()).toList(),
      'replies_has_more': hasMoreReplies,
      'replies_next_cursor': repliesNextCursor,
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
    DateTime? updatedAt,
    String? username,
    String? profilePictureUrl,
    int? likeCount,
    bool? isLiked,
    User? author,
    List<Comment>? replies,
    bool? hasMoreReplies,
    String? repliesNextCursor,
    bool clearRepliesNextCursor = false,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      parentId: parentId ?? this.parentId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      depth: depth ?? this.depth,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      author: author ?? this.author,
      replies: replies ?? this.replies,
      hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
      repliesNextCursor: clearRepliesNextCursor
          ? null
          : (repliesNextCursor ?? this.repliesNextCursor),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
