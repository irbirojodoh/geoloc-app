# Geoloc Documentation

Complete documentation for the Geoloc Flutter application.

## Contents

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | App architecture, layers, and patterns |
| [Screens & Navigation](./screens.md) | All screens and routing |
| [State Management](./state_management.md) | Riverpod providers and state |
| [Data Models](./data_models.md) | Domain models and API contracts |
| [Services](./services.md) | Business logic and API integration |
| [Flutter Guide](./flutter_guide.md) | Learning guide for Flutter beginners |

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Project Overview

**Geoloc** is a hyper-local social media app where users share posts tied to their geographic location and discover content from nearby users.

### Key Features
- 📍 Location-based feed with nearby posts
- ✍️ Create posts with text, media, and location
- 👤 User profiles with follow system
- 🔔 Notifications for likes, comments, and follows
- 🔍 Search for users and content

### Tech Stack

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
