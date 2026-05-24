import 'user.dart';
import 'address.dart';

/// Post model
class Post {
  final String id;
  final String userId;
  final String content;
  final List<String> mediaUrls;
  final double? latitude;
  final double? longitude;
  final String geohash;
  final String? locationName;
  final Address? address;
  final double? distanceKm;
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
    this.latitude,
    this.longitude,
    this.geohash = '',
    this.locationName,
    this.address,
    this.distanceKm,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.author,
  });

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
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      geohash: json['geohash'] as String? ?? '',
      locationName: json['location_name'] as String?,
      address: address,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'media_urls': mediaUrls,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'location_name': locationName,
      'address': address?.toJson(),
      'distance_km': distanceKm,
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
    double? latitude,
    double? longitude,
    String? geohash,
    String? locationName,
    Address? address,
    double? distanceKm,
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
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geohash: geohash ?? this.geohash,
      locationName: locationName ?? this.locationName,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
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
