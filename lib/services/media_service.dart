import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/media_url.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../data/models/post.dart';
import '../data/models/user.dart';

/// Provider for [MediaService].
final mediaServiceProvider = Provider<MediaService>((ref) {
  return MediaService(ref.watch(apiClientProvider));
});

/// In-memory cache for presigned GET URLs keyed by R2 object key.
class MediaUrlCache {
  final _entries = <String, _CachedUrl>{};

  String? get(String key) {
    final entry = _entries[key];
    if (entry == null || entry.expiresAt.isBefore(DateTime.now())) {
      return null;
    }
    return entry.url;
  }

  void put(String key, String url, DateTime expiresAt) {
    _entries[key] = _CachedUrl(
      url,
      expiresAt.subtract(const Duration(minutes: 1)),
    );
  }

  /// Seed cache from a presigned URL already returned by the API.
  void seedFromPresignedUrl(String url) {
    final key = MediaUrl.parseKeyFromUrl(url);
    if (key == null) return;
    put(
      key,
      url,
      DateTime.now().add(const Duration(minutes: 14)),
    );
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;

  const _CachedUrl(this.url, this.expiresAt);
}

/// Signed media URL returned by GET /api/v1/media/sign.
class SignedMediaUrl {
  final String url;
  final DateTime expiresAt;

  const SignedMediaUrl({required this.url, required this.expiresAt});

  factory SignedMediaUrl.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String?;
    final expiresAtRaw = json['expires_at'] as String?;
    if (url == null || url.isEmpty) {
      throw const FormatException('Sign response missing url');
    }
    return SignedMediaUrl(
      url: url,
      expiresAt: expiresAtRaw != null
          ? DateTime.parse(expiresAtRaw).toLocal()
          : DateTime.now().add(const Duration(minutes: 14)),
    );
  }
}

/// Resolves R2 object keys to fresh presigned GET URLs.
class MediaService {
  final ApiClient _apiClient;
  final MediaUrlCache cache = MediaUrlCache();

  MediaService(this._apiClient);

  String? getCachedUrl(String key) => cache.get(key);

  /// Request a fresh presigned GET URL for an R2 object key.
  Future<SignedMediaUrl> signUrl(String key) async {
    final cached = cache.get(key);
    if (cached != null) {
      return SignedMediaUrl(
        url: cached,
        expiresAt: DateTime.now().add(const Duration(minutes: 14)),
      );
    }

    final response = await _apiClient.get(
      ApiEndpoints.mediaSign,
      queryParameters: {'key': key},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to sign media URL');
    }

    final signed = SignedMediaUrl.fromJson(
      response.data as Map<String, dynamic>,
    );
    cache.put(key, signed.url, signed.expiresAt);
    return signed;
  }

  /// Refresh a possibly expired presigned URL; returns null if not an R2 URL.
  Future<String?> refreshPresignedUrl(String url) async {
    final key = MediaUrl.parseKeyFromUrl(url);
    if (key == null) return null;
    final signed = await signUrl(key);
    return signed.url;
  }

  /// Refresh presigned URLs for a list of posts loaded from offline cache.
  Future<List<Post>> hydratePostsMediaUrls(List<Post> posts) async {
    final hydrated = <Post>[];
    for (final post in posts) {
      hydrated.add(await _hydratePost(post));
    }
    return hydrated;
  }

  Future<Post> _hydratePost(Post post) async {
    var updated = post;

    if (post.mediaKeys.isNotEmpty &&
        (post.mediaUrls.isEmpty ||
            post.mediaUrls.every((url) => url.trim().isEmpty))) {
      final urls = <String>[];
      for (final key in post.mediaKeys) {
        try {
          urls.add((await signUrl(key)).url);
        } catch (_) {
          // Skip failed signs; widget can retry individually.
        }
      }
      if (urls.isNotEmpty) {
        updated = updated.copyWith(mediaUrls: urls);
      }
    } else {
      for (final url in post.mediaUrls) {
        cache.seedFromPresignedUrl(url);
      }
    }

    final author = updated.author;
    if (author != null) {
      final needsAvatar =
          author.avatarKey != null &&
          (author.profilePictureUrl == null ||
              author.profilePictureUrl!.trim().isEmpty);
      final needsCover =
          author.coverKey != null &&
          (author.coverImageUrl == null ||
              author.coverImageUrl!.trim().isEmpty);

      var updatedAuthor = author;
      if (needsAvatar) {
        try {
          updatedAuthor = updatedAuthor.copyWith(
            profilePictureUrl: (await signUrl(author.avatarKey!)).url,
          );
        } catch (_) {}
      }
      if (needsCover) {
        try {
          updatedAuthor = updatedAuthor.copyWith(
            coverImageUrl: (await signUrl(author.coverKey!)).url,
          );
        } catch (_) {}
      }
      if (updatedAuthor != author) {
        updated = updated.copyWith(author: updatedAuthor);
      }
    }

    return updated;
  }

  /// Hydrate profile image URLs from stable keys when presigned URLs are absent.
  Future<User> hydrateUserMediaUrls(User user) async {
    var updated = user;

    if (user.avatarKey != null &&
        (user.profilePictureUrl == null ||
            user.profilePictureUrl!.trim().isEmpty)) {
      try {
        updated = updated.copyWith(
          profilePictureUrl: (await signUrl(user.avatarKey!)).url,
        );
      } catch (_) {}
    }

    if (user.coverKey != null &&
        (user.coverImageUrl == null || user.coverImageUrl!.trim().isEmpty)) {
      try {
        updated = updated.copyWith(
          coverImageUrl: (await signUrl(user.coverKey!)).url,
        );
      } catch (_) {}
    }

    return updated;
  }

  /// Delete an owned R2 object.
  Future<void> deleteObject(String key) async {
    final response = await _apiClient.delete(
      ApiEndpoints.mediaDeleteObject,
      queryParameters: {'key': key},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete media object');
    }
  }
}
