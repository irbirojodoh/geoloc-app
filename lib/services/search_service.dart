import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/post.dart';
import '../data/models/user.dart';

/// Provider for SearchService
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(apiClientProvider));
});

class SearchResponse {
  final List<Post> posts;
  final List<User> users;
  final int total;
  final String query;

  const SearchResponse({
    this.posts = const [],
    this.users = const [],
    this.total = 0,
    this.query = '',
  });
}

class AutocompleteResponse {
  final List<String> users;
  final List<String> hashtags;

  const AutocompleteResponse({
    this.users = const [],
    this.hashtags = const [],
  });
}

/// Service for handling search operations
class SearchService {
  final ApiClient _apiClient;

  SearchService(this._apiClient);

  /// Elasticsearch global search across users and posts.
  Future<SearchResponse> searchGlobal(
    String query, {
    String type = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return const SearchResponse();

    final response = await _apiClient.get(
      ApiEndpoints.search,
      queryParameters: {
        'q': query,
        'type': type,
        'page': page,
        'limit': limit,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return _mapSearchResponse(data, fallbackQuery: query);
    }

    return const SearchResponse();
  }

  /// Nearby search with geo-filtered posts.
  Future<SearchResponse> searchNearby(
    String query, {
    required double lat,
    required double lon,
    double radiusKm = 5,
    String type = 'all',
  }) async {
    if (query.trim().isEmpty) return const SearchResponse();

    final response = await _apiClient.get(
      ApiEndpoints.searchNearby,
      queryParameters: {
        'q': query,
        'lat': lat,
        'lon': lon,
        'radius_km': radiusKm,
        'type': type,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return _mapSearchResponse(data, fallbackQuery: query);
    }

    return const SearchResponse();
  }

  /// Real-time autocomplete for usernames and hashtags.
  Future<AutocompleteResponse> autocomplete(
    String query, {
    String type = 'all',
  }) async {
    if (query.trim().isEmpty) return const AutocompleteResponse();

    final response = await _apiClient.get(
      ApiEndpoints.autocomplete,
      queryParameters: {'q': query, 'type': type},
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final users = data['users'] as List<dynamic>? ?? [];
      final hashtags = data['hashtags'] as List<dynamic>? ?? [];
      return AutocompleteResponse(
        users: users.map((e) => e.toString()).toList(),
        hashtags: hashtags.map((e) => e.toString()).toList(),
      );
    }

    return const AutocompleteResponse();
  }

  SearchResponse _mapSearchResponse(
    Map<String, dynamic> data, {
    required String fallbackQuery,
  }) {
    final postItems = (data['posts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final userItems = (data['users'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final totalRaw = data['total'];
    final total = totalRaw is num
        ? totalRaw.toInt()
        : int.tryParse(totalRaw?.toString() ?? '') ?? 0;
    final responseQuery = data['query']?.toString() ?? fallbackQuery;

    return SearchResponse(
      posts: postItems.map(Post.fromJson).toList(),
      users: userItems.map(User.fromJson).toList(),
      total: total,
      query: responseQuery,
    );
  }
}
