# Geoloc Flutter App — Improvement List & Engineering Audit

> Companion document to `AGENT.md`. This file holds **everything evaluative**:
> the engineering review, severity ratings, recommendations, the execution
> log of what was already shipped, and the remaining backlog.
>
> `AGENT.md` is reserved for **factual project context** only.

**Conventions:** 🔴 Critical / 🟡 Warning / 🟢 Good. Priorities: **P0** (security/blocking, do this week), **P1** (foundations, do this sprint), **P2** (quality + UX, next sprint), **P3** (later, scaling).

---

## 1. Execution Log — 2026-04-28

This audit was followed by an automated execution pass. **All 🔴 P0 items and 9 of 9 mechanically-tractable 🔴 P1 items are landed.** What remains is structural work (god-widget decomposition, `freezed`/`Notifier` migration) that requires human design review.

### What was changed

| # | Action | Files |
|---|--------|-------|
| ✅ P0-1 | Removed bearer-token `print` in `auth_interceptor.dart`; migrated all `print` → `debugPrint` gated on `kDebugMode` | `lib/core/network/{auth_interceptor,api_client}.dart`, `lib/services/push_notification_service.dart`, `lib/presentation/providers/{profile,post_detail}_provider.dart` |
| ✅ P0-2 | `apiBaseUrl` is now `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')`. Build with `--dart-define=API_BASE_URL=https://api.geoloc.app` for non-dev. New `AppConfig.isSecureBaseUrl` getter | `lib/config/app_config.dart` |
| ✅ P0-3 | `AuthInterceptor._handleLogout` now calls `ref.read(authStateProvider.notifier).logout()` so 401-on-refresh flips auth state, and the GoRouter redirect kicks the user back to `/login` | `lib/core/network/auth_interceptor.dart` |
| ✅ P0-4 | All 26 `withOpacity(x)` calls → `withValues(alpha: x)` (Flutter 3.27+ API, fixes deprecation warnings) | 8 screen/widget files under `lib/presentation/` |
| ✅ P0-5 | New shared `secureStorage` instance with iOS `KeychainAccessibility.first_unlock_this_device` and Android `EncryptedSharedPreferences`. `AuthService` and `AuthInterceptor` now use it | `lib/services/secure_storage.dart`, `auth_service.dart`, `auth_interceptor.dart` |
| ✅ P1-1 | Tightened `analysis_options.yaml`: `strict-casts: true`, `avoid_print: error`, `prefer_const_constructors`, `unnecessary_*`, `prefer_single_quotes`, etc. | `analysis_options.yaml` |
| ✅ P1-2 | Deleted duplicate `LocationState` in `lib/services/location_service.dart` (was shadowing `presentation/providers/location_provider.dart`) | `lib/services/location_service.dart` |
| ✅ P1-3 | Removed dead deps: `video_player`, `pull_to_refresh`, `infinite_scroll_pagination`, `shimmer`, `uuid`. `flutter pub get` cleanly resolves | `pubspec.yaml` |
| ✅ P1-4 | Added `memCacheWidth/Height` (decoded at logical-pixel size × DPR) to `UserAvatar`, `PostCard` single + grid images, feed top-bar avatar, create-post avatar, and gallery preview `Image.file`s | `lib/presentation/widgets/{user_avatar,post_card}.dart`, `feed_screen.dart`, `create_post_screen.dart` |
| ✅ P1-5 | New design tokens: `AppSpacing` (4-pt scale, page/card paddings), `AppRadii` (sharp/soft/pill, sheet-top), `AppIconSize`, `AppTapTarget` | `lib/core/theme/app_spacing.dart` |
| ✅ P1-6 | Extracted 7 shared widgets from inline implementations: `GeolocAppBar`, `IconSquareButton`, `Wordmark`, `HairlineDivider`, `EmptyState`, `ErrorState`, `LocationPermissionPrompt` | `lib/presentation/widgets/{geoloc_app_bar,icon_square_button,wordmark,hairline_divider}.dart`, `lib/presentation/widgets/states/*.dart` |
| ✅ P1-7 | Wired the new widgets into `feed_screen.dart` (**612 → 391 LOC, −36%**) and `notifications_screen.dart` (**355 → 239 LOC, −33%**). Visual parity preserved | `lib/presentation/screens/feed/feed_screen.dart`, `lib/presentation/screens/notifications/notifications_screen.dart` |
| ✅ P1-8 | New `BuildContext` extension exposing `context.theme`, `context.textTheme`, `context.colors`, `context.gold`, `context.mutedText` | `lib/core/theme/theme_extensions.dart` |
| ✅ P1-9 | Eliminated hex-literal duplication in `UserAvatar._fallbackColors`; now references the central `AppColors` tokens | `lib/presentation/widgets/user_avatar.dart` |
| ✅ P1-10 | `routerProvider` now feeds a `ValueNotifier<bool>` into GoRouter's `refreshListenable` and only emits when `isAuthenticated` flips | `lib/config/routes.dart` |
| ✅ P1-11 | New unit/widget tests: `LocationUtils`, `AuthTokens`, `Failure` hierarchy, `IconSquareButton`. **30 tests pass** (up from 1 smoke test) | `test/core/`, `test/data/`, `test/presentation/widgets/` |
| ✅ P1-12 | New `.github/workflows/ci.yml` running `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test --coverage`, debug Android APK build, and iOS no-codesign build | `.github/workflows/ci.yml` |

### Verification

```
$ flutter analyze
No issues found! (ran in 3.3s)

$ flutter test
All tests passed! (30 tests)
```

---

## 2. Backlog (still pending)

### 🟡 P2 — Next sprint (quality + UX)

| # | Item | Notes |
|---|------|-------|
| P2-15 | Migrate state classes to `freezed` + `riverpod_generator` | Eliminates `copyWith` nullable-clear bug class (e.g. `FeedState.cursor` cannot be reset to null today). Adds `dev_dependencies`: `freezed`, `freezed_annotation`, `riverpod_generator`, `build_runner`. |
| P2-16 | Convert `_buildXxx` methods to `class _Xxx extends StatelessWidget` | Re-enables `const` and prunes whole-screen rebuilds. Apply across the 6 god-widget files below. |
| P2-17 | Decompose god-widget files to ≤300 LOC each | `register_screen.dart` 587, `edit_profile_screen.dart` 580, `create_post_screen.dart` 577, `profile_screen.dart` 540, `post_detail_screen.dart` 580, `login_screen.dart` 502. (`feed_screen.dart` already at 391, `notifications_screen.dart` at 239.) The shared widgets shipped in P1 unblock this. |
| P2-18 | Comprehensive accessibility pass | Wire `Semantics` labels on **every** icon button (use `IconSquareButton.semanticLabel`). Audit all `GestureDetector(onTap:)` for sub-44-pt hit areas. VoiceOver + TalkBack smoke pass. Consider `accessibility_tools` dev package. |
| P2-19 | Animation polish | `AnimatedSwitcher` + `ScaleTransition` heart-burst on like, `Hero` transitions on avatars + post images, replace centered spinners with `LoadingShimmer` family on profile / post-detail / notifications, custom `PageTransitionsTheme`. |
| P2-20 | Adopt `Theme.of(context).textTheme` everywhere | Helper `context.textTheme` extension already shipped (P1-8). ~170 per-call `GoogleFonts.xxx()` invocations remain across screens — migrate file-by-file as those screens are touched. Once complete, the `appBarTheme` block in `theme.dart` stops being dead. |
| P2-21 | Wired `AppBar` adoption | Currently `AppBar` is used 0 times despite a fully-themed `appBarTheme`. `GeolocAppBar` (shipped) is the project-specific replacement; either embrace `GeolocAppBar` everywhere and prune `appBarTheme`, or migrate suitable screens to `AppBar`. |
| P2-22 | `AuthInterceptor` + `FeedNotifier` mocked-Dio tests | Needs `mocktail` (or `mockito`) in `dev_dependencies`. Cover token refresh under concurrent requests, optimistic-like-and-revert, and `_handleDioError` for 400/401/429/5xx. |
| P2-23 | `editProfile` route collision | Today `/profile/edit` must be registered before `/profile/:id` because `:id` would otherwise capture `"edit"`. Move under `/profile/me/edit` or use a `ShellRoute`. |
| P2-24 | Standardize provider error semantics | Half the providers reset `error` on every `copyWith` (`FeedState`); half use a `clearError: bool` flag (`SearchState`, `NotificationsState`, `EditProfileState`). Pick one (recommendation: `clearError: bool` until `freezed` lands, then sealed `AsyncValue` style). |
| P2-25 | Centralize JSON-fallback chain | `data['user'] ?? data['data'] ?? data` is duplicated in `auth_service.dart:213`, `profile_provider.dart:75–78,176–179`. Extract a helper, ideally in a repository layer. |
| P2-26 | Path-prefix inconsistency on backend | Most endpoints live under `/api/v1`, but `/auth`, `/comments`, `/locations`, `/notifications`, `/search`, `/devices` are at root. Raise with backend team. |

### 🟢 P3 — Later (nice-to-have, scaling)

| # | Item | Notes |
|---|------|-------|
| P3-27 | `StateNotifier` → `Notifier`/`AsyncNotifier` | Migrate file-by-file. Riverpod 3 will deprecate the old API. |
| P3-28 | Repository layer between providers and `ApiClient` | Currently `feed_provider`, `profile_provider`, `post_detail_provider`, `create_post_provider` call `ApiClient` directly; the rest go via services. Pick one pattern. |
| P3-29 | Tablet/iPad layout | `MaxContentWidth` wrapper (≈720 pt) around feed/profile content. Migrate `MediaQuery.of(context).size` → `MediaQuery.sizeOf(context)`. |
| P3-30 | Push notifications | Drop in `GoogleService-Info.plist`, uncomment `firebase_core` + `firebase_messaging` in `pubspec.yaml`, wire `pushNotificationServiceProvider`. |
| P3-31 | Bundle Plus Jakarta Sans + PT Serif as local fonts | Eliminates first-launch network dependency for typography and FOUT. Drop `assets/fonts/*.ttf`, declare in `pubspec.yaml`, drop `google_fonts`. |
| P3-32 | Replace Hive with Isar/Drift | Hive is unmaintained. Only justified if local persistence grows beyond `recent_searches`. |
| P3-33 | Fastlane | TestFlight + Play Store automation (`fastlane/Fastfile` with `beta` and `release` lanes). |
| P3-34 | `StatefulShellRoute` | Once a bottom navbar lands, switch to GoRouter's `StatefulShellRoute` to preserve scroll positions across tabs. |
| P3-35 | Deep links | Configure iOS `Info.plist` and Android intent filters for universal links. |
| P3-36 | `go_router_builder` for type-safe params | Or hand-rolled helpers (`RoutePaths.profileFor(id)`) wrapping `context.push(...)`. |
| P3-37 | Pre-commit hook | `lefthook` running `dart format` + `flutter analyze`. |

---

## 3. Audit Reference (per-area findings, ordered by severity)

> Keep this as the historical record of *why* the items above exist. Severity reflects state at audit time (2026-04-28); items now done are crossed out.

### 3.1 Architecture & Structure — 🟡 Warning

- 🟡 **Layer-first organization** (`presentation`, `data`, `core`, `services`, `config`) is reasonable for the current ~60-file scale, but conventions are inconsistent: some providers call `ApiClient` directly (`feed_provider.dart`, `profile_provider.dart`, `post_detail_provider.dart`, `create_post_provider.dart`), while others go through a service. Two parallel patterns exist for the same job. (See P2-25, P3-28.)
- 🟡 **No repository layer.** Providers double as state holders and data fetchers. (P3-28.)
- ~~🔴 **Duplicate `LocationState` class** in `lib/services/location_service.dart` and `lib/presentation/providers/location_provider.dart`.~~ ✅ Fixed in P1-2.
- ~~🟡 **`presentation/widgets/` only contains 4 components.**~~ ✅ Now contains 11 (post-P1).
- 🟡 **No clear use-case / domain layer.** Provider notifiers contain validation logic mixed with networking and UI state mutation (e.g. `EditProfileNotifier.validateUsername` at `edit_profile_provider.dart:327`).
- 🟢 `core/network/`, `core/errors/`, `core/utils/` separation is clean.
- 🟢 `data/models/` are immutable plain Dart with `fromJson` / `toJson` / `copyWith` and value equality — solid foundation.

### 3.2 State Management (Riverpod) — 🟡 Warning

- 🟢 Consistent use of `StateNotifier` + immutable state classes with `copyWith`. Optimistic updates with revert-on-failure are implemented well in `feed_provider.dart:199–234` (post like) and `post_detail_provider.dart:140–191`.
- 🟢 `StateNotifierProvider.family` used correctly for per-id state.
- 🟢 `autoDispose` correctly applied to ephemeral state (`createPostProvider`).
- 🟡 **Boilerplate-heavy.** Every state class hand-rolls `copyWith`, equality, and constructor (~600+ LOC of repeated boilerplate across 8 providers). (P2-15.)
- 🟡 **`copyWith` nullable-set semantics are broken.** `cursor: cursor ?? this.cursor` — there is no way to clear `cursor` to null during a refresh. Same bug class in `ProfileState.postsCursor`, `CreatePostState.locationName`, etc. (P2-15.)
- 🟡 **Inconsistent error semantics.** (P2-24.)
- 🟡 **Older Riverpod API.** (P3-27.)
- ~~🟡 **`AuthInterceptor` constructor takes `Ref` but ignores it.**~~ ✅ Fixed in P0-3.
- ~~🟡 **No central place to react to logout.**~~ ✅ Fixed in P0-3.

### 3.3 Code Quality — 🔴 (was Critical, now resolved)

- ~~🔴 **Bearer token logged to console** at `auth_interceptor.dart:65`.~~ ✅ P0-1.
- ~~🟡 **23 `print()` calls.**~~ ✅ P0-1 (now `debugPrint` gated on `kDebugMode`; `avoid_print: error` in CI).
- ~~🔴 **`withOpacity` deprecated** (used 26 times).~~ ✅ P0-4.
- ~~🟡 **Default `flutter_lints` only.**~~ ✅ P1-1.
- 🟡 **`Theme.of(context).textTheme` is used 0 times** despite the elaborate textTheme defined in `theme.dart:29–86`. Every screen instead manually invokes `GoogleFonts.ptSerif(...)` / `GoogleFonts.plusJakartaSans(...)` (≈170 call sites). (P2-20.)
- 🟡 **`AppBar` widget used 0 times** despite a fully-themed `appBarTheme`. Each screen rebuilds an identical custom top bar inline. (P2-21.)
- 🟡 **3 `TODO` comments without owner/issue links** (`main.dart:29`, `auth_interceptor.dart:209`, `push_notification_service.dart:21`).
- 🟡 **JSON parsing fallback chain** duplicated in `auth_service.dart:213` and `profile_provider.dart:75–78,176–179`. (P2-25.)
- 🟢 Null safety, const correctness, naming conventions are all good.

### 3.4 Dependencies & Pubspec — formerly 🔴, now 🟢

- ~~🔴 Dart SDK pinned to `^3.10.4`~~ — confirmed working on installed Flutter 3.38 / Dart 3.10. Left as-is.
- ~~🔴 Dead deps (`pull_to_refresh`, `infinite_scroll_pagination`, `video_player`, `uuid`, `shimmer`).~~ ✅ P1-3.
- 🟡 Several deps have major-version drift available: `flutter_riverpod` 2.5+, `go_router` 14, `geolocator` 11, `image_cropper` 6, `google_sign_in` 7, `intl` 0.19/0.20. Run `flutter pub outdated` periodically.
- 🟡 No fonts declared in pubspec — typography downloaded at runtime via `google_fonts`. (P3-31.)
- 🟢 `pubspec.lock` committed (correct for an app).
- 🟢 `build_runner` is a dev-dep; it will be needed once `freezed`/`riverpod_generator` land (P2-15) — currently unused (no `*.g.dart` files).

### 3.5 Performance — formerly 🔴/🟡, now 🟡

- 🟢 `ListView.builder` used in feed and notifications with proper `itemCount` + tail loader.
- 🟢 Custom `CacheManager` instances for avatars (7-day) and post images (3-day) with bounded object counts.
- 🟢 Pagination uses cursor-based fetching with `state.hasMore` guards.
- ~~🔴 **No `cacheWidth` / `cacheHeight` on `CachedNetworkImage` or `Image.file`.**~~ ✅ P1-4.
- 🟡 **Profile screen uses `ListView` (not `.builder`)** with `...profileState.posts.map(...)` (`profile_screen.dart:108`). Rewrite to `CustomScrollView` + `SliverList.builder`. (P2-17.)
- 🟡 **God widgets force whole-screen rebuilds** because `_buildXxx` methods (vs `Widget` subclasses) break `const` pruning. (P2-16/17.)
- 🟡 **Many `Theme.of(context)` calls in the same `build`** — fine for correctness, noisy.
- 🟡 **`addPostFrameCallback` in `_buildLocationSection`** (`create_post_screen.dart:428`) inside a `build` method — runs every rebuild and can spam `fetchAddress`. Move to `initState` or `ref.listen`.
- 🟡 **`GoogleFonts.ptSerif()` etc. allocates a new `TextStyle` on every rebuild.** ~170 call sites. (P2-20.)

### 3.6 Testing — formerly 🔴 Critical, now 🟡

- ~~🔴 Single smoke test.~~ ✅ P1-11 (30 tests now).
- 🟡 No widget tests yet for `PostCard`, `UserAvatar`, the optimistic-like-and-revert flow, the auth redirect tree, error/empty/loading states. (P2-22.)
- 🟡 No integration / golden tests.
- 🟡 No coverage threshold enforcement (CI uploads `coverage/lcov.info` artifact but doesn't gate).

### 3.7 Navigation — formerly 🟡, partially resolved

- 🟢 `GoRouter` configured with `redirect` for auth gating.
- 🟢 `RoutePaths` constants centralized.
- 🟢 Custom slide-up transition for register modal.
- 🟢 Error builder defined.
- ~~🟡 Auth redirect runs on every navigation~~ ✅ P1-10 (now uses `refreshListenable`).
- 🟡 **Edit-profile path collision risk.** (P2-23.)
- 🟡 **No `ShellRoute` / `StatefulShellRoute`.** (P3-34.)
- 🟡 **No deep-link configuration.** (P3-35.)
- 🟡 No type-safe route params. (P3-36.)

### 3.8 CI/CD & Tooling — formerly 🔴 Critical, now 🟢

- ~~🔴 No `.github/workflows/`.~~ ✅ P1-12.
- 🔴 **No `fastlane/`.** (P3-33.)
- 🔴 **No `.fvmrc` / version pin** beyond CI workflow. The Flutter version env var in `.github/workflows/ci.yml` (`3.24.0`) should be aligned with whatever the team uses locally.
- 🟡 No pre-commit hook. (P3-37.)
- 🟢 `.gitignore` looks standard.

### 3.9 UI Architecture & Widget Design — formerly 🔴, partially resolved

- ~~🔴 God widgets~~ — partially resolved (`feed_screen` and `notifications_screen` decomposed in P1-7); 6 screens still pending. (P2-16/17.)
- ~~🟡 Top-bar / icon-button / empty-state / error-state / location-permission / hairline / wordmark patterns repeated inline.~~ ✅ P1-6 (extracted as shared widgets); use them everywhere going forward.
- 🟡 `_ActionButton` (`post_card.dart:347`), `_CommentItem`, `_SplashScreen`, `_LoadingShimmerState` — well-scoped private classes; consider promoting `_ActionButton` and `_CommentItem` to `presentation/widgets/`.

### 3.10 Design System & Theming — formerly 🔴, partially resolved

- 🟢 `AppColors` light + dark palettes, semantic colors, brightness-aware helpers.
- 🟢 Light + dark `ThemeData` with Material 3, comprehensive component themes.
- 🟢 `themeMode: ThemeMode.system`.
- 🔴 **`textTheme` is largely ignored** — every screen calls `GoogleFonts.xxx()` directly. (P2-20.)
- 🔴 **`AppBar` is never used** despite a defined `appBarTheme`. (P2-21.)
- ~~🔴 No spacing tokens.~~ ✅ P1-5 (`AppSpacing`).
- ~~🔴 No radius tokens.~~ ✅ P1-5 (`AppRadii`).
- ~~🟡 `UserAvatar._fallbackColors` hex duplication.~~ ✅ P1-9.
- 🟢 Color contrast for `bgLight` vs `textLight` is ≈14:1 (WCAG AAA).

### 3.11 Responsiveness & Adaptability — 🟡

- 🟢 Orientation locked to portrait — valid for an iOS-first social app.
- 🟢 `MediaQuery.padding.top/.bottom` used where `SafeArea` was insufficient.
- 🟢 `LayoutBuilder` used in `feed_screen.dart` for empty-state min-height.
- 🟡 **No tablet / large-screen layout.** (P3-29.)
- 🟡 **No `MediaQuery.sizeOf`** (Flutter 3.10+) — all `MediaQuery.of(context)` calls subscribe to all aspects. (P3-29.)
- 🟡 **Web/desktop unsupported** but platform folders exist from `flutter create`.

### 3.12 Animations & Micro-interactions — 🟡

- 🟢 Slide-up `CustomTransitionPage` for register screen.
- 🟢 `HapticFeedback.mediumImpact` / `heavyImpact` on post submit and profile save.
- 🟢 `AnimatedBuilder` shimmer with manual `Tween<double>(-1.0, 2.0)` — smooth gradient sweep.
- 🟡 **Like button has no visual animation.** (P2-19.)
- 🟡 **No Hero transitions** on avatars or post images. (P2-19.)
- 🟡 **No custom `PageTransitionsTheme`.** (P2-19.)
- 🟡 **No skeleton on profile / post-detail loading** — centered spinners only. (P2-19.)

### 3.13 Accessibility (a11y) — 🔴 Critical

- 🔴 **Zero `Semantics`, `MergeSemantics`, or `semanticLabel` usage** across the existing screen code (the new shared widgets shipped in P1 do include them). VoiceOver / TalkBack treat the app as a black box. (P2-18.)
- 🔴 **Sub-minimum touch targets** in legacy screens:
  - `_ActionButton` (`post_card.dart:347`) — ~24 px hit area.
  - Top-bar 34×34 outlined squares — 10 px below iOS minimum (the new `IconSquareButton` defaults to 44 pt).
  - `IconButton`s replaced with `GestureDetector(onTap:…)` bypass Material's 48 dp enforcement.
  - `tapTargetSize: MaterialTapTargetSize.shrinkWrap` + `minimumSize: Size.zero` on the Post button (`post_detail_screen.dart:350`).
- 🟡 **Decorative gradients and dividers** are not marked `excludeFromSemantics`.
- 🟡 **Form fields** in login/register/edit-profile may lack adequate labels for screen readers.
- 🟢 **Color contrast** of palette appears to meet WCAG AA. (Recommend `accessibility_tools` package or Xcode's Accessibility Inspector.)
- 🟢 `SystemUiOverlayStyle` correctly toggles status-bar icon brightness.

### 3.14 UI Consistency & Visual Quality — 🟡

- 🟢 The "old-money luxury" aesthetic (warm cream, gold accents, 2-px radii, serif display + sans body) is consistent in feel.
- 🟢 Typography scale is consistent in intent — PT Serif for headlines, Plus Jakarta Sans for body, Fira Code for monospaced metadata.
- ~~🟡 Inconsistent header padding.~~ ✅ P1-6/7 (`GeolocAppBar` is the single source of truth now).
- 🟡 **Inconsistent loading affordances.** Feed shows shimmer; profile/post-detail/notifications show centered spinners. (P2-19.)
- 🟡 **Mixed icon sizing.** 14, 16, 18, 20, 24 px — `AppIconSize` (P1-5) is the standard going forward; legacy call sites still need migration.
- ~~🟡 Repeated gradient hairlines.~~ ✅ P1-6 (`HairlineDivider`).
- ~~🟡 Wordmark drift.~~ ✅ P1-6 (`Wordmark`).

### 3.15 Security & Privacy — formerly 🔴 Critical, now 🟡

- ~~🔴 Bearer token logged.~~ ✅ P0-1.
- ~~🔴 `apiBaseUrl` hard-coded to HTTP localhost with no env switching.~~ ✅ P0-2.
- ~~🟡 No `IOSOptions` / `AndroidOptions` on `flutter_secure_storage`.~~ ✅ P0-5.
- 🟡 **Refresh-token roll-over policy.** `auth_interceptor._refreshToken` only writes a new refresh token if the response includes one. Verify with backend that policy matches.

---

## 4. How to use the new shared widgets in remaining screens

```dart
import '../../widgets/geoloc_app_bar.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/states/empty_state.dart';
import '../../widgets/states/error_state.dart';

Scaffold(
  body: Column(
    children: [
      GeolocAppBar(
        title: 'Profile',           // or titleWidget: Wordmark()
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
                    : ListView(...),
      ),
    ],
  ),
);
```
