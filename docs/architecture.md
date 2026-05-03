# Architecture

## Overview

Geoloc follows a **Clean Architecture** pattern with clear separation of concerns across layers.

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Screens    │  │   Widgets    │  │  Providers   │       │
│  │  (UI Views)  │  │ (Reusable)   │  │   (State)    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Services Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ AuthService  │  │LocationService│  │PushService   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Models    │  │  API Client  │  │    Cache     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Core Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Network    │  │    Errors    │  │    Utils     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                 # Entry point, initializes app
├── app.dart                  # Root MaterialApp with theme
├── config/                   # App configuration
│   ├── app_config.dart       # API URLs, constants
│   ├── routes.dart           # GoRouter navigation
│   └── theme.dart            # Material 3 theming
├── core/                     # Shared infrastructure
│   ├── cache/                # Caching utilities
│   ├── constants/            # App constants
│   ├── errors/               # Error handling, failures
│   ├── network/              # API client, interceptors
│   └── utils/                # Helper utilities
├── data/                     # Data layer
│   ├── datasources/          # Remote/local data sources
│   ├── models/               # Data models (DTOs)
│   └── repositories/         # Repository implementations
├── domain/                   # Business logic (if applicable)
├── presentation/             # UI layer
│   ├── providers/            # Riverpod state management
│   ├── screens/              # Full-page UI screens
│   └── widgets/              # Reusable UI components
└── services/                 # Business services
    ├── auth_service.dart     # Authentication logic
    ├── location_service.dart # GPS and geocoding
    └── push_notification_service.dart
```

## Layer Responsibilities

### Presentation Layer
- **Screens**: Full-page UI views (LoginScreen, FeedScreen, etc.)
- **Widgets**: Reusable UI components (PostCard, UserAvatar)
- **Providers**: State management with Riverpod

### Services Layer
- Business logic and orchestration
- API call coordination
- Data transformation

### Data Layer
- **Models**: Data classes with JSON serialization
- **Repositories**: Data access abstraction
- **Datasources**: API and local storage implementation

### Core Layer
- **Network**: Dio HTTP client with auth interceptor
- **Errors**: Failure classes and error handling
- **Utils**: Location utilities, formatters

## Key Patterns

### State Management (Riverpod)
```dart
// Provider definition
final feedStateProvider = StateNotifierProvider<FeedNotifier, FeedState>(...);

// Usage in widgets
class FeedScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedStateProvider);
    // Build UI based on state
  }
}
```

### Navigation (GoRouter)
```dart
// Route definition
GoRoute(
  path: '/profile/:id',
  builder: (context, state) {
    final userId = state.pathParameters['id']!;
    return ProfileScreen(userId: userId);
  },
),

// Navigation
context.push('/profile/123');
context.go('/feed');
```

### API Calls (Dio)
```dart
// With auth interceptor
final response = await _apiClient.get('/feed', queryParameters: {
  'latitude': lat,
  'longitude': lng,
  'radius_km': 5,
});
```

### Real-Time Notifications (SSE & FCM)
- **Foreground (SSE):** `NotificationService` maintains a persistent HTTP connection to the backend `/notifications/stream` using Dio. Events are parsed and propagated to Riverpod (`notificationStreamProvider`).
- **Background (FCM):** `PushNotificationService` uses Firebase Cloud Messaging to wake the app or display native banners when the app is backgrounded or terminated. Token synchronization happens automatically on login.

## Configuration

| Setting | Location | Value |
|---------|----------|-------|
| API Base URL | `app_config.dart` | `http://localhost:8080` |
| Bundle ID | Info.plist | `com.irphotoarts.geoloc_app` |
| Min iOS | Podfile | 13.0 |
| Default Feed Radius | `app_config.dart` | 5km |
| Geohash Precision | `app_config.dart` | 5 (~5km) |
