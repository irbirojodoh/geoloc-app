# Flutter Learning Guide for Geoloc

A practical guide to understanding Flutter through the Geoloc project.

---

## 1. Flutter Basics

### What is Flutter?
Flutter is Google's UI toolkit for building native mobile apps from a single codebase. You write **Dart** code that compiles to native iOS and Android.

### Everything is a Widget
In Flutter, UI is built with **widgets** - small, composable building blocks.

```dart
// A simple widget
Text('Hello World')

// Widgets can be nested
Container(
  padding: EdgeInsets.all(16),
  child: Text('Hello World'),
)
```

### Two Types of Widgets

| Type | When to Use | Example in Geoloc |
|------|-------------|-------------------|
| **StatelessWidget** | UI that doesn't change | `PostCard`, `UserAvatar` |
| **StatefulWidget** | UI with internal state | `LoginScreen` (form inputs) |

---

## 2. Project Structure Explained

### `lib/main.dart` - Entry Point
```dart
void main() {
  runApp(ProviderScope(child: GeolocApp()));
}
```
This starts the app. `ProviderScope` enables Riverpod state management.

### `lib/config/` - Configuration
- **app_config.dart** - Constants (API URL, timeouts)
- **theme.dart** - Colors, fonts, styles
- **routes.dart** - Screen navigation paths

### `lib/presentation/screens/` - UI Screens
Each screen is a widget. Example structure:
```
screens/
├── auth/
│   ├── login_screen.dart
│   └── register_screen.dart
├── feed/
│   └── feed_screen.dart
```

### `lib/services/` - Business Logic
Services handle API calls and data processing:
```dart
// auth_service.dart
Future<User> login({email, password}) async {
  final response = await _apiClient.post('/auth/login', data: {...});
  return User.fromJson(response.data);
}
```

---

## 3. State Management with Riverpod

### Why Riverpod?
Riverpod manages app state (user data, loading states, etc.) across widgets.

### Key Concepts

**Provider** - Holds a value
```dart
final userProvider = Provider<User>((ref) => User(...));
```

**StateNotifier** - Holds mutable state
```dart
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.initial());
  
  void login() {
    state = state.copyWith(isLoading: true);
    // ... do login
    state = AuthState.authenticated(user);
  }
}
```

**ConsumerWidget** - Widget that reads providers
```dart
class FeedScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final feedState = ref.watch(feedStateProvider);
    // Use feedState to build UI
  }
}
```

### In Geoloc
- `auth_provider.dart` - Login state, current user
- `location_provider.dart` - GPS position
- `feed_provider.dart` - Posts list, pagination

---

## 4. Navigation with GoRouter

### Defining Routes
```dart
// routes.dart
GoRoute(
  path: '/login',
  builder: (context, state) => LoginScreen(),
),
GoRoute(
  path: '/profile/:userId',
  builder: (context, state) {
    final userId = state.pathParameters['userId']!;
    return ProfileScreen(userId: userId);
  },
),
```

### Navigating
```dart
// Go to a screen (replaces current)
context.go('/feed');

// Push a screen (adds to stack)
context.push('/profile/123');

// Go back
context.pop();
```

---

## 5. API Calls with Dio

### Making Requests
```dart
// In auth_service.dart
final response = await _apiClient.post(
  '/auth/login',
  data: {'email': email, 'password': password},
);

if (response.statusCode == 200) {
  return User.fromJson(response.data['user']);
}
```

### Auth Interceptor
Automatically adds JWT token to requests:
```dart
// auth_interceptor.dart
options.headers['Authorization'] = 'Bearer $accessToken';
```

---

## 6. Building UI

### Common Widgets

| Widget | Purpose | Example |
|--------|---------|---------|
| `Container` | Box with padding, color, size | Wrapper for content |
| `Column` | Stack children vertically | Form fields |
| `Row` | Stack children horizontally | Action buttons |
| `ListView` | Scrollable list | Feed posts |
| `Card` | Material design card | Post card |
| `TextFormField` | Input with validation | Login form |

### Example: Login Form
```dart
TextFormField(
  controller: _emailController,
  decoration: InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email),
  ),
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
    return null;
  },
)
```

### Styling with Theme
```dart
// Access theme in widgets
final theme = Theme.of(context);

Text(
  'Hello',
  style: theme.textTheme.headlineLarge,
)
```

---

## 7. Common Patterns in Geoloc

### Loading States
```dart
if (state.isLoading) {
  return CircularProgressIndicator();
}
```

### Error Handling
```dart
if (state.error != null) {
  return Text('Error: ${state.error}');
}
```

### Pull to Refresh
```dart
RefreshIndicator(
  onRefresh: () => ref.read(feedProvider.notifier).refresh(),
  child: ListView(...),
)
```

### Infinite Scroll
```dart
_scrollController.addListener(() {
  if (_scrollController.position.pixels >= 
      _scrollController.position.maxScrollExtent - 200) {
    ref.read(feedProvider.notifier).loadMore();
  }
});
```

---

## 8. Quick Reference

### Run Commands
```bash
flutter run              # Run on default device
flutter run -d ios       # Run on iOS simulator
flutter hot reload       # Press 'r' while running
flutter analyze          # Check for errors
flutter test             # Run tests
```

### File Naming
- Screens: `login_screen.dart`
- Widgets: `post_card.dart`
- Services: `auth_service.dart`
- Providers: `auth_provider.dart`
- Models: `user.dart`

### Useful Resources
- [Flutter Docs](https://docs.flutter.dev)
- [Dart Language Tour](https://dart.dev/language)
- [Riverpod Docs](https://riverpod.dev)
- [GoRouter Docs](https://pub.dev/packages/go_router)

---

## 9. Next Steps

1. **Explore the code** - Start with `main.dart`, then `routes.dart`
2. **Modify a screen** - Try changing text or colors in `login_screen.dart`
3. **Add a feature** - Create a new widget or screen
4. **Run tests** - Write a simple widget test

The best way to learn is by experimenting. Break things, fix them, and you'll understand how it all works!
