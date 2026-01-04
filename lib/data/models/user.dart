/// User model
class User {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final String? bio;
  final String? phoneNumber;
  final String? profilePictureUrl;
  final DateTime? lastOnline;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int followersCount;
  final int followingCount;
  final bool? isFollowing; // Current user's follow status

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    this.bio,
    this.phoneNumber,
    this.profilePictureUrl,
    this.lastOnline,
    this.createdAt,
    this.updatedAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String?,
      bio: json['bio'] as String?,
      phoneNumber: json['phone_number'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      lastOnline: json['last_online'] != null
          ? DateTime.parse(json['last_online'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'bio': bio,
      'phone_number': phoneNumber,
      'profile_picture_url': profilePictureUrl,
      'last_online': lastOnline?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'followers_count': followersCount,
      'following_count': followingCount,
      'is_following': isFollowing,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    String? bio,
    String? phoneNumber,
    String? profilePictureUrl,
    DateTime? lastOnline,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      lastOnline: lastOnline ?? this.lastOnline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'User(id: $id, username: $username)';
}
