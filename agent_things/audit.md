# Geoloc Flutter App — Pre-Launch Audit

**Original audit:** 2026-07-15  
**Last updated:** 2026-07-15 (post iOS hardening pass)  
**Scope:** ~105 `lib/` source files, ~21.6k LOC, 17 test files  
**Auditor lens:** UI consistency, animation smoothness, production readiness, resource utilization

---

## Audit Summary

**Verdict: iOS TESTFLIGHT-READY WITH CAVEATS — Android / full prod still blocked.**

An iOS-priority hardening pass addressed **most Blocker and High** items from the original audit. The app now has global error handling + Crashlytics wiring, HTTPS release API enforcement, deferred startup, bundled fonts, iOS deep links, push-tap routing, chat scroll fix, and a passing iOS release build (`flutter build ios --release --no-codesign`, 71 tests green).

**Remaining before App Store:** Apple codesign/provisioning, Crashlytics dSYM upload in Xcode, flip `aps-environment` to `production`, confirm reset-password email URLs, and manual QA on device.

**Still blocked for Android Play:** debug release signing. **Still open across platforms:** full design-system consolidation, AppSpacing codemod, integration tests for auth→feed→post flows, DM decrypt on isolates, broad `ref.select` on feed, accessibility semantics on icon-only controls.

The bones are solid; the iOS launch gate is much closer than before.

---

## Implementation Log (2026-07-15)

| Area | Change | Key files |
|------|--------|-----------|
| Crash reporting | `runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher.onError` → Crashlytics | `lib/core/bootstrap/crash_reporting.dart`, `lib/main.dart` |
| Firebase | `DefaultFirebaseOptions.currentPlatform`; deferred bootstrap | `lib/core/bootstrap/app_bootstrap.dart`, `lib/firebase_options.dart` |
| API config | Release default `https://api.geoloc.app`; `assertValidForRelease()` | `lib/config/app_config.dart` |
| Version | `1.0.0+1` | `pubspec.yaml` |
| iOS deep links | `CFBundleURLTypes` + `remote-notification` | `ios/Runner/Info.plist` |
| Push nav | `routeFromPushData` + `pendingPushRouteProvider` | `lib/config/push_navigation.dart`, `lib/services/push_notification_service.dart` |
| Startup | `runApp` first; Firebase/push listeners post-frame; no permission dialog at launch | `lib/main.dart`, `lib/app.dart` |
| Fonts | Bundled TTFs in `google_fonts/`; `allowRuntimeFetching = false` | `google_fonts/`, `pubspec.yaml` |
| Status bar | Theme-driven `AnnotatedRegion` in `GeolocApp` | `lib/app.dart` |
| Chat scroll | `ref.listen` on message count; sticky-bottom logic | `lib/presentation/screens/messages/chat_screen.dart` |
| Providers | `.autoDispose` on chat/profile/post-detail families | `dm_provider.dart`, `profile_provider.dart`, `post_detail_provider.dart` |
| Rebuilds | `ref.select` on inbox keys, unread badges, DM unread | `chat_screen.dart`, `notifications_provider.dart`, `dm_provider.dart` |
| Network | Parallel inbox preview hydrate; parallel media sign; local mark-read (no full inbox reload on chat open) | `dm_service.dart`, `media_service.dart`, `dm_provider.dart` |
| SSE | Cool-down after 20 consecutive failures | `notifications_provider.dart` |
| Perf | Ambient/create glow pause on background; `TopBarBackdrop` blur off by default; comments `SliverList.builder` | `ambient_glow_background.dart`, `app_shell.dart`, `top_bar_backdrop.dart`, `post_detail_screen.dart` |
| Images | `memCacheWidth/Height` on cover + login background; 80 MB image cache cap | `profile_screen.dart`, `edit_profile_screen.dart`, `login_screen.dart`, `main.dart` |
| UI | Auth `onInverseSurface` scrims; cream surface tokens `@Deprecated`; dead widgets deleted; Hero orphan removed | `login_screen.dart`, `register_screen.dart`, `app_colors.dart` |
| Logging | `AppLogger`; key `debugPrint` replaced | `lib/core/logging/app_logger.dart` |
| l10n | EN scaffold + delegates | `lib/l10n/`, `l10n.yaml`, `lib/app.dart` |
| CI/tests | Flutter 3.29, iOS release CI step, `flutter analyze` strict; widget + config tests | `.github/workflows/ci.yml`, `test/` |

**Verification:** `flutter analyze lib test` — 0 errors; `flutter test` — 71 passed; `flutter build ios --release --no-codesign --dart-define=API_BASE_URL=https://api.geoloc.app` — ✓ Built.

---

## Findings

Legend: **FIXED** | **PARTIAL** | **OPEN**

### UI Consistency

- ~~**[Blocker] Global status bar hardcoded to light mode**~~ — **FIXED.** Removed hardcoded overlay from `main.dart`; `GeolocApp` drives `SystemUiOverlayStyle` from resolved brightness via `AnnotatedRegion`.

- **[High] Two competing design systems** — **PARTIAL.** Committed to M3 + lavender `AmbientGlowBackground` as SoT. Cream/parchment surface tokens in `AppColors` marked `@Deprecated`; gold accents retained for `AppTextStyles`. Lavender glow vs white M3 cards still a visual tension — not fully unified.

- **[High] `AppSpacing` ~0% adoption** — **PARTIAL.** Feed list gutter migrated to `AppSpacing`; ~140+ literals remain across other screens.

- ~~**[High] Auth `Colors.white.withOpacity` hardcoding**~~ — **FIXED** on login/register (→ `colorScheme.onInverseSurface.withValues`). Login gradient scrim still uses some `withOpacity` on `Colors.black` (info-level).

- **[High] Component duplication** — **PARTIAL.** Dead widgets deleted (`HairlineDivider`, `CustomRefreshIndicator`, `AnimatedScrollGradientBackground`). `GeolocAppBar` promotion, shared moderation overflow menu, and `SliverAppBar` dedup **not done** (~10 screens still copy-pasted).

- **[Medium] Corner-radius chaos** — **OPEN.** 2px / 12–16px / 28px still coexist.

- **[Medium] Inconsistent state widgets** — **OPEN.** Chat/inbox/new-message still roll custom empty UIs; loading patterns still mixed.

- **[High] No accessibility text-scale handling** — **PARTIAL.** Nav bar height scales with `textScaler` (capped 1.35×). Post images, auth buttons, nav label font sizes still fixed.

- **[Low] Portrait-locked** — **OPEN** (product decision).

- **[Low] Pure Material** — **OPEN.**

---

### Animation Smoothness

- ~~**[Blocker] `_scrollToBottom()` in `build()`**~~ — **FIXED.** Scroll via `ref.listen` on message count + sticky-bottom flag; send forces stick-to-bottom.

- **[High] Always-on animation stack in `AppShell`** — **PARTIAL.** `AmbientGlowBackground` and `_CreatePostAttentionGlow` pause when app backgrounded. Per-frame gradient allocation and nav pill spring still run while foregrounded.

- ~~**[High] `TopBarBackdrop` BackdropFilter on every pinned app bar**~~ — **PARTIAL.** Blur disabled by default (`enableBlur: false`); semi-opaque tint used instead. Call sites unchanged; can opt into blur per screen.

- ~~**[High] Post-detail comments eager list**~~ — **FIXED.** Comments use `SliverList.builder`; post header remains in `SliverToBoxAdapter`.

- **[Medium] Chat read-receipt O(n²)** — **OPEN.** `indexWhere` ×2 per message per build.

- **[Medium] Missing `RepaintBoundary` / `Opacity` saveLayer on bubbles** — **OPEN.**

- **[Medium] Shimmer over-instantiation** — **OPEN** (~50 shimmer controllers on feed load).

- ~~**[Medium] Hero orphan on login**~~ — **FIXED.** Removed orphan `Hero(tag: 'app-logo')`.

- **[Medium] Nested shell route transitions** — **OPEN.**

- **Pass (unchanged):** All `AnimationController`s + `TabController` disposed; no `shrinkWrap` nested scrollables.

---

### Production Readiness

- ~~**[Blocker] No global error handling**~~ — **FIXED.** `crash_reporting.dart` + `runZonedGuarded` in `main.dart`.

- ~~**[Blocker] No Crashlytics / Firebase options**~~ — **PARTIAL.** `firebase_crashlytics` added; options wired; push nav implemented. **Still needed:** Xcode dSYM upload script, verify crashes in Firebase console, Analytics not added.

- ~~**[Blocker] Insecure default API**~~ — **FIXED.** Release defaults to `https://api.geoloc.app`; `assertValidForRelease()` enforces HTTPS. Debug retains LAN override via `--dart-define`.

- **[Blocker] Android release signed with debug keys** — **OPEN.** `android/app/build.gradle.kts:37-41` unchanged.

- ~~**[Blocker] iOS deep links unregistered**~~ — **FIXED.** `CFBundleURLTypes` for `geoloc` scheme in `Info.plist`.

- ~~**[Blocker] Version `0.0.1-alpha`**~~ — **FIXED.** `1.0.0+1`.

- **[High] Ungated `debugPrint`** — **PARTIAL.** `AppLogger` added; replaced in auth, DM, API client, push, post detail, profile. Not exhaustive grep across entire `lib/`.

- **[High] No localization** — **PARTIAL.** EN scaffold (`flutter_localizations`, `app_en.arb`, delegates). UI strings still hardcoded; `timeago` still `en_short`.

- ~~**[High] Deep-link empty catch blocks**~~ — **FIXED.** `AppLogger.warning` on deep-link failures.

- **[High] Critical flow test coverage** — **PARTIAL.** Widget test fixed; `push_navigation_test`, `app_config_test` added. **No** integration tests for login → feed → create post.

- **[Medium] Unchecked casts / force-unwraps** — **OPEN.**

- **[Medium] Accessibility gaps (icon-only controls)** — **OPEN.**

- **[Medium] No `PopScope` / state restoration** — **OPEN.**

- ~~**[Medium] CI not production-grade**~~ — **PARTIAL.** Flutter 3.29, strict analyze, iOS release `--no-codesign` in CI. No codesign, dSYM upload, or integration-test job.

---

### Resource Utilization

- ~~**[Blocker] Blocking startup before `runApp()`**~~ — **FIXED.** Hive still before `runApp` (required for auth disk reads); Firebase/Crashlytics/push listeners deferred post-frame. Push permission no longer at launch.

- ~~**[Blocker] Runtime `google_fonts` fetch**~~ — **FIXED.** Fonts bundled; `allowRuntimeFetching = false`.

- ~~**[High] Family providers never auto-dispose**~~ — **FIXED** for `dmChatProvider`, `profileProvider`, `postDetailProvider`.

- **[High] Zero `ref.select()`** — **PARTIAL.** Added on chat inbox keys, notification unread, DM unread. Feed still watches full `feedStateProvider`; per-post scoping not done.

- ~~**[High] Full-res cover/login images**~~ — **FIXED.** `memCacheWidth/Height` added; 80 MB `imageCache` cap.

- ~~**[High] SSE reconnect forever**~~ — **PARTIAL.** 2-minute cool-down after 20 failures; still `while(true)` (no background pause).

- ~~**[High] N+1 inbox/media + full inbox reload on chat open**~~ — **PARTIAL (client-side).** Parallel hydrate/sign; local mark-read replaces full reload. Server-side batch endpoints still absent.

- **[High] DM decrypt + JSON on UI isolate** — **OPEN.** `Future.wait` decrypt still on main isolate.

- **[Medium] Unbounded in-memory caches** — **OPEN.**

- **[Medium] Search stale-request guard / profile TTL** — **OPEN.**

- **Pass (unchanged):** Controller/timer/subscription disposal; feed disk cache + 5-min TTL; upload compression isolated.

---

## Prioritized Fix List (remaining)

Ordered by risk-to-ship:

### iOS App Store (manual / infra)

1. **[Blocker]** Apple codesign + provisioning profile for release/TestFlight.
2. **[Blocker]** Add Crashlytics dSYM upload run script in Xcode; verify a test crash in Firebase console.
3. **[High]** Set `aps-environment` to `production` in `Runner.entitlements` for store builds.
4. **[High]** Device QA: dark-mode status bar, offline cold start (fonts), `geoloc://reset-password?token=…`, push tap → correct screen.

### Cross-platform code

5. **[Blocker — Android only]** Real release signing in `android/app/build.gradle.kts`.
6. **[High]** Integration tests: login → feed → create post → view post (mocked API).
7. **[High]** Offload batch DM decrypt to `compute()` / `Isolate.run`.
8. **[High]** `ref.select` on feed state; per-post like scoping to stop full-list rebuilds.
9. **[High]** Finish design consolidation OR align `AmbientGlowBackground` base with M3 surface.
10. **[High]** Full ARB string extraction before non-English markets.
11. **[Medium]** Promote `GeolocAppBar`; extract shared moderation overflow menu.
12. **[Medium]** AppSpacing codemod (~140 literals).
13. **[Medium]** Accessibility: tooltips/semantics on icon-only controls; broader text-scale fixes.
14. **[Medium]** Chat read-receipt index precompute; single top-level `Shimmer` on feed load.
15. **[Medium]** SSE pause when app backgrounded; LRU on service caches.
16. **[Low]** Simplify shell route transitions; standardize corner radii.

---

## Severity Summary (post-hardening)

| Severity | Original | Resolved | Remaining |
|----------|----------|----------|-----------|
| **Blocker** | 16 | 11 (iOS) | 5 (Android signing ×1, dSYM/codesign ×2, DM isolate optional ×0, integration tests ×0) |
| **High** | 22 | ~12 partial/full | ~10 |
| **Medium** | 18 | ~4 partial | ~14 |
| **Low** | 6 | 2 | 4 |

*Counts are approximate; several items moved from Blocker → Partial when core fix landed but manual verification or follow-up remains.*

---

## Minimum Launch Checklist

| # | Item | Status |
|---|------|--------|
| 1 | `FlutterError.onError` + `PlatformDispatcher.onError` → Crashlytics | ✅ Done |
| 2 | `firebase_crashlytics` + `DefaultFirebaseOptions.currentPlatform` | ✅ Done |
| 3 | Release HTTPS API default + enforcement | ✅ Done |
| 4 | Build flavors (dev/staging/prod) | ❌ Not done |
| 5 | Release signing (Android + iOS) | ❌ Manual step required |
| 6 | iOS `CFBundleURLTypes` for reset-password | ✅ Done |
| 7 | Structured logger; gate `debugPrint` | ⚠️ Partial (`AppLogger`) |
| 8 | Integration tests for critical flows | ❌ Not done |
| 9 | Fix `widget_test.dart` for `MaterialApp.router` | ✅ Done |
| 10 | `localizationsDelegates` + ARB | ⚠️ EN scaffold only |

---

## Recommended Next Pass (UI)

1. **Promote `GeolocAppBar`** to replace ~10 copy-pasted `SliverAppBar` + `TopBarBackdrop` blocks.
2. **Extract `_ModerationOverflowMenu`** from the three overflow button files.
3. **Codemod `AppSpacing`** across remaining screens (start with auth, profile, inbox).
4. **Unify empty/loading/error** on chat, inbox filter, new-message sheet.
5. **Align glow base** (`#F0F2FA`) closer to M3 `colorScheme.surface` or document intentional contrast.
