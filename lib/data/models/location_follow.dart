/// Location subscription model
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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

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
