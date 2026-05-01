# UI/UX Audit Report — Geoloc App

**Date:** 1 May 2026  
**Auditor:** Senior Frontend Engineering Review  
**Framework:** Flutter 3.x (Material 3, Riverpod, GoRouter)

---

## Executive Summary

The Geoloc Flutter application demonstrates a **mature, thoughtfully crafted design system** with a distinctive "old-money luxury" aesthetic—warm neutrals, gold accents, PT Serif / Plus Jakarta Sans typography, and 2-pt sharp-corner geometry. The codebase exhibits strong engineering discipline: shared widget primitives (`GeolocAppBar`, `EmptyState`, `ErrorState`, `LoadingShimmer`), a centralized token system (`AppColors`, `AppSpacing`, `AppRadii`), and consistent use of Riverpod for reactive state management. However, several patterns undermine consistency: **inconsistent AppBar usage** across screens, **Google Fonts called directly** instead of leveraging the Theme's `textTheme`, **accessibility gaps** (missing semantic labels and autofill hints), **portrait-only lock** limiting tablet/landscape users, and **minor performance concerns** in the custom shimmer animation. The top priorities are: (1) unifying AppBar usage, (2) migrating all typography to Theme references, (3) closing accessibility gaps, and (4) fixing the FAB anchoring.

---

## 1. Visual Design & Consistency

### 1.1 Typography Hierarchy

**Current State:**  
The `AppTheme` defines a well-structured `TextTheme` with PT Serif for display/headline/title roles and Plus Jakarta Sans for body/label roles. FiraCode is used for timestamps and numeric data (`labelSmall`). Font sizes follow a logical hierarchy.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 1.1a | **`GoogleFonts.xxx()` called directly instead of `context.textTheme`** — roughly 80+ call sites bypass the Theme's `textTheme`. This means font changes in `AppTheme` won't propagate; every screen hardcodes its own style. | `post_card.dart:L89`, `feed_screen.dart:L103`, `login_screen.dart:L149`, `create_post_screen.dart:L81`, `notifications_screen.dart:L138`, et al. | 🔴 Critical |
| 1.1b | **Line-height (`height`) only set on `bodyLarge` posts** — Other text styles lack explicit `height`, leading to inconsistent line spacing across devices. The post body uses `height: 1.5` but comments and form labels do not. | `post_card.dart:L141` | 🟡 Medium |
| 1.1c | **Password field uses 6-char minimum in login but 8-char in register** — Inconsistent validation UX. | `login_screen.dart:L261` vs `register_screen.dart:L313` | 🟡 Medium |

**Recommendation 1.1a:**  
Replace all direct `GoogleFonts.xxx()` calls with `Theme.of(context).textTheme` or the `GeolocThemeContext` extension:

```dart
// ❌ Current (post_card.dart)
Text(
  post.author?.username ?? 'Username',
  style: GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: cs.onSurface,
  ),
)

// ✅ Recommended
Text(
  post.author?.username ?? 'Username',
  style: context.textTheme.titleSmall?.copyWith(color: cs.onSurface),
)
```

Add missing styles to `AppTheme` to cover all needed variants (e.g., `titleSmall` for usernames, `bodySmall` for muted captions).

### 1.2 Color Palette & Design System Adherence

**Current State:**  
`AppColors` provides a comprehensive old-money palette with light/dark variants, semantic colors (error, success, warning, info), and gold accent resolution via `AppColors.gold(context)`. The `ColorScheme` is wired into `ThemeData`.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 1.2a | **`Colors.black.withValues(alpha: 0.35)` hardcoded** — the profile overflow menu uses a raw black overlay instead of a theme-derived surface color. | `profile_overflow_menu_button.dart:L26` | 🟡 Medium |
| 1.2b | **Login dark gradient overlay uses raw `Colors.black`** — Should use a theme-token dark overlay for consistency. | `login_screen.dart:L116-L124` | 🟢 Nice-to-have |
| 1.2c | **`Colors.white` used in overflow image counter** — breaks dark-mode consistency. Should use `cs.onPrimary` or a light-surface token. | `post_card.dart:L316` | 🟡 Medium |

**Recommendation 1.2c:**  
```dart
// ❌ Current
color: Colors.white,

// ✅ Recommended
color: Theme.of(context).colorScheme.onPrimary,
```

### 1.3 Spacing, Padding & Alignment

**Current State:**  
`AppSpacing` defines a 4-pt scale (xxs=2 through huge=40) with `pagePadding` and `cardPadding` constants. `AppRadii` provides `sharp=2`, `soft=8`, `pill=999`.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 1.3a | **Magic numbers used instead of `AppSpacing` tokens** — `PostCard` uses `margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)` instead of `AppSpacing.md` (12) and `AppSpacing.xxs` for the 6 (no exact match, but 8 = `sm` would be close). | `post_card.dart:L30` | 🟡 Medium |
| 1.3b | **`PostCard` padding uses `const EdgeInsets.all(16)`** — should use `AppSpacing.cardPadding` which is already defined as `EdgeInsets.all(16)`. | `post_card.dart:L31` | 🟡 Medium |
| 1.3c | **Inconsistent padding in auth screens** — Login uses `left: 32, right: 32`, ForgotPassword uses `horizontal: 28`. | `login_screen.dart:L159` vs `forgot_password_screen.dart:L99` | 🟢 Nice-to-have |

**Recommendation 1.3a–b:**  
```dart
// ❌ Current
margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
padding: const EdgeInsets.all(16),

// ✅ Recommended
margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
padding: AppSpacing.cardPadding,
```

### 1.4 Iconography Style & Sizing

**Current State:**  
`AppIconSize` provides a size ramp (xs=14, sm=16, md=20, lg=24). Icons are predominantly Material `Icons.xxx_outlined` variants, aligning with the understated old-money aesthetic.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 1.4a | **Mix of filled and outlined icon variants** — The like button toggles between `Icons.favorite` (filled) and `Icons.favorite_outline` which is correct, but some icons use filled variants inconsistently (e.g., `Icons.arrow_back` in GeolocAppBar contexts vs `Icons.arrow_back` elsewhere). | Various | 🟢 Nice-to-have |
| 1.4b | **`IconSquareButton` vs raw `GestureDetector` inconsistency** — `FeedScreen._buildProfileLeading` builds a raw 34×34 square with `GestureDetector` + `Container` while `IconSquareButton` exists for exactly this purpose. | `feed_screen.dart:L247-L302` | 🟡 Medium |

**Recommendation 1.4b:**  
FeedScreen's profile avatar leading widget should either use `IconSquareButton` with a custom child or extract a reusable `AvatarIconButton` component. The current inline implementation duplicates the 44pt touch-target pattern already solved by `IconSquareButton`.

---

## 2. Component Architecture

### 2.1 Widget Reusability

**Current State:**  
Strong extraction of shared widgets: `GeolocAppBar`, `EmptyState`, `ErrorState`, `LoadingShimmer` (+`PostCardShimmer`/`FeedShimmer`), `IconSquareButton`, `UserAvatar`, `PostCard`, `Wordmark`, `HairlineDivider`, `LocationPermissionPrompt`, `CustomRefreshIndicator`, `CommentOverflowMenuButton`, `PostOverflowMenuButton`, `ProfileOverflowMenuButton`.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 2.1a | **Bottom sheet pattern duplicated 3×** — `FeedScreen._showLogoutSheet`, `CreatePostScreen._showMediaPicker`, `EditProfileScreen._showImagePickerSheet` all share the same structure: section title in gold PT Serif → gradient hairline → action buttons. This pattern should be a reusable `ActionSheet` widget. | `feed_screen.dart:L76-L157`, `create_post_screen.dart:L54-L130`, `edit_profile_screen.dart:L118-L230` | 🟡 Medium |
| 2.1b | **Error banner duplicated** — The inline error container with `AppColors.error.withValues(alpha: 0.08)` background, icon, and text appears identically in `LoginScreen` and `RegisterScreen`. | `login_screen.dart:L173-L196`, `register_screen.dart:L149-L172` | 🟡 Medium |
| 2.1c | **`GeolocAppBar` not used in 4 screens** — `SettingsScreen`, `BlockedUsersScreen`, `MutedUsersScreen`, and `ForgotPasswordScreen`/`ResetPasswordScreen` all use the default Material `AppBar` with inline styling instead of the shared `GeolocAppBar`. | `settings_screen.dart:L25-L35`, `blocked_users_screen.dart:L19-L30`, etc. | 🔴 Critical |
| 2.1d | **No design token system for text styles** — While `AppColors`, `AppSpacing`, and `AppRadii` exist as tokens, there's no equivalent `AppTextStyles` class. All typography is done via `GoogleFonts.xxx()` at each call site. | Throughout | 🔴 Critical |

**Recommendation 2.1a — Extract `ActionSheet` widget:**  
```dart
class GeolocActionSheet extends StatelessWidget {
  const GeolocActionSheet({
    super.key,
    required this.title,
    required this.children,
    this.cancelLabel = 'Cancel',
    this.onCancel,
  });

  final String title;
  final List<Widget> children;
  final String cancelLabel;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 20;

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: /* ... */),
          const SizedBox(height: 16),
          const HairlineDivider(),
          const SizedBox(height: 12),
          ...children,
          if (cancelLabel != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onCancel ?? () => Navigator.pop(context),
              child: Text(cancelLabel, style: /* ... */),
            ),
          ],
        ],
      ),
    );
  }
}
```

**Recommendation 2.1c:**  
All screens should use `GeolocAppBar` for a consistent top-bar experience. Update `SettingsScreen`, `BlockedUsersScreen`, `MutedUsersScreen`, `ForgotPasswordScreen`, and `ResetPasswordScreen`.

### 2.2 Overuse or Misuse of Flutter Built-in Widgets

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 2.2a | **`CustomScrollView` only used in `PostDetailScreen`** — Other list screens (Feed, Notifications, BlockedUsers, MutedUsers) use `ListView` + `RefreshIndicator`. The feed could benefit from `CustomScrollView` with slivers for the tab bar + content to avoid nested scroll views. | `feed_screen.dart` | 🟢 Nice-to-have |
| 2.2b | **`AnimatedBuilder` in `LoadingShimmer` listens to the full animation** — The builder is called on every frame of the 1.4s repeating animation, repainting the entire shimmer widget. For a list with 5 shimmer cards, that's 5 concurrent AnimationControllers. | `loading_shimmer.dart:L45-L73` | 🟡 Medium |
| 2.2c | **`AlwaysScrollableScrollPhysics` used everywhere** — Forces scrollability even when content fits. While intentional for pull-to-refresh, it disables the bounce effect on iOS when content is smaller than the viewport. | `feed_screen.dart:L338`, `blocked_users_screen.dart:L56` | 🟢 Nice-to-have |

**Recommendation 2.2b:**  
Consider using a single `AnimationController` shared across shimmer items via `InheritedWidget` or Riverpod, or use the `shimmer` package which handles this efficiently. The current custom implementation spins up `N` controllers for `N` shimmer items.

---

## 3. User Experience & Interaction

### 3.1 Navigation Patterns & Information Architecture

**Current State:**  
GoRouter with clean path-based routing. No `BottomNavigationBar` exists — navigation flows through the feed's top bar (profile avatar, notifications bell) and tapping posts/comments. The feed uses a dual-tab layout (Nearby / Following).

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 3.1a | **No bottom navigation bar** — Users must navigate through the feed's top bar for all destinations. There's no tab bar for common destinations like Feed, Search, Post, Notifications, Profile. This is atypical for a social media app and increases cognitive load. | `feed_screen.dart` — no `BottomNavigationBar` | 🔴 Critical |
| 3.1b | **"Following" tab shows "Still under construction"** — This dead-end tab provides no value and creates a broken-glass experience. | `feed_screen.dart:L201-L206` | 🔴 Critical |
| 3.1c | **No back-swipe gesture on iOS** — Routes use `builder:` instead of `pageBuilder:` with `CustomTransitionPage`, losing the iOS edge-swipe back gesture for most routes. Only `RegisterScreen` uses `pageBuilder`. | `routes.dart:L115-L142` | 🟡 Medium |
| 3.1d | **`FloatingActionButtonLocation.endDocked` used without a dock** — `endDocked` is designed to dock the FAB into a `BottomAppBar`. Since there's no `BottomAppBar`, this location effectively places the FAB floating at the bottom-right. Should use `endFloat` instead. | `feed_screen.dart:L210` | 🟡 Medium |

**Recommendation 3.1a–b:**  
Add a proper `BottomNavigationBar` (or `NavigationBar` for M3) with 4 tabs: Feed, Search, Create Post (+), Notifications. Consider a `Scaffold` with `bottomNavigationBar` at the app level via a `ShellRoute` in GoRouter:

```dart
// routes.dart — ShellRoute pattern
ShellRoute(
  builder: (context, state, child) => AppShell(child: child),
  routes: [
    GoRoute(path: '/feed', builder: (_, __) => const FeedScreen()),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
  ],
)
```

Remove the "Following" tab or implement it before shipping.

### 3.2 Feedback Mechanisms

**Current State:**  
Good use of `LoadingShimmer`/`FeedShimmer` for loading states, `EmptyState` for empty states, and `ErrorState` for errors. Toast messages via `SnackBar`.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 3.2a | **No pull-to-refresh haptic feedback** — When a user pulls to refresh and data loads, there's no haptic confirmation. | `feed_screen.dart` | 🟢 Nice-to-have |
| 3.2b | **`_SplashScreen` has no branding** — Displays a bare `CircularProgressIndicator`. Should show the wordmark and a subtle animation for brand reinforcement. | `routes.dart:L211-L215` | 🟡 Medium |
| 3.2c | **No "undo" for destructive actions** — Block, mute, and delete operations show confirmation dialogs but no undo snackbar after the action completes. | `post_overflow_menu_button.dart`, `comment_overflow_menu_button.dart` | 🟡 Medium |
| 3.2d | **Like button has no optimistic update animation** — The heart icon toggles instantly without scale/spring animation. A subtle `Transform.scale` bounce would improve perceived responsiveness. | `post_card.dart:_ActionButton` | 🟢 Nice-to-have |

**Recommendation 3.2d:**  
```dart
// Add a brief scale animation on like toggle
void _onLikeTap() {
  _scaleController.forward().then((_) => _scaleController.reverse());
  onTap?.call();
}
// Wrap Icon in ScaleTransition
```

### 3.3 Gesture Support & Touch Target Sizing

**Current State:**  
`AppTapTarget` defines iOS (44pt) and Material (48pt) minimums. `IconSquareButton` enforces 44×44pt with `Semantics` and `InkResponse`. The profile avatar in the feed also has a 44pt container.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 3.3a | **`_ActionButton` (like/comment/share) has no minimum touch target** — The `GestureDetector` wraps a `Padding(4,4)` + `Row` with no size constraint, making these critical interaction points potentially smaller than 48×48dp. | `post_card.dart:L355-L384` | 🔴 Critical |
| 3.3b | **"Forgot Password" button uses `tapTargetSize: MaterialTapTargetSize.shrinkWrap`** — This shrinks the touch target below accessibility minimums. | `login_screen.dart:L283` | 🟡 Medium |
| 3.3c | **Comment thread reply/edit buttons have small tap targets** — The inline reply/edit actions in `PostDetailScreen` use small tap targets without minimum size enforcement. | `post_detail_screen.dart` (CommentThread widget) | 🟡 Medium |

**Recommendation 3.3a:**  
```dart
// ❌ Current _ActionButton
return GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Padding(/* ... */),
);

// ✅ Recommended: enforce 48×48 minimum
return GestureDetector(
  onTap: onTap,
  behavior: HitTestBehavior.opaque,
  child: Container(
    constraints: const BoxConstraints(
      minWidth: AppTapTarget.materialMinimum,
      minHeight: AppTapTarget.materialMinimum,
    ),
    alignment: Alignment.center,
    child: Padding(/* ... */),
  ),
);
```

### 3.4 Micro-interactions & Animation Quality

**Current State:**  
`RegisterScreen` uses a `SlideTransition` for a bottom-sheet entry. The login card has an `AnimatedContainer` reacting to keyboard height. `LoadingShimmer` has a custom shimmer animation. `AnnotatedRegion` is used for status bar style changes.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 3.4a | **No page transition animations** — Most routes use `builder:` which provides no transition. Only `RegisterScreen` has a custom transition. iOS users expect slide-from-right transitions. | `routes.dart` — most routes | 🟡 Medium |
| 3.4b | **No staggered list animations** — Posts appear instantly. A subtle fade-in or slide-up stagger on first load would elevate the luxury feel. | `feed_screen.dart:_buildBody` | 🟢 Nice-to-have |
| 3.4c | **No tab switch animation** — Switching between Nearby/Following tabs has no crossfade or slide. | `feed_screen.dart:TabBarView` | 🟢 Nice-to-have |

---

## 4. Accessibility

### 4.1 Semantic Labels & Screen Reader Support

**Current State:**  
`IconSquareButton` wraps itself in `Semantics(button: true, label: semanticLabel)`. `Wordmark` has `Semantics(label: 'Geoloc', header: true)`. The feed avatar has `Semantics(label: 'Profile (long-press for account menu)', button: true)`.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 4.1a | **Post cards have no semantic labels** — The `GestureDetector` wrapping the entire `PostCard` has no `Semantics` node. Screen readers cannot identify it as a tappable element. | `post_card.dart:L28` | 🔴 Critical |
| 4.1b | **`_ActionButton` (like/comment/share) has no semantics** — These are icon-only buttons with no screen-reader labels. | `post_card.dart:L355-L384` | 🔴 Critical |
| 4.1c | **No `Semantics` on image media in PostCard** — `CachedNetworkImage` has no `semanticLabel` for alt-text. | `post_card.dart:_buildMedia` | 🟡 Medium |
| 4.1d | **Form fields have no `autofillHints`** — Login and register forms should provide `AutofillHints.email`, `AutofillHints.password`, `AutofillHints.username`, `AutofillHints.name` for password manager integration. | `login_screen.dart`, `register_screen.dart` | 🟡 Medium |
| 4.1e | **Notifications list items have no semantics** — Each notification row is wrapped in `GestureDetector` without a semantic label. | `notifications_screen.dart:L118` | 🟡 Medium |

**Recommendation 4.1a–b:**  
```dart
// PostCard GestureDetector
return Semantics(
  button: true,
  label: 'Post by ${post.author?.username ?? 'unknown'}',
  child: GestureDetector(
    onTap: onTap,
    child: Container(/* ... */),
  ),
);

// _ActionButton
Widget build(BuildContext context) {
  final label = switch (icon) {
    Icons.favorite || Icons.favorite_outline => 'Like${label != null ? ", $label likes" : ""}',
    Icons.chat_bubble_outline => 'Comment${label != null ? ", $label comments" : ""}',
    Icons.share_outlined => 'Share',
    _ => 'Action',
  };
  return Semantics(
    button: true,
    label: label,
    child: GestureDetector(/* ... */),
  );
}
```

**Recommendation 4.1d:**  
```dart
TextFormField(
  autofillHints: const [AutofillHints.email],
  controller: _emailController,
  // ...
)
```

### 4.2 Color Contrast Ratios (WCAG AA)

**Current State:**  
The old-money palette uses muted, warm tones. Let's analyze key foreground/background pairs:

| Element | Foreground | Background | Approx. Ratio | Pass AA? |
|---------|-----------|------------|---------------|----------|
| Body text (light) | `#1E1810` (textLight) | `#F5F0E8` (bgLight) | ~13:1 | ✅ AAA |
| Muted text (light) | `#7A6A50` (textMutedLight) | `#F5F0E8` (bgLight) | ~4.2:1 | ✅ AA (lg text), ⚠️ borderline for body |
| Gold on cream (light) | `#8B6914` (goldDeep) | `#F5F0E8` (bgLight) | ~4.5:1 | ✅ AA |
| Body text (dark) | `#F5F0E8` (textDark) | `#1A1714` (bgDark) | ~12:1 | ✅ AAA |
| Error on bg (light) | `#B44D4D` (error) | `#F5F0E8` (bgLight) | ~4.2:1 | ⚠️ Borderline |
| Gold on dark surface | `#C9A84C` (goldBright) | `#2C2420` (surfaceDark) | ~3.8:1 | ❌ Fails AA for body text |

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 4.2a | **Gold accent on dark surfaces fails WCAG AA for body text** — `goldBright (#C9A84C)` on `surfaceDark (#2C2420)` yields ~3.8:1, below the 4.5:1 minimum for normal text. Gold buttons with dark text pass, but gold text labels (e.g., "SIGN IN" button text) may be hard to read. | `login_screen.dart:L316`, `register_screen.dart` | 🟡 Medium |
| 4.2b | **`textMutedLight (#7A6A50)` on `bgLight (#F5F0E8)`** — At ~4.2:1, this is borderline for body text at smaller sizes. Consider darkening to `#6B5A40` or using a slightly larger font size. | `app_colors.dart:L11` | 🟢 Nice-to-have |
| 4.2c | **Error text on error backgrounds** — Error banners use `error` text on `error.withAlpha(0.08)` — the contrast between error text and the tinted background may be insufficient. | `login_screen.dart:L173-L196` | 🟢 Nice-to-have |

**Recommendation 4.2a:**  
For dark mode gold text elements, consider using `goldLight (#E8C97A)` instead of `goldBright (#C9A84C)` for body-sized text:
```dart
// Add to AppColors / ThemeExtension
static Color goldText(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? goldLight   // lighter, better contrast
      : goldDeep;
}
```

### 4.3 Text Scalability

**Current State:**  
No explicit testing for system font size changes. `Text` widgets use fixed `fontSize` values (mostly 10–24px).

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 4.3a | **No `textScaleFactor` clamping** — The app does not use `MediaQuery.textScaler` or clamp text scaling. On devices with large accessibility font sizes, layout will break. | `app.dart` — no `MediaQuery` override | 🔴 Critical |
| 4.3b | **Fixed-height containers with text inside** — The profile screen's cover image area uses fixed pixel heights. If text scales up inside these areas, overflow will occur. | `profile_screen.dart:L133-L145` | 🟡 Medium |

**Recommendation 4.3a:**  
```dart
// In app.dart or main.dart
MaterialApp.router(
  builder: (context, child) {
    final mediaQuery = MediaQuery.of(context);
    final clampedScale = mediaQuery.textScaler.clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: 1.3,
    );
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedScale),
      child: child!,
    );
  },
  // ...
);
```

---

## 5. Responsiveness & Adaptability

### 5.1 Screen Size & Orientation Handling

**Current State:**  
`main.dart` locks orientation to portrait-only via `SystemChrome.setPreferredOrientations`. No tablet or landscape layouts exist.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 5.1a | **Portrait-only lock** — The app is locked to portrait mode with no landscape support, and no tablet adaptations. While acceptable for v1, this should be documented as a known limitation and addressed for tablet users. | `main.dart:L13-L16` | 🟡 Medium |
| 5.1b | **No `LayoutBuilder` or `Breakpoint` usage** — Screens use `MediaQuery.of(context).size` ad-hoc (notably login screen) but there's no breakpoint system for tablet layouts. | `login_screen.dart:L84-L86` | 🟡 Medium |
| 5.1c | **Feed cards are full-width regardless of screen width** — On tablets, post cards would stretch to unreasonable widths. | `post_card.dart` — no `maxWidth` constraint | 🟡 Medium |

**Recommendation 5.1c:**  
```dart
// Constrain card width on wide screens
return Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 600),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      // ... existing card content
    ),
  ),
);
```

### 5.2 Safe Area & Notch Handling

**Current State:**  
`GeolocAppBar` adds `MediaQuery.paddingOf(context).top` for status bar inset. Other screens handle it inconsistently.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 5.2a | **Inconsistent safe area handling** — `FeedScreen` uses `GeolocAppBar` (handles top safe area) but adds `padding: const EdgeInsets.only(bottom: 80)` without accounting for the bottom safe area (home indicator on iOS). | `feed_screen.dart:L337` | 🔴 Critical |
| 5.2b | **`PostDetailScreen` disables safe area** — Uses `SafeArea(top: false, bottom: false)` which causes content to render under the status bar and home indicator. The custom header compensates for top, but the comment input at the bottom doesn't account for the home indicator. | `post_detail_screen.dart:L166` | 🔴 Critical |
| 5.2c | **`CreatePostScreen` does the same** — `SafeArea(top: false, bottom: false)` with manual top padding, but the bottom toolbar lacks home indicator padding. | `create_post_screen.dart:L130` | 🟡 Medium |

**Recommendation 5.2a:**  
```dart
// ❌ Current
padding: const EdgeInsets.only(bottom: 80),

// ✅ Recommended
padding: EdgeInsets.only(
  bottom: 80 + MediaQuery.paddingOf(context).bottom,
),
```

### 5.3 Platform-Specific Adaptations

**Current State:**  
No explicit platform-adaptive widgets (`CupertinoXxx`). The app uses Material Design throughout with `ThemeData(useMaterial3: true)`. Icons are Material.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 5.3a | **No iOS-style scroll physics** — `AlwaysScrollableScrollPhysics` is used everywhere instead of platform-adaptive physics (bouncy on iOS, clamping on Android). | `feed_screen.dart:L338` | 🟢 Nice-to-have |
| 5.3b | **iOS edge-swipe back missing** — GoRouter's `builder:` method doesn't use iOS-style page transitions with swipe-back. Only `RegisterScreen` uses `pageBuilder` with `CustomTransitionPage`. | `routes.dart` | 🟡 Medium |

---

## 6. Performance-Impacting UI Patterns

### 6.1 Unnecessary Rebuilds

**Current State:**  
Riverpod with `ConsumerStatefulWidget` and `ConsumerWidget` used correctly. `ref.watch` is used at appropriate granularity. The router uses a `ValueNotifier` fed from `ref.listen` to avoid tearing down the navigator on every auth state change — excellent.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 6.1a | **`_buildProfileLeading` watches `currentUserProvider`** — This triggers a rebuild of the entire `FeedScreen` whenever the current user changes, even though only the avatar in the app bar needs updating. | `feed_screen.dart:L238` | 🟡 Medium |
| 6.1b | **`LoadingShimmer` creates `AnimationController` per widget** — In a feed with 5 shimmer cards, 5 `AnimationController`s run concurrently, each calling `setState` every ~16ms. A single shared controller would be more efficient. | `loading_shimmer.dart:L30-L35` | 🟡 Medium |

**Recommendation 6.1a:**  
Extract the profile-leading widget into its own `ConsumerWidget`:
```dart
class FeedProfileAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    // ... avatar build logic
  }
}
```

### 6.2 Heavy Widgets in Lists

**Current State:**  
`ListView.builder` is used correctly for lazy loading. `CachedNetworkImage` with `memCacheWidth`/`memCacheHeight` limits memory for decoded images — excellent practice.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 6.2a | **`PostCard` is not `const`** — The `PostCard` constructor takes `required this.post` (non-const) so it can't be const-constructed. However, `Row`/`Column` children within the card could use more `const` constructors for static elements. | `post_card.dart` | 🟢 Nice-to-have |
| 6.2b | **Login screen loads full-resolution background image** — `Image.asset('assets/images/IMG_6454.JPEG', width: screenSize.width, height: screenSize.height)` decodes the image at full screen resolution every rebuild. Consider using `memCacheWidth`/`memCacheHeight` or a lower-resolution variant. | `login_screen.dart:L89-L93` | 🟡 Medium |

**Recommendation 6.2b:**  
```dart
Image.asset(
  'assets/images/IMG_6454.JPEG',
  width: screenSize.width,
  height: screenSize.height,
  fit: BoxFit.cover,
  cacheWidth: (screenSize.width * MediaQuery.devicePixelRatioOf(context)).round(),
),
```

### 6.3 Overdraw & Opacity/Clipping Misuse

**Current State:**  
`ClipRRect` is used for image corners in post cards. `Opacity` is not used (correct — `withValues(alpha: ...)` is used instead for colors). Cached images use `placeholder` and `errorWidget` correctly.

**Issues Found:**

| # | Issue | Location | Severity |
|---|-------|----------|----------|
| 6.3a | **`ClipOval` in `UserAvatar` for every avatar** — `ClipOval` triggers anti-aliased clipping which is more expensive than `BorderRadius.circular`. For a list with many avatars, consider `ClipRRect(borderRadius: BorderRadius.circular(size/2))`. | `user_avatar.dart:L77` | 🟢 Nice-to-have |
| 6.3b | **`Stack` used for login screen overlay** — The login screen uses a `Stack` with a full-screen `Image.asset` behind the card. On every keyboard show/hide, the entire stack rebuilds due to the `AnimatedContainer`. | `login_screen.dart:L88-L250` | 🟡 Medium |

---

## 7. Prioritised Action Plan

Top 10 changes ranked by impact-to-effort ratio:

| Rank | Change | Category | Priority |
|------|--------|----------|----------|
| **1** | **Replace all direct `GoogleFonts.xxx()` calls with `context.textTheme` references** — Add missing styles to `AppTheme`, then migrate ~80+ call sites. Create `AppTextStyles` token class if needed. | Visual Design | 🔴 Critical |
| **2** | **Add `Semantics` labels to `PostCard`, `_ActionButton`, and all interactive elements** — Every tappable widget must have a semantic label. Add `autofillHints` to all form fields. | Accessibility | 🔴 Critical |
| **3** | **Unify AppBar usage: replace Material `AppBar` with `GeolocAppBar`** — Update `SettingsScreen`, `BlockedUsersScreen`, `MutedUsersScreen`, `ForgotPasswordScreen`, `ResetPasswordScreen`. | Component Architecture | 🔴 Critical |
| **4** | **Fix safe area / home indicator handling** — Add bottom padding accounting for `MediaQuery.paddingOf(context).bottom` in feed list, post detail comment input, create post toolbar. | Responsiveness | 🔴 Critical |
| **5** | **Implement or remove "Following" tab** — Replace "Still under construction" placeholder with a working implementation or hide the tab until ready. | UX | 🔴 Critical |
| **6** | **Add proper bottom navigation bar** — Use `NavigationBar` (M3) or `BottomNavigationBar` with ShellRoute for Feed, Search, Notifications, Profile. | Navigation | 🔴 Critical |
| **7** | **Enforce minimum touch targets on `_ActionButton` and "Forgot Password"** — Ensure all interactive elements meet 48×48dp minimum. | UX/Gesture | 🔴 Critical |
| **8** | **Extract duplicated bottom-sheet pattern into `GeolocActionSheet`** — Eliminate 3× duplicated sheet layouts. | Component Architecture | 🟡 Medium |
| **9** | **Clamp `textScaleFactor` to 1.0–1.3** — Add `MediaQuery` override in `MaterialApp.router` builder to prevent layout breakage with large accessibility fonts. | Accessibility | 🟡 Medium |
| **10** | **Fix `FloatingActionButtonLocation.endDocked` → `endFloat`** — Address incorrect FAB anchoring. | UX | 🟡 Medium |

---

## Appendix A: Quick Wins (Low Effort, High Impact)

These changes can be implemented in under an hour each:

1. Add `autofillHints` to all `TextFormField` widgets (login, register, forgot password, reset password)
2. Fix `FloatingActionButtonLocation.endDocked` → `endFloat` in `feed_screen.dart:L210`
3. Add `semanticLabel` to `_ActionButton` in `post_card.dart` (like, comment, share)
4. Replace magic numbers with `AppSpacing` tokens in `PostCard` margin/padding
5. Brand the `_SplashScreen` with the `Wordmark` widget
6. Add `cacheWidth`/`cacheHeight` to the login screen background image
7. Add `const` constructors to static children in `PostCard` widget tree
8. Change `ProfileOverflowMenuButton` raw black overlay to theme-aware color

---

## Appendix B: Design Token Audit

| Token Category | Status | Notes |
|---------------|--------|-------|
| Colors (`AppColors`) | ✅ Complete | Light/dark pairs, semantic colors, gold accent resolution |
| Spacing (`AppSpacing`) | ✅ Complete | 4-pt scale, page/card constants |
| Border Radius (`AppRadii`) | ✅ Complete | Sharp (2), soft (8), pill (999) |
| Icon Sizes (`AppIconSize`) | ✅ Complete | 14–24pt ramp |
| Touch Targets (`AppTapTarget`) | ✅ Complete | iOS 44pt, Material 48pt |
| **Text Styles** | ❌ Missing | No `AppTextStyles` class; direct `GoogleFonts.xxx()` everywhere |
| **Elevation/Shadow** | ❌ Missing | App uses `elevation: 0` everywhere; flat design is consistent but not tokenized |
| **Animation Durations** | ❌ Missing | `Duration(milliseconds: 350)` etc. scattered across files |
| **Breakpoints** | ❌ Missing | No responsive breakpoint system |

---

*End of report.*
