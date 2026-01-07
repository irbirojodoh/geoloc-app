import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for post images with 3-day stale period
class PostImageCacheManager {
  static const key = 'postImageCache';

  static CacheManager instance = CacheManager(
    Config(key, stalePeriod: const Duration(days: 3), maxNrOfCacheObjects: 200),
  );

  /// Clear the entire cache
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}

/// Custom cache manager for profile avatars with 7-day stale period
class AvatarCacheManager {
  static const key = 'avatarCache';

  static CacheManager instance = CacheManager(
    Config(key, stalePeriod: const Duration(days: 7), maxNrOfCacheObjects: 100),
  );

  /// Clear the entire cache
  static Future<void> clearCache() async {
    await instance.emptyCache();
  }
}
