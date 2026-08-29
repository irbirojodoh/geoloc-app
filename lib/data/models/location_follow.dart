/// A geographic area the user follows, identified by a **server-owned**
/// `geohash_prefix`.
///
/// That prefix is currently 6 characters (~1.2 km × 0.6 km). Never persist it
/// as a durable cache key and never client-compute it for unfollow — Cassandra
/// deletes are idempotent, so a stale 5-char prefix returns 200 while deleting
/// nothing. Always use the value from the latest `GET /locations/following`.
class LocationFollow {
  final String geohashPrefix;
  final String? name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  const LocationFollow({
    required this.geohashPrefix,
    this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory LocationFollow.fromJson(Map<String, dynamic> json) {
    return LocationFollow(
      geohashPrefix: json['geohash_prefix'] as String,
      name: json['name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// API payload only — do not write this map to Hive/SharedPreferences.
  Map<String, dynamic> toJson() {
    return {
      'geohash_prefix': geohashPrefix,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }

  LocationFollow copyWith({
    String? geohashPrefix,
    String? name,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return LocationFollow(
      geohashPrefix: geohashPrefix ?? this.geohashPrefix,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationFollow &&
          runtimeType == other.runtimeType &&
          geohashPrefix == other.geohashPrefix;

  @override
  int get hashCode => geohashPrefix.hashCode;
}
