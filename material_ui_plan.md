# Material UI Overhaul Plan (Material 3 / Material You)

## Goals

- Rebuild the app UI to a Google-style Material Design 3 experience.
- Remove legacy custom visual system (old-money theme, ad-hoc headers, custom typography helpers).
- Standardize all core screens and shared components on M3 semantics and component theming.

## Phase 1 — Foundation (Theme + App Shell)

1. Rebuild `lib/config/theme.dart`
   - Use `ThemeData(useMaterial3: true)` with:
     - `ColorScheme.fromSeed(seedColor: Color(0xFF1A73E8), brightness: ...)`
     - `GoogleFonts.plusJakartaSansTextTheme(...)`
   - Define M3 typescale in `textTheme` (displayLarge, headlineMedium, titleLarge, titleMedium, bodyLarge, bodyMedium, labelLarge, labelSmall).
   - Configure component themes centrally (no inline widget styling):
     - `AppBarTheme`
     - `NavigationBarThemeData`
     - `CardThemeData`
     - `FilledButtonThemeData`
     - `OutlinedButtonThemeData`
     - `TextButtonThemeData`
     - `FloatingActionButtonThemeData`
     - `InputDecorationTheme` (outlined, radius 8)
     - `ChipThemeData`
     - `BottomSheetThemeData`
     - `DialogThemeData`

2. Update `lib/app.dart`
   - Keep `theme`, `darkTheme`, `themeMode: ThemeMode.system`.
   - Remove text scale clamping logic.

3. Rebuild `lib/presentation/widgets/app_shell.dart`
   - Use M3 `NavigationBar` with destinations:
     - Home
     - Explore
     - Notifications
     - Profile
   - Ensure Profile resolves to current authenticated user id via `currentUserProvider`.
   - Add `FloatingActionButton.extended` for compose/post action.
   - Ensure all destinations route to real screens.

## Phase 2 — Core Screen Rebuilds (From Scratch)

1. `LoginScreen`
   - Surface background, centered icon + app name + tagline.
   - Labelled outlined/filled text fields.
   - Full-width `FilledButton` for sign-in.
   - `TextButton` for account creation.
   - Remove local asset background dependencies.

2. `FeedScreen`
   - `CustomScrollView` + `SliverAppBar.medium`.
   - `SliverList.builder` feed.
   - M3 post cards with proper hierarchy (author, timestamp, content, actions, counts).
   - Skeleton cards matching real post card layout.
   - FAB handled by shell.

3. `ProfileScreen`
   - `NestedScrollView` with `SliverAppBar.large`.
   - Avatar in flexible space.
   - Stats row as tonal cards/chips.
   - `FilledButton.tonal` for edit profile.
   - `TabBar` + `TabBarView` (Posts, Likes, Saved).

4. `PostDetailScreen`
   - `AppBar(elevation: 0)` with semantic back action.
   - Full post card at top.
   - Comments section label.
   - List-based comment tiles.
   - Sticky bottom input bar with text field + send icon.

## Phase 3 — Shared Components + State Widgets

1. Rebuild `PostCard` to an M3 card component.
2. Rebuild shimmer/skeleton placeholders to mirror final card geometry.
3. Standardize empty/error states to M3 spec:
   - Large semantic icon, headline, body, CTA.
4. Ensure all interaction controls use material buttons/icon buttons with >= 48 dp targets.

## Phase 4 — Cleanup and Deletions

1. Remove old style helper systems:
   - Delete `lib/core/theme/app_text_styles.dart`.
   - Delete `lib/core/theme/theme_extensions.dart`.
2. Replace call sites with `Theme.of(context).textTheme.*` and `Theme.of(context).colorScheme.*`.
3. Remove ad-hoc `GestureDetector` usage for nav/action controls and replace with material controls.
4. Remove hardcoded widget colors (`Color(...)`) from UI layer in favor of color roles.

## Phase 5 — Verification

1. Run static analysis and fix issues.
2. Verify navigation reachability for all bottom destinations.
3. Smoke test major flows:
   - Login
   - Feed list + pull-to-refresh + pagination
   - Profile navigation from bottom bar
   - Post detail + comments input
4. Confirm dark mode rendering and semantic color role usage.

