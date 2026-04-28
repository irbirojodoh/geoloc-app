import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/post.dart';
import '../data/models/user.dart';

/// Provider for SearchService
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(apiClientProvider));
});

/// Service for handling search operations
class SearchService {
  final ApiClient _apiClient;

  SearchService(this._apiClient);

  /// Search users by query
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final response = await _apiClient.get(
      ApiEndpoints.searchUsers,
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final users = data['users'] as List<dynamic>? ?? [];
      return users
          .map((json) => User.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Search posts by content
  Future<List<Post>> searchPosts(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final response = await _apiClient.get(
      ApiEndpoints.searchPosts,
      queryParameters: {
        'q': query,
        'limit': limit,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final posts = data['posts'] as List<dynamic>? ?? [];
      return posts
          .map((json) => Post.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  /// Get suggested users (nearby or popular)
  Future<List<User>> getSuggestedUsers({int limit = 10}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.searchUsers,
        queryParameters: {
          'suggested': true,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final users = data['users'] as List<dynamic>? ?? [];
        return users
            .map((json) => User.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fallback: return empty list if suggested endpoint not available
    }

    return [];
  }
}
