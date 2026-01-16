import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/like_response.dart';

/// Provider for LikeService
final likeServiceProvider = Provider<LikeService>((ref) {
  return LikeService(ref.watch(apiClientProvider));
});

/// Service for handling like operations with optimistic UI support
class LikeService {
  final ApiClient _apiClient;

  LikeService(this._apiClient);

  /// Toggle like state for a post
  ///
  /// [postId] - The post ID to toggle like for
  /// [like] - true to like, false to unlike
  ///
  /// Returns [LikeResponse] with the server's confirmed state
  Future<LikeResponse> togglePostLike(String postId, bool like) async {
    final response = await _apiClient.post(
      ApiEndpoints.togglePostLike(postId),
      data: {'like': like},
    );

    if (response.statusCode == 200) {
      return LikeResponse.fromJson(response.data as Map<String, dynamic>);
    }

    throw Exception('Failed to toggle post like: ${response.statusCode}');
  }

  /// Toggle like state for a comment
  ///
  /// [commentId] - The comment ID to toggle like for
  /// [like] - true to like, false to unlike
  ///
  /// Returns [LikeResponse] with the server's confirmed state
  Future<LikeResponse> toggleCommentLike(String commentId, bool like) async {
    final response = await _apiClient.post(
      ApiEndpoints.toggleCommentLike(commentId),
      data: {'like': like},
    );

    if (response.statusCode == 200) {
      return LikeResponse.fromJson(response.data as Map<String, dynamic>);
    }

    throw Exception('Failed to toggle comment like: ${response.statusCode}');
  }
}
