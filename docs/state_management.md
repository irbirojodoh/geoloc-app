# State Management

Geoloc uses **Riverpod** for state management, providing a robust, testable, and compile-safe solution.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Widgets                            │
│                  (ConsumerWidget/StatefulWidget)             │
│                            │                                 │
│                       ref.watch()                            │
│                            ▼                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                      Providers                        │   │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐      │   │
│  │  │   Auth     │  │    Feed    │  │  Location  │      │   │
│  │  │  Provider  │  │  Provider  │  │  Provider  │      │   │
│  │  └────────────┘  └────────────┘  └────────────┘      │   │
│  └──────────────────────────────────────────────────────┘   │
│                            │                                 │
│                       Services                               │
│                            ▼                                 │
│                      API / Storage                           │
└─────────────────────────────────────────────────────────────┘
```

## Providers

### Auth Provider
**File**: `lib/presentation/providers/auth_provider.dart`

Manages authentication state, current user, and login/logout flows.

```dart
// State class
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final User? user;
  final String? error;
}

// Provider definition
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

// Current user shortcut
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});
```

**Actions**:
- `login(email, password)` - Authenticate user
- `register(email, password, username, fullName)` - Create account
- `logout()` - Clear session
- `refreshToken()` - Refresh JWT token
- `loadUser()` - Fetch current user profile

---

### Location Provider
**File**: `lib/presentation/providers/location_provider.dart`

Manages GPS location and address resolution.

```dart
// State class
class LocationState {
  final Position? position;
  final String? address;
  final bool isLoading;
  final String? error;
}

// Provider
final locationStateProvider = StateNotifierProvider<LocationNotifier, LocationState>(...);
```

**Actions**:
- `getCurrentLocation()` - Get GPS coordinates
- `getAddressFromCoordinates(lat, lng)` - Reverse geocode

---

### Feed Provider
**File**: `lib/presentation/providers/feed_provider.dart`

Manages the post feed with pagination and refresh.

```dart
// State class
class FeedState {
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? cursor;
}

// Provider
final feedStateProvider = StateNotifierProvider<FeedNotifier, FeedState>(...);
```

**Actions**:
- `loadFeed(lat, lng, radiusKm)` - Initial feed load
- `loadMore()` - Pagination (infinite scroll)
- `refresh()` - Pull-to-refresh
- `likePost(postId)` - Toggle like
- `deletePost(postId)` - Remove post

---

### Create Post Provider
**File**: `lib/presentation/providers/create_post_provider.dart`

Manages post creation flow with media and location.

```dart
// State class
class CreatePostState {
  final String content;
  final List<File> mediaFiles;
  final Position? location;
  final String? address;
  final bool isSubmitting;
  final String? error;
}

// Provider
final createPostStateProvider = StateNotifierProvider<CreatePostNotifier, CreatePostState>(...);
```

**Actions**:
- `setContent(text)` - Update post text
- `addMedia(file)` - Add photo/video
- `removeMedia(index)` - Remove media
- `setLocation(position)` - Set post location
- `submit()` - Create the post

---

### Post Detail Provider
**File**: `lib/presentation/providers/post_detail_provider.dart`

Manages single post view with comments.

```dart
// State class
class PostDetailState {
  final Post? post;
  final List<Comment> comments;
  final bool isLoading;
  final bool isSubmittingComment;
  final String? error;
}

// Provider (family for different post IDs)
final postDetailProvider = StateNotifierProvider.family<PostDetailNotifier, PostDetailState, String>(...);
```

**Actions**:
- `loadPost(postId)` - Fetch post details
- `loadComments()` - Fetch comments
- `addComment(content)` - Post a comment
- `deleteComment(commentId)` - Remove comment
- `likePost()` - Toggle like

---

### Profile Provider
**File**: `lib/presentation/providers/profile_provider.dart`

Manages user profile view and follow actions.

```dart
// State class
class ProfileState {
  final User? user;
  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingPosts;
  final String? error;
}

// Provider (family for different user IDs)
final profileProvider = StateNotifierProvider.family<ProfileNotifier, ProfileState, String>(...);
```

**Actions**:
- `loadProfile(userId)` - Fetch user profile
- `loadUserPosts()` - Fetch user's posts
- `follow()` - Follow user
- `unfollow()` - Unfollow user
- `updateProfile(data)` - Edit profile

---

## Usage Patterns

### Reading State
```dart
class FeedScreen extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch for changes (rebuilds on change)
    final feedState = ref.watch(feedStateProvider);
    
    // Read without subscribing (one-time read)
    final user = ref.read(currentUserProvider);
    
    return feedState.isLoading
        ? CircularProgressIndicator()
        : ListView.builder(...);
  }
}
```

### Triggering Actions
```dart
// In a button callback
onPressed: () {
  ref.read(feedStateProvider.notifier).refresh();
}

// In initState
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(locationStateProvider.notifier).getCurrentLocation();
  });
}
```

### Family Providers
```dart
// Provider that takes a parameter
final profileProvider = StateNotifierProvider.family<..., String>(...);

// Usage - each userId gets its own state
final profileState = ref.watch(profileProvider('user-123'));
```

### Listening for Side Effects
```dart
ref.listen<AuthState>(authStateProvider, (previous, next) {
  if (next.error != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next.error!)),
    );
  }
});
```

## State Patterns

### Loading States
```dart
if (state.isLoading) {
  return Center(child: CircularProgressIndicator());
}
```

### Error Handling
```dart
if (state.error != null) {
  return ErrorWidget(
    message: state.error!,
    onRetry: () => ref.read(provider.notifier).retry(),
  );
}
```

### Empty States
```dart
if (state.posts.isEmpty) {
  return EmptyStateWidget(message: 'No posts yet');
}
```

### Optimistic Updates
```dart
// Immediately update UI, revert on error
void likePost(String postId) {
  final currentPosts = state.posts;
  final index = currentPosts.indexWhere((p) => p.id == postId);
  
  // Optimistic update
  state = state.copyWith(
    posts: [...currentPosts]..[index] = currentPosts[index].copyWith(
      isLiked: true,
      likeCount: currentPosts[index].likeCount + 1,
    ),
  );
  
  // API call
  try {
    await _service.likePost(postId);
  } catch (e) {
    // Revert on error
    state = state.copyWith(posts: currentPosts);
  }
}
```
