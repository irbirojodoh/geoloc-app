# Geoloc

A hyper-local social media app built with Flutter. Share and discover content from people in your neighborhood.

![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![iOS](https://img.shields.io/badge/iOS-13.0+-000000?logo=apple)

## Features

- 📍 **Location-Based Feed** - See posts from people nearby (5km default radius)
- 📝 **Create Posts** - Share text and media tied to your location
- 💬 **Comments** - Engage with 3-level nested replies
- 👥 **User Profiles** - Follow users and view their posts
- 🔔 **Notifications** - Get notified about likes, comments, and follows
- 📌 **Location Following** - Subscribe to geographic areas for updates

## Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter |
| State Management | Riverpod |
| Navigation | GoRouter |
| HTTP Client | Dio |
| Local Storage | flutter_secure_storage, Hive |
| Location | Geolocator |

## Getting Started

### Prerequisites

- Flutter SDK 3.38+
- Xcode 15+ (for iOS)
- iOS Simulator or device

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/geoloc-app-flutter.git
cd geoloc-app-flutter

# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d ios
```

### Backend Setup

The app requires the Go backend running on `localhost:8080`. See the backend repository for setup instructions.

## Project Structure

```
lib/
├── config/         # App configuration, theme, routes
├── core/           # Network layer, utilities, errors
├── data/models/    # Data classes
├── presentation/   # UI (screens, widgets, providers)
└── services/       # Business logic
```

## Configuration

Update `lib/config/app_config.dart` for:

```dart
static const String apiBaseUrl = 'http://localhost:8080';
static const double defaultFeedRadiusKm = 5.0;
```

## Development

```bash
# Hot reload (while running)
r

# Run tests
flutter test

# Analyze code
flutter analyze

# Build for iOS
flutter build ios
```

## Documentation

- [Flutter Guide](docs/flutter_guide.md) - Learn Flutter with this project
- [AGENT.md](AGENT.md) - Project context and architecture

## License

MIT License - See [LICENSE](LICENSE) for details.
