import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../config/app_config.dart';
import '../data/models/post.dart';

/// Provider for [FeedCacheService].
final feedCacheServiceProvider = Provider<FeedCacheService>((ref) {
  return FeedCacheService();
});

/// Cached feed snapshot for offline display.
class CachedFeedSnapshot {
  final List<Post> posts;
  final double latitude;
  final double longitude;
  final double radiusKm;
  final String? cursor;
  final bool hasMore;
  final DateTime cachedAt;

  const CachedFeedSnapshot({
    required this.posts,
    required this.latitude,
    required this.longitude,
    required this.radiusKm,
    required this.cursor,
    required this.hasMore,
    required this.cachedAt,
  });
}

/// Persists feed posts locally without ephemeral presigned URLs.
class FeedCacheService {
  static const _cacheKey = 'latest_feed';

  Future<void> saveFeed({
    required List<Post> posts,
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? cursor,
    required bool hasMore,
  }) async {
    final box = await Hive.openBox<Map>(AppConfig.feedCacheBox);
    await box.put(_cacheKey, {
      'posts': posts.map((post) => post.toCacheJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
      'cursor': cursor,
      'has_more': hasMore,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  Future<CachedFeedSnapshot?> loadFeed() async {
    final box = await Hive.openBox<Map>(AppConfig.feedCacheBox);
    final raw = box.get(_cacheKey);
    if (raw == null) return null;

    final data = Map<String, dynamic>.from(raw);
    final postsJson = data['posts'] as List<dynamic>? ?? [];
    final posts = postsJson
        .map(
          (json) => Post.fromCacheJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();

    if (posts.isEmpty) return null;

    return CachedFeedSnapshot(
      posts: posts,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      radiusKm: (data['radius_km'] as num?)?.toDouble() ??
          AppConfig.defaultFeedRadiusKm,
      cursor: data['cursor'] as String?,
      hasMore: data['has_more'] as bool? ?? false,
      cachedAt: DateTime.tryParse(data['cached_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> clear() async {
    final box = await Hive.openBox<Map>(AppConfig.feedCacheBox);
    await box.delete(_cacheKey);
  }
}
