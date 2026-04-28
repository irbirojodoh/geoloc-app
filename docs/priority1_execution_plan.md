# Priority 1 Execution Plan

> Detailed implementation guide for MVP-critical features  
> **Status: ✅ ALL TASKS COMPLETE**

---

## Overview

| # | Feature | Files Created/Modified | Status |
|---|---------|----------------------|--------|
| 1 | Edit Profile Screen | 3 files | ✅ Complete |
| 2 | Search Screen | 4 files | ✅ Complete |
| 3 | Notifications Screen | 4 files | ✅ Complete |
| 4 | Follow/Unfollow | 2 files | ✅ Complete |
| 5 | Feed Like Wiring | Already implemented | ✅ Complete |

**Implementation Date:** January 28, 2026  
**Flutter Analyze:** ✅ 0 errors (30 warnings/info only)

---

## 1. Edit Profile Screen

### Files to Modify/Create

| File | Action |
|------|--------|
| `lib/presentation/screens/profile/edit_profile_screen.dart` | Rewrite |
| `lib/presentation/providers/edit_profile_provider.dart` | Create |
| `lib/services/upload_service.dart` | Create |

### Step 1.1: Create Upload Service

**File:** `lib/services/upload_service.dart`

```dart
// Handles image uploads to backend
// Methods:
// - uploadAvatar(File image) -> String avatarUrl
// - uploadCover(File image) -> String coverUrl
// - uploadPostMedia(List<File> files) -> List<String> urls
```

**API Endpoints:**
- `POST /api/v1/upload/avatar` - multipart form data
- `POST /api/v1/upload/cover` - multipart form data

### Step 1.2: Create Edit Profile Provider

**File:** `lib/presentation/providers/edit_profile_provider.dart`

**State Class:**
```dart
class EditProfileState {
  final User? originalUser;
  final String fullName;
  final String username;
  final String bio;
  final File? newProfileImage;
  final File? newCoverImage;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool hasChanges;
  final bool saveSuccess;
}
```

**Provider Methods:**
- `loadProfile()` - Load current user data
- `updateFullName(String)` - Update local state
- `updateUsername(String)` - Update local state  
- `updateBio(String)` - Update local state
- `pickProfileImage(ImageSource)` - Pick and crop image
- `pickCoverImage(ImageSource)` - Pick and crop image
- `saveProfile()` - Upload images (if changed) + update profile
- `discardChanges()` - Reset to original

### Step 1.3: Implement Edit Profile Screen UI

**File:** `lib/presentation/screens/profile/edit_profile_screen.dart`

**UI Components:**
1. **Header** - Back button, title, Save button
2. **Cover Image Section**
   - Current/new cover image display
   - Edit overlay button
   - Camera/Gallery picker
3. **Profile Picture Section**
   - Circular avatar
   - Edit overlay button
   - Camera/Gallery picker with crop
4. **Form Fields**
   - Full Name (TextFormField)
   - Username (TextFormField with @prefix)
   - Bio (TextFormField, multiline, max 150 chars)
5. **Validation**
   - Username: 3-30 chars, alphanumeric + underscore
   - Full Name: required, max 50 chars
   - Bio: optional, max 150 chars

**User Interactions:**
- Tap cover → show picker sheet
- Tap avatar → show picker sheet
- Edit any field → enable Save button
- Tap Save → validate + upload + save
- Tap Back with changes → show discard dialog

### Step 1.4: Integration Checklist

- [ ] Create `upload_service.dart`
- [ ] Create `edit_profile_provider.dart`
- [ ] Rewrite `edit_profile_screen.dart`
- [ ] Add image cropper for avatar (1:1 ratio)
- [ ] Add image cropper for cover (16:9 ratio)
- [ ] Handle loading states
- [ ] Handle error states
- [ ] Add haptic feedback on save
- [ ] Update profile screen after save
- [ ] Test dark/light mode

---

## 2. Search Screen

### Files to Modify/Create

| File | Action |
|------|--------|
| `lib/presentation/screens/search/search_screen.dart` | Rewrite |
| `lib/presentation/providers/search_provider.dart` | Create |
| `lib/services/search_service.dart` | Create |
| `lib/data/models/search_result.dart` | Create |

### Step 2.1: Create Search Service

**File:** `lib/services/search_service.dart`

```dart
class SearchService {
  // Search users by query
  Future<List<User>> searchUsers(String query, {int limit = 20});
  
  // Search posts by content
  Future<List<Post>> searchPosts(String query, {int limit = 20});
  
  // Get suggested users (nearby or popular)
  Future<List<User>> getSuggestedUsers({int limit = 10});
}
```

**API Endpoints:**
- `GET /api/v1/search/users?q={query}&limit={limit}`
- `GET /api/v1/search/posts?q={query}&limit={limit}`

### Step 2.2: Create Search Provider

**File:** `lib/presentation/providers/search_provider.dart`

**State Class:**
```dart
class SearchState {
  final String query;
  final SearchTab activeTab; // users, posts
  final List<User> userResults;
  final List<Post> postResults;
  final List<String> recentSearches;
  final List<User> suggestedUsers;
  final bool isLoading;
  final String? error;
}

enum SearchTab { users, posts }
```

**Provider Methods:**
- `search(String query)` - Debounced search (300ms)
- `setActiveTab(SearchTab)` - Switch tabs
- `clearSearch()` - Clear query and results
- `addRecentSearch(String)` - Save to Hive
- `removeRecentSearch(String)` - Remove from Hive
- `clearRecentSearches()` - Clear all history
- `loadSuggestedUsers()` - Load on screen open

### Step 2.3: Implement Search Screen UI

**File:** `lib/presentation/screens/search/search_screen.dart`

**UI Components:**
1. **Search Header**
   - Search TextField with clear button
   - Cancel button (pops screen)
2. **Tab Bar** (when query exists)
   - Users tab
   - Posts tab
3. **Initial State** (no query)
   - Recent searches list
   - Suggested users section
4. **Search Results**
   - Users: UserListTile with follow button
   - Posts: PostCard (reuse existing)
5. **Empty States**
   - No results found
   - No recent searches

**User Interactions:**
- Type query → debounced search (300ms)
- Tap user → navigate to profile
- Tap post → navigate to post detail
- Tap recent search → populate and search
- Swipe recent search → delete
- Tap clear → clear all recent

### Step 2.4: Create Search Result Widgets

**New Widgets Needed:**
- `UserSearchTile` - Avatar, username, full name, follow button
- `SearchEmptyState` - Illustration + message

### Step 2.5: Integration Checklist

- [ ] Create `search_service.dart`
- [ ] Create `search_provider.dart`
- [ ] Setup Hive box for recent searches
- [ ] Rewrite `search_screen.dart`
- [ ] Create `UserSearchTile` widget
- [ ] Implement debounced search
- [ ] Add keyboard dismiss on scroll
- [ ] Handle loading states
- [ ] Handle error states
- [ ] Test navigation to profile/post
- [ ] Test dark/light mode

---

## 3. Notifications Screen

### Files to Modify/Create

| File | Action |
|------|--------|
| `lib/presentation/screens/notifications/notifications_screen.dart` | Rewrite |
| `lib/presentation/providers/notifications_provider.dart` | Create |
| `lib/services/notification_service.dart` | Create |
| `lib/data/models/notification.dart` | Review/Update |

### Step 3.1: Review Notification Model

**File:** `lib/data/models/notification.dart`

Ensure model supports:
```dart
class AppNotification {
  final String id;
  final String type; // like, comment, follow, nearby_post
  final String? actorId;
  final User? actor;
  final String? postId;
  final String? commentId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
}
```

### Step 3.2: Create Notification Service

**File:** `lib/services/notification_service.dart`

```dart
class NotificationService {
  // Get paginated notifications
  Future<NotificationPage> getNotifications({String? cursor, int limit = 20});
  
  // Mark single notification as read
  Future<void> markAsRead(String notificationId);
  
  // Mark all notifications as read
  Future<void> markAllAsRead();
  
  // Get unread count (for badge)
  Future<int> getUnreadCount();
}
```

**API Endpoints:**
- `GET /api/v1/notifications?cursor={cursor}&limit={limit}`
- `PUT /api/v1/notifications/:id/read`
- `PUT /api/v1/notifications/read-all`
- `GET /api/v1/notifications/unread-count`

### Step 3.3: Create Notifications Provider

**File:** `lib/presentation/providers/notifications_provider.dart`

**State Class:**
```dart
class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final String? cursor;
  final String? error;
  final int unreadCount;
}
```

**Provider Methods:**
- `loadNotifications()` - Initial load
- `refreshNotifications()` - Pull to refresh
- `loadMore()` - Pagination
- `markAsRead(String id)` - Mark single
- `markAllAsRead()` - Mark all

### Step 3.4: Implement Notifications Screen UI

**File:** `lib/presentation/screens/notifications/notifications_screen.dart`

**UI Components:**
1. **Header**
   - Title: "Notifications"
   - "Mark all read" button
2. **Notification List**
   - Pull to refresh
   - Infinite scroll pagination
   - Grouped by date (Today, Yesterday, This Week, Older)
3. **Notification Tile**
   - Actor avatar
   - Notification icon (heart, comment, person, pin)
   - Message text
   - Time ago
   - Unread indicator (blue dot)
   - Post thumbnail (if applicable)
4. **Empty State**
   - Illustration
   - "All caught up!" message

**Notification Type Icons:**
| Type | Icon | Color |
|------|------|-------|
| like | heart.fill | red |
| comment | bubble.left.fill | blue |
| follow | person.badge.plus | green |
| nearby_post | mappin.circle.fill | orange |

**User Interactions:**
- Tap notification → navigate to related content + mark read
- Pull down → refresh
- Scroll to bottom → load more
- Tap "Mark all read" → mark all + update UI

### Step 3.5: Integration Checklist

- [ ] Review/update `notification.dart` model
- [ ] Create `notification_service.dart`
- [ ] Create `notifications_provider.dart`
- [ ] Rewrite `notifications_screen.dart`
- [ ] Create notification tile widget
- [ ] Implement date grouping
- [ ] Add unread indicator
- [ ] Add pull to refresh
- [ ] Add pagination
- [ ] Add empty state
- [ ] Test deep link navigation
- [ ] Test dark/light mode

---

## 4. Follow/Unfollow Functionality

### Files to Modify

| File | Action |
|------|--------|
| `lib/presentation/providers/profile_provider.dart` | Modify |
| `lib/presentation/screens/profile/profile_screen.dart` | Modify |

### Step 4.1: Add Follow Methods to Profile Provider

**File:** `lib/presentation/providers/profile_provider.dart`

**Add to ProfileState:**
```dart
final bool isFollowLoading; // Loading state for follow button
```

**Add Methods:**
```dart
// Follow a user
Future<void> followUser() async {
  // 1. Set isFollowLoading = true
  // 2. Optimistic update: isFollowing = true, followersCount++
  // 3. Call API: POST /api/v1/users/:id/follow
  // 4. On error: rollback changes
  // 5. Set isFollowLoading = false
}

// Unfollow a user
Future<void> unfollowUser() async {
  // 1. Set isFollowLoading = true
  // 2. Optimistic update: isFollowing = false, followersCount--
  // 3. Call API: DELETE /api/v1/users/:id/follow
  // 4. On error: rollback changes
  // 5. Set isFollowLoading = false
}

// Toggle follow state
Future<void> toggleFollow() async {
  if (state.user?.isFollowing == true) {
    await unfollowUser();
  } else {
    await followUser();
  }
}
```

### Step 4.2: Wire Up Follow Button in Profile Screen

**File:** `lib/presentation/screens/profile/profile_screen.dart`

**Locate the follow button and update:**
```dart
// Find the follow/unfollow button in _buildProfileInfo
// Currently it likely has onPressed: () {}

// Update to:
CupertinoButton(
  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
  color: profileState.user!.isFollowing == true
      ? CupertinoColors.systemGrey5
      : CupertinoColors.activeBlue,
  onPressed: profileState.isFollowLoading
      ? null
      : () => ref.read(profileProvider(widget.userId).notifier).toggleFollow(),
  child: profileState.isFollowLoading
      ? CupertinoActivityIndicator()
      : Text(
          profileState.user!.isFollowing == true ? 'Following' : 'Follow',
          style: TextStyle(
            color: profileState.user!.isFollowing == true
                ? CupertinoColors.label
                : CupertinoColors.white,
          ),
        ),
)
```

### Step 4.3: Add Haptic Feedback

```dart
import 'package:flutter/services.dart';

// In toggleFollow:
HapticFeedback.mediumImpact();
```

### Step 4.4: Integration Checklist

- [ ] Add `isFollowLoading` to ProfileState
- [ ] Implement `followUser()` method
- [ ] Implement `unfollowUser()` method
- [ ] Implement `toggleFollow()` method
- [ ] Wire up follow button onPressed
- [ ] Add loading state to button
- [ ] Add haptic feedback
- [ ] Handle API errors with rollback
- [ ] Test follow/unfollow flow
- [ ] Verify follower count updates

---

## 5. Feed Like Button Wiring

### Files to Modify

| File | Action |
|------|--------|
| `lib/presentation/providers/feed_provider.dart` | Modify |
| `lib/presentation/screens/feed/feed_screen.dart` | Modify |

### Step 5.1: Add Like Method to Feed Provider

**File:** `lib/presentation/providers/feed_provider.dart`

**Add Method:**
```dart
/// Toggle like for a post in the feed
Future<void> toggleLike(String postId) async {
  // 1. Find post in state.posts
  final postIndex = state.posts.indexWhere((p) => p.id == postId);
  if (postIndex == -1) return;
  
  final post = state.posts[postIndex];
  final newIsLiked = !post.isLiked;
  final newLikeCount = post.likeCount + (newIsLiked ? 1 : -1);
  
  // 2. Optimistic update
  final updatedPost = post.copyWith(
    isLiked: newIsLiked,
    likeCount: newLikeCount,
  );
  final updatedPosts = [...state.posts];
  updatedPosts[postIndex] = updatedPost;
  state = state.copyWith(posts: updatedPosts);
  
  // 3. Haptic feedback
  HapticFeedback.lightImpact();
  
  // 4. Call API
  try {
    final likeService = _ref.read(likeServiceProvider);
    await likeService.togglePostLike(postId, newIsLiked);
  } catch (e) {
    // 5. Rollback on error
    final rollbackPosts = [...state.posts];
    rollbackPosts[postIndex] = post;
    state = state.copyWith(posts: rollbackPosts);
  }
}
```

### Step 5.2: Wire Up Like Button in Feed Screen

**File:** `lib/presentation/screens/feed/feed_screen.dart`

**Locate PostCard usage and update onLike:**
```dart
// Find where PostCard is used in the feed list
// Currently it likely has onLike: () {}

// Update to:
PostCard(
  post: post,
  onTap: () => context.push('/post/${post.id}'),
  onLike: () => ref.read(feedStateProvider.notifier).toggleLike(post.id),
  onComment: () => context.push('/post/${post.id}'),
  onShare: () {}, // TODO: Implement share
  onUserTap: () => context.push('/profile/${post.userId}'),
)
```

### Step 5.3: Ensure Post Model Has copyWith

**File:** `lib/data/models/post.dart`

Verify `Post` has a `copyWith` method:
```dart
Post copyWith({
  String? id,
  String? userId,
  String? content,
  List<String>? mediaUrls,
  int? likeCount,
  int? commentCount,
  bool? isLiked,
  // ... other fields
});
```

### Step 5.4: Integration Checklist

- [ ] Verify Post model has `copyWith`
- [ ] Add `toggleLike()` to FeedNotifier
- [ ] Import LikeService in feed_provider
- [ ] Wire up `onLike` callback in FeedScreen
- [ ] Add haptic feedback
- [ ] Handle API errors with rollback
- [ ] Test like/unlike animation
- [ ] Verify like count updates
- [ ] Test in both light/dark mode

---

## Testing Checklist

### Unit Tests to Add

```
test/
├── services/
│   ├── upload_service_test.dart
│   ├── search_service_test.dart
│   └── notification_service_test.dart
├── providers/
│   ├── edit_profile_provider_test.dart
│   ├── search_provider_test.dart
│   └── notifications_provider_test.dart
```

### Manual Testing Scenarios

| Feature | Test Case |
|---------|-----------|
| Edit Profile | Change name → Save → Verify in profile |
| Edit Profile | Change avatar → Verify crop → Save |
| Edit Profile | Back with changes → Confirm discard |
| Search | Type query → See results debounced |
| Search | Tap user → Navigate to profile |
| Search | Recent search → Tap → Execute search |
| Notifications | Tap like notification → Go to post |
| Notifications | Mark all read → All dots disappear |
| Follow | Tap follow → Count increases |
| Follow | Tap following → Confirm unfollow |
| Feed Like | Tap heart → Fills red, count +1 |
| Feed Like | Tap again → Heart unfills, count -1 |

---

## Definition of Done

Each feature is complete when:

- [ ] All UI components implemented
- [ ] Provider/State management working
- [ ] API integration complete
- [ ] Loading states shown
- [ ] Error states handled
- [ ] Empty states designed
- [ ] Haptic feedback added
- [ ] Dark/Light mode tested
- [ ] No console errors
- [ ] Code reviewed
