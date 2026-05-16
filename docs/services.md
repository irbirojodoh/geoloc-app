# Services

Services handle business logic, API communication, and external integrations.

## Services Overview

| Service | File | Description |
|---------|------|-------------|
| AuthService | `auth_service.dart` | Authentication and user management |
| LocationService | `location_service.dart` | GPS and geocoding |
| NotificationService | `notification_service.dart` | Fetching notification history and SSE stream |
| PushNotificationService | `push_notification_service.dart` | Firebase push notifications |

---

## Auth Service

**File**: `lib/services/auth_service.dart`

Handles all authentication-related operations.

### Provider

```dart
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});
```

### Methods

#### Login
```dart
Future<User> login({
  required String email,
  required String password,
}) async {
  final response = await _apiClient.post('/auth/login', data: {
    'email': email,
    'password': password,
  });
  
  // Store tokens
  await _storeTokens(response.data['access_token'], response.data['refresh_token']);
  
  return User.fromJson(response.data['user']);
}
```

#### Register
```dart
Future<User> register({
  required String email,
  required String password,
  required String username,
  required String fullName,
}) async {
  final response = await _apiClient.post('/auth/register', data: {
    'email': email,
    'password': password,
    'username': username,
    'full_name': fullName,
  });
  
  await _storeTokens(...);
  return User.fromJson(response.data['user']);
}
```

#### Refresh Token
```dart
Future<void> refreshToken() async {
  final refreshToken = await _secureStorage.read(key: 'refresh_token');
  
  final response = await _apiClient.post('/auth/refresh', data: {
    'refresh_token': refreshToken,
  });
  
  await _storeTokens(response.data['access_token'], response.data['refresh_token']);
}
```

#### Logout
```dart
Future<void> logout() async {
  await _secureStorage.delete(key: 'access_token');
  await _secureStorage.delete(key: 'refresh_token');
}
```

#### Get Current User
```dart
Future<User> getCurrentUser() async {
  final response = await _apiClient.get('/users/me');
  return User.fromJson(response.data);
}
```

#### Update Profile
```dart
Future<User> updateProfile({
  String? fullName,
  String? bio,
  String? username,
}) async {
  final response = await _apiClient.put('/users/me', data: {
    if (fullName != null) 'full_name': fullName,
    if (bio != null) 'bio': bio,
    if (username != null) 'username': username,
  });
  return User.fromJson(response.data);
}
```

---

## Location Service

**File**: `lib/services/location_service.dart`

Handles GPS location and reverse geocoding.

### Provider

```dart
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(apiClient: ref.watch(apiClientProvider));
});
```

### Methods

#### Get Current Position
```dart
Future<Position> getCurrentPosition() async {
  // Check permission
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw LocationPermissionDenied();
    }
  }
  
  // Get position
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

#### Get Address from Coordinates
```dart
Future<Address> getAddressFromCoordinates(double lat, double lng) async {
  final response = await _apiClient.get('/geocode/address', queryParameters: {
    'latitude': lat,
    'longitude': lng,
  });
  
  return Address.fromJson(response.data);
}
```

#### Calculate Distance
```dart
double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
  return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // km
}
```

---

## Push Notification Service

**File**: `lib/services/push_notification_service.dart`

Handles Firebase Cloud Messaging for background push notifications and token syncing.

> **Note**: iOS uses `GoogleService-Info.plist` (configured). Android requires `google-services.json` to complete setup on that platform.

### Provider

```dart
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});
```

### Methods

#### Initialize
```dart
Future<void> initialize() async {
  // Request permission
  final settings = await FirebaseMessaging.instance.requestPermission();
  
  // Get FCM token
  final token = await FirebaseMessaging.instance.getToken();
  
  // Register token with backend
  await _registerToken(token);
  
  // Handle foreground messages
  FirebaseMessaging.onMessage.listen(_handleMessage);
}
```

#### Handle Notification Tap
```dart
void _handleMessage(RemoteMessage message) {
  final type = message.data['type'];
  final targetId = message.data['target_id'];
  
  switch (type) {
    case 'like':
    case 'comment':
      // Navigate to post
      router.push('/post/$targetId');
      break;
    case 'follow':
      // Navigate to profile
      router.push('/profile/$targetId');
      break;
  }
}
```

---

## Notification Service

**File**: `lib/services/notification_service.dart`

Handles notifications list, read endpoints, actor enrichment by `actor_id`, and
real-time SSE streams.

### Provider

```dart
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(apiClientProvider));
});
```

### Methods

#### Fetch Notifications
```dart
Future<NotificationPage> getNotifications({
  int limit = 50,
  bool unreadOnly = false,
})
```

Contract:

- `GET /api/v1/notifications?limit={n}[&unread=true]`
- Parses:
  - `notifications`
  - `unread_count`
  - `total`
- No cursor pagination on this endpoint; "load more" is implemented by
  increasing `limit` (capped at 100).

The service also resolves missing actor info (`actor_id`) using:

- `GET /api/v1/users/{actor_id}`

and caches users in-memory for the session.

#### Get Notification Stream (SSE)
```dart
Stream<AppNotification> getNotificationStream() async* {
  final response = await _apiClient.dio.get<ResponseBody>(
    ApiEndpoints.notificationStream,
    options: Options(
      responseType: ResponseType.stream,
      headers: {'Accept': 'text/event-stream'},
    ),
  );

  final stream = response.data?.stream;
  if (stream == null) return;

  yield* stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .where((data) => data.isNotEmpty)
      .map((data) {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      return AppNotification.fromJson(json);
    } catch (_) {
      return null;
    }
  }).where((n) => n != null).cast<AppNotification>();
}
```

---

## API Client

**File**: `lib/core/network/api_client.dart`

Dio wrapper for HTTP requests with auth interceptor.

### Configuration

```dart
final dio = Dio(BaseOptions(
  baseUrl: 'http://localhost:8080',
  connectTimeout: Duration(seconds: 10),
  receiveTimeout: Duration(seconds: 10),
  headers: {
    'Content-Type': 'application/json',
  },
));
```

### Auth Interceptor

**File**: `lib/core/network/auth_interceptor.dart`

Automatically adds JWT token and handles 401 refresh.

```dart
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(options, handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  @override
  void onError(error, handler) async {
    if (error.response?.statusCode == 401) {
      // Try to refresh token
      await _refreshToken();
      // Retry request
      return handler.resolve(await _retry(error.requestOptions));
    }
    handler.next(error);
  }
}
```

---

## API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Create account |
| POST | `/auth/login` | Login |
| POST | `/auth/refresh` | Refresh JWT |

### Users
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/users/me` | Get current user |
| PUT | `/users/me` | Update profile |
| GET | `/users/:id` | Get user profile |
| POST | `/users/:id/follow` | Follow user |
| DELETE | `/users/:id/follow` | Unfollow user |
| GET | `/users/:id/followers` | List followers |
| GET | `/users/:id/following` | List following |

### Posts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/feed` | Get nearby posts |
| POST | `/posts` | Create post |
| GET | `/posts/:id` | Get post detail |
| DELETE | `/posts/:id` | Delete post |
| POST | `/posts/:id/like` | Like post |
| DELETE | `/posts/:id/like` | Unlike post |
| GET | `/posts/:id/comments` | List comments |
| POST | `/posts/:id/comments` | Add comment |

### Geocoding
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/geocode/address` | Reverse geocode |

### Notifications
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/notifications` | List notifications (`limit`, `unread`) |
| PUT | `/api/v1/notifications/:id/read` | Mark as read |
| PUT | `/api/v1/notifications/read-all` | Mark all as read |
| GET | `/api/v1/notifications/stream` | SSE stream |
| POST | `/api/v1/devices` | Register FCM token |
| DELETE | `/api/v1/devices` | Unregister FCM token |

### Search
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/search/users` | Search users |
| GET | `/search/posts` | Search posts |
