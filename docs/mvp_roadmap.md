# Geoloc MVP Roadmap

> Last Updated: January 28, 2026  
> **Status: ✅ Priority 1 Complete - MVP Ready!**

## 📊 Current State Analysis

### ✅ What's Already Implemented

| Component | Status | Quality |
|-----------|--------|---------|
| Authentication (Login/Register) | ✅ Complete | Polished UI, JWT handling |
| Feed Screen | ✅ Complete | Pull-to-refresh, pagination, location-based |
| Create Post Screen | ✅ Complete | Media picker, location display |
| Post Detail Screen | ✅ Complete | Comments, likes working |
| Profile Screen | ✅ Complete | Cover image, posts list, follow counts |
| Post Card Widget | ✅ Complete | Cupertino styling, dynamic colors |
| Like Service | ✅ Complete | Optimistic UI pattern |
| Location Service | ✅ Complete | Permission handling |
| API Client + Interceptors | ✅ Complete | Auth refresh, error handling |
| Dark/Light Mode | ✅ Complete | Consistent theming |
| **Search Screen** | ✅ Complete | User/post search, debounce, recent history |
| **Notifications Screen** | ✅ Complete | Grouped list, mark read, deep-links |
| **Edit Profile Screen** | ✅ Complete | Form fields, image picker, validation |
| **Follow/Unfollow** | ✅ Complete | Loading state, optimistic updates |

### ~~⚠️ Placeholder/Incomplete Screens~~ (All Complete!)

| Screen | Status | Implementation |
|--------|--------|----------------|
| **Search Screen** | ✅ Complete | Full implementation with tabs |
| **Notifications Screen** | ✅ Complete | Grouped by date, all features |
| **Edit Profile Screen** | ✅ Complete | Full form with image upload |

---

## ✅ Priority 1 - Critical for MVP (COMPLETE!)

### 1. ✅ Complete Search Screen
**File:** `lib/presentation/screens/search/search_screen.dart`

**Implemented:**
- [x] User search by username/name
- [x] Post search by content
- [x] Recent search history (local storage with Hive)
- [x] Trending/nearby users suggestions
- [x] Debounced search input (300ms)
- [x] Loading states
- [x] Empty/no results state
- [x] Users/Posts tabbed interface

---

### 2. ✅ Complete Notifications Screen
**File:** `lib/presentation/screens/notifications/notifications_screen.dart`

**Implemented:**
- [x] List notifications (likes, comments, follows, nearby posts)
- [x] Mark individual notification as read
- [x] Mark all as read button
- [x] Deep-link navigation to related content
- [x] Pull-to-refresh
- [x] Pagination for older notifications
- [x] Empty state design ("All caught up!")
- [x] Notification type icons
- [x] Grouped by date (Today/Yesterday/This Week/Older)

---

### 3. ✅ Complete Edit Profile Screen
**File:** `lib/presentation/screens/profile/edit_profile_screen.dart`

**Implemented:**
- [x] Edit full name field
- [x] Edit username field
- [x] Edit bio field (multiline)
- [x] Profile picture upload/change (gallery)
- [x] Cover image upload/change
- [x] Form validation
- [x] Save button with loading state
- [x] Discard changes confirmation dialog
- [x] Image cropping support

---

### 4. ✅ Follow/Unfollow Functionality
**File:** `lib/presentation/screens/profile/profile_screen.dart`

**Implemented:**
- [x] Wire up follow/unfollow button to API
- [x] Update follower/following counts in real-time
- [x] Optimistic UI updates
- [x] Loading state on button (CupertinoActivityIndicator)
- [x] Error handling with rollback

---

### 5. ✅ Feed Like Button Wiring
**Files:** `lib/presentation/providers/feed_provider.dart`

**Status:** Already implemented - `toggleLike` method was wired to LikeService.
- [x] Connect like action in FeedScreen to LikeService
- [x] Optimistic UI updates in feed state
- [x] Update like count immediately

---

## 🚀 Priority 2 - High Value Features

### 6. Onboarding Flow
New users should have a guided experience.

**Requirements:**
- [ ] Location permission explanation screen (before request)
- [ ] Profile completion prompt after registration
- [ ] Optional: Quick tutorial overlay for first-time users
- [ ] Skip option for all onboarding steps

---

### 7. Empty States Design
Several screens lack proper empty states.

**Requirements:**
- [ ] Feed: "No posts nearby" with radius adjustment option
- [ ] Profile Posts: "No posts yet" with create post CTA
- [ ] Notifications: "All caught up!" illustration
- [ ] Search: "Find people nearby" suggestions
- [ ] Comments: "Be the first to comment" prompt

---

### 8. Error States & Retry Logic
Improve user experience when things go wrong.

**Requirements:**
- [ ] Network error screen with retry button
- [ ] Location permission denied handling with settings link
- [ ] Location services disabled handling
- [ ] Session expired auto-refresh or re-login prompt
- [ ] Server unavailable state

---

### 9. Pull-to-Refresh Consistency
Some screens have it, others don't.

**Requirements:**
- [ ] Add to Notifications screen
- [ ] Add to Search results
- [ ] Consistent refresh indicator style

---

### 10. Loading States (Shimmer)
FeedScreen has `LoadingShimmer` but not consistently used everywhere.

**Requirements:**
- [ ] Profile screen loading shimmer
- [ ] Post detail loading shimmer
- [ ] Notifications loading shimmer
- [ ] Search results loading shimmer

---

## 🚀 Priority 3 - Nice to Have (Post-MVP)

### 11. Location Following
Backend supports subscribing to geographic areas.

**Requirements:**
- [ ] Subscribe to locations
- [ ] Get notifications for posts in followed locations
- [ ] UI for managing followed locations
- [ ] Location suggestions based on activity

---

### 12. Share Posts
**Requirements:**
- [ ] Deep links for sharing
- [ ] Share sheet integration (iOS/Android native)
- [ ] Copy link functionality
- [ ] Share to other apps

---

### 13. Report/Block Users
**Requirements:**
- [ ] Report inappropriate content (posts/comments)
- [ ] Block users
- [ ] Mute notifications from specific users
- [ ] Blocked users management screen

---

### 14. Post Deletion
**Requirements:**
- [ ] Delete own posts
- [ ] Confirmation dialog
- [ ] Handle cascade comment deletion
- [ ] Update feed after deletion

---

### 15. Push Notifications Setup
Firebase is configured in Podfile but commented out in pubspec.

**Requirements:**
- [ ] Enable firebase_core and firebase_messaging in pubspec.yaml
- [ ] Add GoogleService-Info.plist to iOS
- [ ] Add google-services.json to Android
- [ ] Register device tokens on login
- [ ] Handle foreground notifications
- [ ] Handle background notifications
- [ ] Deep-link from notification tap

---

## 📅 Implementation Timeline

### Week 1: Core MVP Completion

| Day | Task | Estimated Hours |
|-----|------|-----------------|
| Day 1 | Edit Profile Screen - UI Layout | 4h |
| Day 2 | Edit Profile Screen - Image upload + API | 4h |
| Day 3 | Search Screen - UI + User search | 4h |
| Day 4 | Search Screen - Post search + History | 4h |
| Day 5 | Notifications Screen - List + Navigation | 4h |
| Day 6 | Follow/Unfollow wiring | 3h |
| Day 7 | Feed like button wiring + Testing | 3h |

### Week 2: Polish & Error Handling

| Day | Task | Estimated Hours |
|-----|------|-----------------|
| Day 1 | Empty states for Feed, Profile | 3h |
| Day 2 | Empty states for Notifications, Search | 3h |
| Day 3 | Error handling - Network errors | 4h |
| Day 4 | Error handling - Location, Auth | 4h |
| Day 5 | Loading shimmer consistency | 3h |
| Day 6 | Bug fixes + Edge cases | 4h |
| Day 7 | Final testing + Polish | 4h |

---

## 📋 Summary

| Category | Count | Status |
|----------|-------|--------|
| Critical Issues (MVP Blockers) | 5 | 🔴 Not Started |
| High Priority Features | 5 | 🟡 Not Started |
| Nice-to-Have Features | 5 | ⚪ Backlog |

**Estimated time to MVP:** 2 weeks of focused development

---

## 🎯 Definition of Done (MVP)

- [ ] All 5 critical features implemented
- [ ] App runs without crashes on iOS simulator
- [ ] Dark/Light mode works consistently
- [ ] Location permissions handled gracefully
- [ ] Network errors show user-friendly messages
- [ ] All placeholder screens replaced with functional UI
- [ ] Basic unit tests for services
- [ ] Widget tests for critical screens
- [ ] README updated with setup instructions

---

## 📝 Notes

- Backend is running on `localhost:8080` - ensure it's updated for production
- Firebase push notifications need GoogleService-Info.plist before enabling
- Consider TestFlight beta for user testing after MVP
- Track user feedback for Priority 3 feature prioritization
