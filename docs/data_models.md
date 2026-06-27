# Data Models

Data models represent the core domain entities and handle JSON serialization for API communication.

## Models Overview

| Model | File | Description |
|-------|------|-------------|
| User | `user.dart` | User profile data |
| Post | `post.dart` | Social media post |
| Comment | `comment.dart` | Post comment |
| Address | `address.dart` | Location address details |
| AuthTokens | `auth_tokens.dart` | JWT access/refresh tokens |
| Notification | `notification.dart` | Activity notification |
| LocationFollow | `location_follow.dart` | Followed location |

---

## User

**File**: `lib/data/models/user.dart`

Represents a user profile in the system.

```dart
class User {
  final String id;
  final String username;
  final String email;
  final String? fullName;
  final String? bio;
  final String? phoneNumber;
  final String? profilePictureUrl;
  final String? coverImageUrl;
  final String? avatarKey;       // R2 object key (attach on update)
  final String? coverKey;        // R2 object key (attach on update)
  final DateTime? lastOnline;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int followersCount;
  final int followingCount;
  final bool? isFollowing;  // Current user's follow status
}
```

### JSON Mapping

| Dart Field | JSON Key | Notes |
|------------|----------|-------|
| `id` | `id` or `user_id` | Accepts either |
| `username` | `username` | |
| `email` | `email` | |
| `fullName` | `full_name` | |
| `profilePictureUrl` | `profile_picture_url` | Presigned GET URL from API |
| `avatarKey` | `avatar_key` | Stable R2 key for attach/sign |
| `coverKey` | `cover_key` | Stable R2 key for attach/sign |
| `followersCount` | `followers_count` | Default: 0 |
| `isFollowing` | `is_following` | Only in profile responses |

---

## Post

**File**: `lib/data/models/post.dart`

Represents a social media post with location.

```dart
class Post {
  final String id;
  final String userId;
  final String content;
  final List<String> mediaUrls;   // Presigned GET URLs from API (ephemeral)
  final List<String> mediaKeys;   // Stable R2 keys (cache + attach)
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
}
```

### Computed Properties

```dart
// Get formatted location string
String get formattedLocation {
  if (address != null && address!.formattedLocation.isNotEmpty) {
    return address!.formattedLocation;  // e.g., "Pondok Cina, Depok"
  }
  if (locationName != null && locationName!.isNotEmpty) {
    return locationName!;
  }
  return '';
}
```

### JSON Mapping

| Dart Field | JSON Key | Notes |
|------------|----------|-------|
| `id` | `id` | |
| `userId` | `user_id` | |
| `content` | `content` | |
| `mediaUrls` | `media_urls` | Presigned GET URLs (ephemeral) |
| `mediaKeys` | `media_keys` | Stable R2 keys for cache/attach |
| `latitude` | `latitude` | Nullable |
| `longitude` | `longitude` | Nullable |
| `geohash` | `geohash` | Location hash |
| `distanceKm` | `distance_km` | Distance from user |
| `likeCount` | `like_count` | Default: 0 |
| `isLiked` | `is_liked` | Default: false |
| `author` | `author` or flat fields | See below |

### Author Parsing

The API may return author data in two formats:

```json
// Nested object format
{
  "author": {
    "id": "123",
    "username": "john",
    "profile_picture_url": "..."
  }
}

// Flat format (in feed responses)
{
  "user_id": "123",
  "username": "john",
  "profile_picture_url": "..."
}
```

Both formats are handled in `Post.fromJson()`.

---

## Comment

**File**: `lib/data/models/comment.dart`

Represents a comment on a post.

```dart
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final User? author;
}
```

---

## Address

**File**: `lib/data/models/address.dart`

Represents a geocoded location address.

```dart
class Address {
  final String? road;
  final String? neighbourhood;
  final String? suburb;
  final String? city;
  final String? state;
  final String? postcode;
  final String? country;
  final String? countryCode;
  final String? displayName;
}
```

### Computed Properties

```dart
// Short location format: "Suburb, City" or "City, State"
String get formattedLocation {
  final parts = <String>[];
  if (suburb != null) parts.add(suburb!);
  if (city != null) parts.add(city!);
  if (parts.isEmpty && state != null) parts.add(state!);
  return parts.join(', ');
}
```

---

## AuthTokens

**File**: `lib/data/models/auth_tokens.dart`

JWT tokens for authentication.

```dart
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
  
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}
```

---

## Notification

**File**: `lib/data/models/notification.dart`

Activity notification for user interactions.

```dart
class AppNotification {
  final String id;
  final String userId;
  final String type;        // 'like', 'comment', 'follow', 'location_post'
  final String actorId;
  final String? targetId;   // Post or comment ID
  final String? message;
  final bool isRead;
  final DateTime createdAt;
  final User? actor;
}
```

### Notification Types

| Type | Description | Target |
|------|-------------|--------|
| `like` | Someone liked your post | Post ID |
| `comment` | Comment on your post | Post ID |
| `follow` | New follower | User ID |
| `location_post` | Post near followed location | Post ID |

---

## LocationFollow

**File**: `lib/data/models/location_follow.dart`

Represents a location the user follows to receive notifications.

```dart
class LocationFollow {
  final String id;
  final String userId;
  final String geohash;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final int radiusKm;
  final DateTime createdAt;
}
```

---

## Common Patterns

### JSON Serialization

```dart
// From JSON
factory User.fromJson(Map<String, dynamic> json) {
  return User(
    id: json['id'] as String,
    username: json['username'] as String,
    // ... handle nullable fields with null checks
  );
}

// To JSON
Map<String, dynamic> toJson() {
  return {
    'id': id,
    'username': username,
    // ...
  };
}
```

### CopyWith Pattern

```dart
User copyWith({
  String? id,
  String? username,
  // ...
}) {
  return User(
    id: id ?? this.id,
    username: username ?? this.username,
    // ...
  );
}
```

### Equality

```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is User && runtimeType == other.runtimeType && id == other.id;

@override
int get hashCode => id.hashCode;
```
