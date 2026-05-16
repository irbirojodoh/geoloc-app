# Screens & Navigation

## Screen Overview

| Screen | Path | Description |
|--------|------|-------------|
| Splash | `/` | Initial loading, redirects based on auth |
| Login | `/login` | User authentication |
| Register | `/register` | New user registration |
| Feed | `/feed` | Main feed with nearby posts |
| Create Post | `/create-post` | Compose new post |
| Post Detail | `/post/:id` | Single post with comments |
| Profile | `/profile/:id` | User profile view |
| Edit Profile | `/profile/edit` | Edit own profile |
| Search | `/search` | Search users and content |
| Notifications | `/notifications` | Activity notifications |

## Navigation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                         App Start                            │
│                            │                                 │
│                            ▼                                 │
│                      ┌─────────┐                             │
│                      │ Splash  │                             │
│                      └────┬────┘                             │
│                           │                                  │
│              ┌────────────┴────────────┐                     │
│              │                         │                     │
│        Authenticated?            Not Authenticated           │
│              │                         │                     │
│              ▼                         ▼                     │
│         ┌────────┐              ┌──────────┐                │
│         │  Feed  │              │  Login   │                │
│         └────────┘              └────┬─────┘                │
│                                      │                       │
│                                      ▼                       │
│                               ┌──────────┐                  │
│                               │ Register │                  │
│                               └──────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## Screen Details

### Authentication Screens

#### Login Screen (`/login`)
**File**: `lib/presentation/screens/auth/login_screen.dart`

Features:
- Email/password login form
- Social login buttons (Google, Apple - placeholder)
- Forgot password link
- Register navigation
- Dynamic light/dark mode theming
- Keyboard-adaptive layout

#### Register Screen (`/register`)
**File**: `lib/presentation/screens/auth/register_screen.dart`

Features:
- Full name, username, email, password fields
- Terms of service agreement
- Form validation
- Slide-up transition animation
- Keyboard-adaptive scrolling

---

### Main App Screens

#### Feed Screen (`/feed`)
**File**: `lib/presentation/screens/feed/feed_screen.dart`

Features:
- Location-based post feed
- Pull-to-refresh
- Infinite scroll pagination
- Post cards with author, content, location
- Like/comment actions
- Navigation to post detail, profile
- Bottom navbar with Home/Search/Notifications/Profile
- Inline `+` compose action appears on Home only

#### Create Post Screen (`/create-post`)
**File**: `lib/presentation/screens/post/create_post_screen.dart`

Features:
- Text content input
- Media picker (photo/video)
- Current location detection
- Address display from coordinates
- Post submission

#### Post Detail Screen (`/post/:id`)
**File**: `lib/presentation/screens/post/post_detail_screen.dart`

Features:
- Full post view
- Comments list
- Add comment input
- Like button
- Share options
- Author profile link

---

### Profile Screens

#### Profile Screen (`/profile/:id`)
**File**: `lib/presentation/screens/profile/profile_screen.dart`

Features:
- User info display (avatar, name, bio)
- Followers/following counts
- Follow/unfollow button (for other users)
- Edit profile button (for own profile)
- User's posts list
- Cover image

#### Edit Profile Screen (`/profile/edit`)
**File**: `lib/presentation/screens/profile/edit_profile_screen.dart`

Features:
- Edit full name, username, bio
- Change profile picture
- Change cover image
- Save changes

---

### Utility Screens

#### Search Screen (`/search`)
**File**: `lib/presentation/screens/search/search_screen.dart`

Features:
- Search input
- User search results
- Post search results
- Recent searches
- Autocomplete users + hashtags

#### Notifications Screen (`/notifications`)
**File**: `lib/presentation/screens/notifications/notifications_screen.dart`

Features:
- Notification list from `/api/v1/notifications`
- Types: likes, comments, follows, nearby posts
- Read-all action
- Navigate to related content
- Pull-to-refresh + limit-based load more

---

## Navigation Implementation

### Route Configuration
**File**: `lib/config/routes.dart`

```dart
class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String feed = '/feed';
  static const String createPost = '/create-post';
  static const String postDetail = '/post/:id';
  static const String profile = '/profile/:id';
  static const String editProfile = '/profile/edit';
  static const String search = '/search';
  static const String notifications = '/notifications';
}
```

### Auth-Based Redirects
```dart
redirect: (context, state) {
  final isLoggedIn = authState.isAuthenticated;
  final isAuthRoute = state.matchedLocation == RoutePaths.login ||
                      state.matchedLocation == RoutePaths.register;

  if (!isLoggedIn && !isAuthRoute) {
    return RoutePaths.login;  // Redirect to login
  }
  if (isLoggedIn && isAuthRoute) {
    return RoutePaths.feed;   // Redirect to feed
  }
  return null;  // No redirect
}
```

### Navigation Methods
```dart
// Replace current screen
context.go('/feed');

// Push onto navigation stack
context.push('/profile/123');

// Go back
context.pop();

// Push with query parameters
context.push('/search?q=flutter');
```

### Custom Transitions
```dart
// Register screen slide-up animation
pageBuilder: (context, state) => CustomTransitionPage(
  child: const RegisterScreen(),
  transitionsBuilder: (context, animation, _, child) {
    return SlideTransition(
      position: Tween(
        begin: Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: child,
    );
  },
),
```

Shell menu pages (`/feed`, `/search`, `/notifications`, `/profile/:id`) use a
directional slide transition. Direction follows navbar order:

- Home = 0
- Search = 1
- Notifications = 2
- Profile = 3

Rules:

- target > current: target enters from right, current exits left
- target < current: target enters from left, current exits right
