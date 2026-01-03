# Geoloc Flutter App - Agent Context

## Project Overview

**Geoloc** is a hyper-local social media mobile app built with Flutter, targeting iOS first. Users can share posts that are tied to their geographic location, and see content from others nearby.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.38+ |
| Language | Dart |
| State Management | Riverpod |
| Navigation | GoRouter |
| HTTP Client | Dio |
| Local Storage | flutter_secure_storage, Hive |
| Location | Geolocator |
| Backend | Go + Cassandra (separate repo) |

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── app.dart                  # Root MaterialApp
├── config/
│   ├── app_config.dart       # API URLs, constants
│   ├── routes.dart           # GoRouter configuration
│   └── theme.dart            # Material 3 themes
├── core/
│   ├── errors/failures.dart  # Error handling
│   ├── network/
│   │   ├── api_client.dart   # Dio wrapper
│   │   ├── auth_interceptor.dart  # JWT handling
│   │   └── api_endpoints.dart
│   └── utils/
│       └── location_utils.dart  # Geohash utilities
├── data/models/              # Data classes
│   ├── user.dart
│   ├── post.dart
│   ├── comment.dart
│   └── ...
├── presentation/
│   ├── providers/            # Riverpod state
│   ├── screens/              # UI screens
│   └── widgets/              # Reusable widgets
└── services/                 # Business logic
    ├── auth_service.dart
    ├── location_service.dart
    └── push_notification_service.dart
```

## Key Configuration

| Setting | Value |
|---------|-------|
| Bundle ID | `com.irphotoarts.geoloc_app` |
| Min iOS | 13.0 |
| API Base URL | `http://localhost:8080` |
| Default Feed Radius | 5km |
| Geohash Precision | 5 (~5km) |

## Backend API

The backend runs on `localhost:8080` with these key endpoints:

```
POST /auth/register    - Create account
POST /auth/login       - Login
POST /auth/refresh     - Refresh JWT
GET  /feed             - Get nearby posts
POST /posts            - Create post
GET  /users/:id        - Get user profile
```

## Running the App

```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Current State

- ✅ Project initialized
- ✅ Core infrastructure (API client, auth, routing)
- ✅ Data models
- ✅ Auth screens (login, register)
- ✅ Feed screen with location-based loading
- ⏳ Profile, search, notifications (placeholders)
- ⏳ Firebase push notifications (needs GoogleService-Info.plist)

## Development Notes

1. **Firebase not configured** - Push notifications are stubbed. Add `GoogleService-Info.plist` to enable.
2. **Backend required** - API calls need the Go backend running on port 8080.
3. **iOS only** - Focused on iOS first; Android config may need updates.
