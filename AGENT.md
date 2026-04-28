# AGENT.md — Geoloc Flutter App Context

> **Geoloc** is a hyper-local social media iOS-first app built with Flutter, Riverpod, GoRouter, and Dio. Users share posts tied to their geographic location and consume content from people nearby (5 km default radius).
>
> This document is the **project context** for any agent working in this repo. It describes what exists today, how the pieces fit together, and the conventions to follow when adding code.
>
> **For the engineering audit, prioritized backlog, and execution log, see [`improvement_list.md`](./improvement_list.md).** This file is intentionally non-evaluative — facts, not opinions.

---

## 1. Project Snapshot

| Item | Value |
|------|-------|
| Bundle ID | `com.irphotoarts.geoloc_app` |
| Package name (Dart) | `geoloc_app` |
| Min iOS | 13.0 |
| Dart SDK | `^3.10.4` |
| Flutter | 3.38+ |
| State management | `flutter_riverpod` 2.4.x — `StateNotifier` + `StateNotifierProvider[.family]` |
| Routing | `go_router` 13.x with `refreshListenable` against auth state |
| HTTP | `dio` 5.x with a JWT-refreshing interceptor |
| Secure storage | `flutter_secure_storage` 9.x with hardened iOS/Android options |
| Local cache | `hive_flutter` (recent searches only) |
| Location | `geolocator` 10.x + `geocoding` 2.x |
| Backend | Go + Cassandra at `localhost:8080` (separate repo) |

**Source size:** ~7,700 LOC across ~60 Dart files in `lib/`. **30 tests** in `test/`. CI in `.github/workflows/ci.yml`. `flutter analyze` reports **0 issues**.

---

## 2. Folder Structure

```
lib/
├── main.dart                       # Entry point, Hive init, system chrome
├── app.dart                        # Root MaterialApp.router + ThemeData
├── config/
│   ├── app_config.dart             # API base URL (--dart-define), durations, keys
│   ├── routes.dart                 # GoRouter + RoutePaths constants
│   └── theme.dart                  # Material 3 light + dark ThemeData
├── core/
│   ├── cache/image_cache_manager.dart  # Avatar (7d) + post-image (3d) CacheManagers
│   ├── errors/failures.dart        # Failure hierarchy
│   ├── network/
│   │   ├── api_client.dart         # Dio wrapper + Provider
│   │   ├── auth_interceptor.dart   # JWT attach/refresh/logout
│   │   └── api_endpoints.dart      # Centralized endpoint paths
│   ├── theme/
│   │   ├── app_colors.dart         # Color tokens
│   │   ├── app_spacing.dart        # AppSpacing / AppRadii / AppIconSize / AppTapTarget
│   │   └── theme_extensions.dart   # context.textTheme, context.gold, ...
│   └── utils/location_utils.dart   # Geohash + Haversine + formatDistance
├── data/models/                    # Immutable data classes (User, Post, Comment, ...)
├── presentation/
│   ├── providers/                  # Riverpod StateNotifier providers (one per feature)
│   ├── screens/                    # Screen widgets, grouped by feature
│   └── widgets/                    # Shared, reusable widgets (see §6)
│       └── states/                 # EmptyState, ErrorState, LocationPermissionPrompt
└── services/                       # API-calling business logic
    ├── secure_storage.dart         # Hardened FlutterSecureStorage singleton
    ├── auth_service.dart
    ├── location_service.dart
    ├── upload_service.dart
    ├── search_service.dart
    ├── notification_service.dart
    ├── push_notification_service.dart
    └── like_service.dart

test/
├── core/{utils,errors}/            # LocationUtils, Failure tests
├── data/models/                    # AuthTokens tests
├── presentation/widgets/           # IconSquareButton widget tests
└── widget_test.dart                # App smoke test

.github/workflows/ci.yml            # format → analyze → test → build (Android/iOS)
```

---

## 3. How the App is Wired

### 3.1 Entry point

`main.dart` performs Flutter binding init, Hive init, locks orientation to portrait, sets the system UI overlay style, then runs `runApp(ProviderScope(child: GeolocApp()))`. `GeolocApp` (`app.dart`) is a `ConsumerWidget` returning a `MaterialApp.router` with the `routerProvider` and `ThemeData` from `theme.dart`.

### 3.2 Routing (GoRouter)

- Single `routerProvider` in `lib/config/routes.dart`. Routes are defined with `GoRoute` and a centralized `RoutePaths` constants class.
- **Auth gating**: the router subscribes once to `authStateProvider` via `ref.listen`, feeds the resulting `ValueNotifier<bool>` into GoRouter's `refreshListenable`, and re-runs only the `redirect` logic when `isAuthenticated` flips. The router itself is never rebuilt.
- **Splash → Login or Feed** depending on auth state. Auth routes (`/login`, `/register`) redirect logged-in users to `/feed`; protected routes redirect anonymous users to `/login`.
- **Register** uses a custom slide-up `CustomTransitionPage` over the login background.
- Other transitions are platform default (iOS slide-from-right).
- **Path collision note:** `/profile/edit` is registered before `/profile/:id` so `:id` doesn't capture `"edit"`. Don't reorder.

### 3.3 State management (Riverpod)

- All state lives in `lib/presentation/providers/`. One file per feature: `auth_provider`, `feed_provider`, `profile_provider`, `post_detail_provider`, `create_post_provider`, `edit_profile_provider`, `search_provider`, `notifications_provider`, `location_provider`.
- Pattern is `StateNotifierProvider<XxxNotifier, XxxState>` (or `.family` for per-id state, e.g. `profileProvider(userId)`, `postDetailProvider(postId)`).
- State classes are immutable Dart with hand-rolled `copyWith`. Optimistic updates with revert-on-failure are used for likes (`feed_provider.dart`, `post_detail_provider.dart`).
- `autoDispose` is applied to ephemeral state (`createPostProvider`).
- **Note:** some providers call `ApiClient` directly (`feed_provider`, `profile_provider`, `post_detail_provider`, `create_post_provider`); others go through a service (`auth`, `notifications`, `search`). Both patterns coexist.

### 3.4 Networking (Dio + AuthInterceptor)

- `apiClientProvider` constructs a `Dio` instance with `BaseOptions(baseUrl: AppConfig.apiBaseUrl, ...)` and registers `AuthInterceptor` + `_LoggingInterceptor`.
- `AuthInterceptor` (`lib/core/network/auth_interceptor.dart`):
  - Attaches `Authorization: Bearer <accessToken>` on every request except `/auth/login`, `/auth/register`, `/auth/refresh`, `/auth/google/token`, `/auth/apple/token`.
  - On expired-access-token *or* a 401 response, it calls `_refreshToken` (which uses a separate `Dio` to avoid an interceptor loop), retries the original request, and replays any pending requests queued during the refresh.
  - On refresh failure, it calls `ref.read(authStateProvider.notifier).logout()`, which clears tokens via `AuthService.logout()` and flips auth state to unauthenticated, triggering the GoRouter redirect back to `/login`.
- `_LoggingInterceptor` only emits in debug builds (`if (kDebugMode) debugPrint(...)`). Bearer tokens are **never** logged.
- The base URL is configurable at build time:
  ```bash
  flutter run --dart-define=API_BASE_URL=https://api-staging.geoloc.app
  ```
  Default is `http://localhost:8080`. `AppConfig.isSecureBaseUrl` returns true iff the configured URL uses HTTPS.

### 3.5 Secure storage

- Always use the singleton `secureStorage` from `lib/services/secure_storage.dart`. Never construct `FlutterSecureStorage()` directly.
- iOS: `KeychainAccessibility.first_unlock_this_device` (secrets unavailable before first unlock; bound to this device — not iCloud-synced).
- Android: `EncryptedSharedPreferences`.
- Stored keys (defined in `AppConfig`): `accessTokenKey`, `refreshTokenKey`, `accessTokenExpiryKey`, `refreshTokenExpiryKey`, `currentUserKey`.
- Token lifetimes: access 15 min, refresh 7 days.

### 3.6 Theming

- `theme.dart` defines Material 3 light + dark `ThemeData` with custom `colorScheme`, `textTheme` (PT Serif headlines, Plus Jakarta Sans body, Fira Code for monospaced metadata), `appBarTheme`, `cardTheme`, button themes, `inputDecorationTheme`, and more.
- Color tokens live in `lib/core/theme/app_colors.dart` (`AppColors.gold(context)`, `AppColors.textMuted(context)`, semantic colors, etc.).
- Spacing/radius/icon/tap-target tokens live in `lib/core/theme/app_spacing.dart` (see §5).
- Ergonomic accessors via `lib/core/theme/theme_extensions.dart`: `context.textTheme`, `context.colors`, `context.gold`, `context.mutedText`, `context.isDark`.
- `themeMode: ThemeMode.system` — light/dark follows OS.
- Aesthetic: "old-money luxury" — warm cream, gold accents, 2-px sharp corners (`AppRadii.sharp`), serif display + sans body.

### 3.7 Image caching

- `lib/core/cache/image_cache_manager.dart` defines two custom `CacheManager`s used with `cached_network_image`:
  - `AvatarCacheManager` — stale period 7 days.
  - `PostImageCacheManager` — stale period 3 days.
- All `CachedNetworkImage` and `Image.file` instances pass `memCacheWidth` / `memCacheHeight` (or `cacheWidth` / `cacheHeight`) sized to the rendered logical-pixel dimensions × `MediaQuery.devicePixelRatioOf(context)` so the decoder doesn't expand 4K source files into RAM.

### 3.8 Logging

- All runtime logging goes through `if (kDebugMode) debugPrint(...)`. `print()` is a CI error (lint: `avoid_print: error` in `analysis_options.yaml`).
- Bearer tokens, secrets, PII must never be logged.

---

## 4. Backend Contract

Endpoints touched by the Flutter app (consolidated from `lib/core/network/api_endpoints.dart` and providers):

```
POST   /auth/register
POST   /auth/login                        (body: identifier + password)
POST   /auth/refresh
POST   /auth/google/token
POST   /auth/apple/token

GET    /api/v1/feed                       (lat, lng, radius_km, limit, cursor)
GET    /api/v1/users/me
PUT    /api/v1/users/me
GET    /api/v1/users/:id
GET    /api/v1/users/:id/posts
POST   /api/v1/users/:id/follow
DELETE /api/v1/users/:id/follow
GET    /api/v1/users/:id/followers
GET    /api/v1/users/:id/following

POST   /api/v1/posts
GET    /api/v1/posts/:id
POST   /api/v1/posts/:id/toggle-like      (preferred, idempotent)
POST   /api/v1/posts/:id/comments
GET    /api/v1/posts/:id/comments
POST   /api/v1/comments/:id/toggle-like   (preferred, idempotent)
POST   /comments/:id/reply
DELETE /comments/:id

POST   /locations/follow
DELETE /locations/:geohash/follow
GET    /locations/following

GET    /api/v1/geocode/address            (lat, lng)

GET    /notifications
PUT    /notifications/:id/read
PUT    /notifications/read-all

GET    /search/users
GET    /search/posts

POST   /api/v1/upload/avatar              (multipart, ≤5 MB; ?type=cover for cover)
POST   /api/v1/upload/post                (multipart, ≤50 MB)

POST   /devices                           (push token)
DELETE /devices
```

**Path-prefix note:** most endpoints live under `/api/v1`, but `/auth`, `/comments`, `/locations`, `/notifications`, `/search`, `/devices` are at root.

---

## 5. Design Tokens

Use these. Don't hardcode magic numbers, hex colors, or per-call `GoogleFonts` styles.

| Token | File | Purpose |
|-------|------|---------|
| `AppSpacing.{xxs,xs,sm,md,lg,xl,xxl,xxxl,huge}` | `lib/core/theme/app_spacing.dart` | 4-pt scale: 2, 4, 8, 12, 16, 20, 24, 32, 40 |
| `AppSpacing.{pagePadding,cardPadding}` | `lib/core/theme/app_spacing.dart` | Standard insets |
| `AppRadii.{sharp,soft,pill}` | `lib/core/theme/app_spacing.dart` | 2 / 8 / 999 |
| `AppRadii.{sharpAll,softAll,sheetTop}` | `lib/core/theme/app_spacing.dart` | `BorderRadius` values |
| `AppIconSize.{xs,sm,md,lg}` | `lib/core/theme/app_spacing.dart` | 14 / 16 / 20 / 24 |
| `AppTapTarget.{iosMinimum,materialMinimum}` | `lib/core/theme/app_spacing.dart` | 44 / 48 |
| `AppColors.*` | `lib/core/theme/app_colors.dart` | Brand palette + semantic colors. Use brightness-aware helpers: `AppColors.gold(context)`, `AppColors.textMuted(context)` |
| `context.{theme,textTheme,colors,gold,mutedText,isDark,brightness}` | `lib/core/theme/theme_extensions.dart` | Theme/brand accessors |

---

## 6. Shared UI Primitives

Use these. Don't reinvent.

| Widget | File | Use for |
|--------|------|---------|
| `GeolocAppBar` | `lib/presentation/widgets/geoloc_app_bar.dart` | **Every** screen's top bar. Handles safe-area inset and bottom hairline. Pass `title:` (string) or `titleWidget:` (e.g. `Wordmark()`) plus optional `leading` / `trailing` (typically `IconSquareButton`s) |
| `IconSquareButton` | `lib/presentation/widgets/icon_square_button.dart` | All 44×44 outlined-square icon buttons. **Always** pass `semanticLabel`. Optional `tooltip` |
| `Wordmark` | `lib/presentation/widgets/wordmark.dart` | "Geoloc" italic PT Serif title (single source of truth for font/size) |
| `HairlineDivider` | `lib/presentation/widgets/hairline_divider.dart` | Faded gradient hairline inside bottom sheets |
| `EmptyState` | `lib/presentation/widgets/states/empty_state.dart` | Gold icon + serif title + muted body + optional outlined CTA |
| `ErrorState` | `lib/presentation/widgets/states/error_state.dart` | Red icon + retry CTA |
| `LocationPermissionPrompt` | `lib/presentation/widgets/states/location_permission_prompt.dart` | "Enable Location" + Open Settings flow |
| `PostCard` | `lib/presentation/widgets/post_card.dart` | Feed/profile post tile |
| `UserAvatar` | `lib/presentation/widgets/user_avatar.dart` | User avatar with deterministic fallback colors |
| `LoadingShimmer` (and `FeedShimmer`) | `lib/presentation/widgets/loading_shimmer.dart` | Skeleton loading states |
| `CustomRefreshIndicator` | `lib/presentation/widgets/custom_refresh_indicator.dart` | Pull-to-refresh wrapper |
| `secureStorage` | `lib/services/secure_storage.dart` | Hardened singleton — **always** use this, never `FlutterSecureStorage()` directly |

### Reference example

```dart
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

Scaffold(
  body: Column(
    children: [
      GeolocAppBar(
        title: 'Profile',                // or titleWidget: Wordmark()
        leading: IconSquareButton(
          icon: Icons.arrow_back,
          semanticLabel: 'Back',
          onTap: () => context.pop(),
        ),
        trailing: IconSquareButton(
          icon: Icons.settings_outlined,
          semanticLabel: 'Settings',
          onTap: () { /* … */ },
        ),
      ),
      Expanded(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? ErrorState(message: state.error!, onRetry: load)
                : state.items.isEmpty
                    ? const EmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Nothing yet',
                        message: 'Things will show up here.',
                      )
                    : ListView.builder(...),
      ),
    ],
  ),
);
```

---

## 7. Current Implementation State

- ✅ Theming + colors + design tokens, Material 3
- ✅ API client + JWT interceptor + auth refresh + secure storage
- ✅ Auth: email/password, Google Sign-In, Apple Sign-In
- ✅ Feed (Nearby tab) with cursor pagination, optimistic likes, pull-to-refresh
- ✅ Create Post (text + multi-image + location with reverse-geocoded address)
- ✅ Post Detail with comments + nested-reply data model + comment likes
- ✅ Profile (own + others) with follow/unfollow + paginated posts
- ✅ Edit Profile (full name / username / bio / avatar / cover with image cropping)
- ✅ Search (users + posts, debounced, recent searches in Hive)
- ✅ Notifications list (paginated, mark-as-read)
- ✅ GitHub Actions CI (format / analyze / test / Android+iOS build smoke)
- ⏳ Feed "Following" tab — placeholder
- ⏳ Comment replies UI (model supports up to depth 3, screen does not yet render trees)
- ⏳ Firebase / FCM push notifications (stubbed; awaiting `GoogleService-Info.plist`)
- ⏳ Location-following geohash subscriptions (endpoints declared, no UI)
- ⏳ Video playback (no current dep, no usage)
- ⏳ Android-specific config (iOS-first; Android may need permissions / signing review)

For the prioritized backlog, see [`improvement_list.md`](./improvement_list.md).

---

## 8. Run / Build / Test

```bash
flutter pub get

# Local dev (default points at http://localhost:8080)
flutter run -d ios

# Staging / production — override the base URL at build time
flutter run --dart-define=API_BASE_URL=https://api-staging.geoloc.app
flutter build ios --release \
  --dart-define=API_BASE_URL=https://api.geoloc.app

flutter test                # 30 tests, expects 0 failures
flutter analyze             # 0 issues; CI runs --no-fatal-infos
dart fix --apply            # mechanical const/parens cleanup
dart format .               # CI enforces zero-diff formatting
```

---

## 9. Key Constants & Invariants

| Setting | Location | Value |
|---------|----------|-------|
| API base URL | `lib/config/app_config.dart` | `String.fromEnvironment('API_BASE_URL', default 'http://localhost:8080')` |
| Default feed radius | `lib/config/app_config.dart` | 5 km |
| Geohash precision | `lib/config/app_config.dart` | 5 (≈5 km) |
| Access-token lifetime | `lib/config/app_config.dart` | 15 min |
| Refresh-token lifetime | `lib/config/app_config.dart` | 7 days |
| Default page size | `lib/config/app_config.dart` | 20 |
| Search debounce | `lib/config/app_config.dart` | 400 ms |
| Max comment depth | `lib/config/app_config.dart` | 3 |
| Avatar cache stale | `lib/core/cache/image_cache_manager.dart` | 7 days |
| Post-image cache stale | `lib/core/cache/image_cache_manager.dart` | 3 days |

---

## 10. Editing Rules of Thumb

- **Add screen** → register a `RoutePaths` constant + `GoRoute` in `lib/config/routes.dart`. The router uses `refreshListenable` against `authStateProvider`; no rebuild on benign state changes.
- **Add provider** → place in `lib/presentation/providers/`, follow the `StateNotifierProvider<XxxNotifier, XxxState>` pattern.
- **New API endpoint** → add to `lib/core/network/api_endpoints.dart`. Prefer adding a method to an existing service over calling `ApiClient` from a notifier.
- **New colors / spacings** → extend `AppColors` / `AppSpacing`. Don't reach for `Color(0x…)` or magic-number `EdgeInsets`.
- **Top bars** → use `GeolocAppBar`. Don't roll a custom `Container` + `Row`.
- **Icon buttons** → use `IconSquareButton` with `semanticLabel`. Never under 44 pt tap area.
- **Empty / error / location-permission UI** → use `EmptyState`, `ErrorState`, `LocationPermissionPrompt` from `widgets/states/`.
- **Logging** → `if (kDebugMode) debugPrint(...)` only. `print()` is a CI error.
- **Images** → set `memCacheWidth` / `memCacheHeight` (or `cacheWidth` / `cacheHeight`) to logical pixels × `MediaQuery.devicePixelRatioOf(context)`.
- **Secure storage** → import the singleton `secureStorage` from `lib/services/secure_storage.dart`. Never `FlutterSecureStorage()` directly.
- **Theming** → use `context.textTheme.xxx` and `context.colors.xxx` from `theme_extensions.dart` instead of `Theme.of(context).colorScheme` and per-call `GoogleFonts.xxx()`.
- **Tests** → mirror `lib/` under `test/`. Import as `package:geoloc_app/...` (not `package:geoloc/...`).
- **Deprecated APIs** → use `withValues(alpha: x)`, not `withOpacity(x)`. Use `MediaQuery.sizeOf(context)` / `paddingOf(context)` / `devicePixelRatioOf(context)` over the deprecated `MediaQuery.of(context).xxx`.
