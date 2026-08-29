import '../../core/logging/app_logger.dart';
import 'user.dart';
import 'address.dart';

/// Post model
class Post {
  final String id;
  final String userId;
  final String content;
  final List<String> mediaUrls;
  final List<String> mediaKeys;
  final double? latitude;
  final double? longitude;
  final String geohash;
  final String? locationName;
  final Address? address;
  final double? distanceKm;
  final bool locationVerified;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final User? author;

  const Post({
    required this.id,
    required this.userId,
    required this.content,
    this.mediaUrls = const [],
    this.mediaKeys = const [],
    this.latitude,
    this.longitude,
    this.geohash = '',
    this.locationName,
    this.address,
    this.distanceKm,
    this.locationVerified = false,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.author,
  });

  /// Number of media items (prefers resolved URLs, falls back to keys).
  int get mediaCount =>
      mediaUrls.isNotEmpty ? mediaUrls.length : mediaKeys.length;

  bool get hasMedia => mediaCount > 0;

  String? mediaUrlAt(int index) =>
      index < mediaUrls.length ? mediaUrls[index] : null;

  String? mediaKeyAt(int index) =>
      index < mediaKeys.length ? mediaKeys[index] : null;

  /// Get formatted location string (e.g., "Pondok Cina, Depok")
  String get formattedLocation {
    // First try to use address
    if (address != null && address!.formattedLocation.isNotEmpty) {
      return address!.formattedLocation;
    }
    // Fallback to locationName
    if (locationName != null && locationName!.isNotEmpty) {
      return locationName!;
    }
    return '';
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    // Handle author: either nested object or flat fields
    User? author;
    if (json['author'] != null) {
      author = User.fromJson(json['author'] as Map<String, dynamic>);
    } else if (json['username'] != null) {
      // Backend returns flat structure with username and profile_picture_url
      author = User(
        id: json['user_id'] as String,
        username: json['username'] as String,
        email: '', // Not provided in feed response
        profilePictureUrl: json['profile_picture_url'] as String?,
        avatarKey: json['avatar_key'] as String?,
        createdAt: DateTime.now(),
      );
    }

    // Parse address if present
    Address? address;
    if (json['address'] != null) {
      address = Address.fromJson(json['address'] as Map<String, dynamic>);
    }

    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      mediaUrls:
          (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      mediaKeys:
          (json['media_keys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geohash: json['geohash'] as String? ?? '',
      locationName: json['location_name'] as String?,
      address: address,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      locationVerified: _locationVerifiedFromJson(json),
      createdAt: DateTime.parse(json['created_at'] as String),
      likeCount: json['like_count'] as int? ?? 0,
      // Backend payloads have not been consistent here; accept common variants.
      commentCount:
          json['comment_count'] as int? ??
          json['comments_count'] as int? ??
          json['comments'] as int? ??
          json['commentCount'] as int? ??
          0,
      isLiked: json['is_liked'] as bool? ?? false,
      author: author,
    );
  }

  /// JSON for offline cache — omits ephemeral presigned URLs and
  /// session-volatile location labels (street-level names change as cells
  /// are re-geocoded; always take `location_name` from a live response).
  Map<String, dynamic> toCacheJson() {
    final json = toJson();
    json.remove('media_urls');
    json.remove('location_name');
    json.remove('address');
    if (json['author'] is Map<String, dynamic>) {
      final authorJson = Map<String, dynamic>.from(
        json['author'] as Map<String, dynamic>,
      );
      authorJson.remove('profile_picture_url');
      authorJson.remove('cover_image_url');
      json['author'] = authorJson;
    }
    return json;
  }

  /// Restores a cached post, dropping any location labels that slipped onto disk.
  factory Post.fromCacheJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    copy.remove('location_name');
    copy.remove('address');
    return Post.fromJson(copy);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'media_urls': mediaUrls,
      'media_keys': mediaKeys,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'location_name': locationName,
      'address': address?.toJson(),
      'distance_km': distanceKm,
      'location_verified': locationVerified,
      'created_at': createdAt.toIso8601String(),
      'like_count': likeCount,
      'comment_count': commentCount,
      'is_liked': isLiked,
      'author': author?.toJson(),
    };
  }

  Post copyWith({
    String? id,
    String? userId,
    String? content,
    List<String>? mediaUrls,
    List<String>? mediaKeys,
    double? latitude,
    double? longitude,
    String? geohash,
    String? locationName,
    Address? address,
    double? distanceKm,
    bool? locationVerified,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    User? author,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaKeys: mediaKeys ?? this.mediaKeys,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      locationVerified: locationVerified ?? this.locationVerified,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      author: author ?? this.author,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Post(id: $id, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...)';
}

bool _locationVerifiedFromJson(Map<String, dynamic> json) {
  final raw = _readLocationVerifiedRaw(json);
  final parsed = _parseBool(raw) ?? false;
  debugLogApiPostLocation(json, source: 'Post.fromJson', parsed: parsed);
  return parsed;
}

/// Reads `location_verified` from common API key variants.
Object? _readLocationVerifiedRaw(Map<String, dynamic> json) {
  const candidates = [
    'location_verified',
    'is_location_verified',
    'locationVerified',
    'LocationVerified',
    'isLocationVerified',
    'photo_location_verified',
    'location_match',
  ];
  for (final key in candidates) {
    if (json.containsKey(key)) return json[key];
  }
  for (final key in json.keys) {
    final lower = key.toLowerCase();
    if (lower.contains('location') && lower.contains('verif')) {
      return json[key];
    }
  }
  return null;
}

bool? _parseBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

/// Debug-only dump of location-verification fields from a raw API post.
void debugLogApiPostLocation(
  Map<String, dynamic> json, {
  required String source,
  bool? parsed,
}) {
  final related = <String, dynamic>{};
  for (final entry in json.entries) {
    final key = entry.key.toLowerCase();
    if (key.contains('location') ||
        key.contains('verif') ||
        key.contains('exif') ||
        key.contains('gps') ||
        key.contains('geohash') ||
        key.contains('media_key') ||
        key.contains('media_keys')) {
      related[entry.key] = entry.value;
    }
  }
  final raw = _readLocationVerifiedRaw(json);
  AppLogger.debug(
    '📍 [$source] id=${json['id']} content=${json['content']} '
    'raw=$raw parsed=${parsed ?? _parseBool(raw)} '
    'related=$related allKeys=${json.keys.toList()}',
  );
}
