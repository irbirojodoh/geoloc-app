/// Response model for toggle-like API endpoint
class LikeResponse {
  /// Whether the item is currently liked by the user
  final bool isLiked;

  /// Total like count after the operation
  final int likeCount;

  /// Whether the state actually changed (false if already in desired state)
  final bool changed;

  const LikeResponse({
    required this.isLiked,
    required this.likeCount,
    required this.changed,
  });

  factory LikeResponse.fromJson(Map<String, dynamic> json) {
    return LikeResponse(
      isLiked: json['is_liked'] as bool,
      likeCount: json['like_count'] as int,
      changed: json['changed'] as bool? ?? true,
    );
  }
}
