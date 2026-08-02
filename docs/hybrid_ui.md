# Hybrid UI: Native SwiftUI + Flutter

How Geoloc combines Flutter (Dart) widgets with native iOS SwiftUI for system Liquid Glass chrome.

## Why hybrid?

Flutter’s `BackdropFilter` can approximate blur, but it does not use Apple’s Liquid Glass materials, motion response, or system Display / Accessibility settings (Reduce Transparency, Liquid Glass tint, Increase Contrast).

For top and bottom chrome that should feel native on iOS, we embed a SwiftUI view via a **Flutter Platform View** (`UiKitView`). Interactive content (icons, labels, buttons) stays in Flutter and is stacked on top.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Flutter (Dart)                                                │
│                                                              │
│  AppShell / GeolocAppBar / screens                           │
│       │                                                      │
│       ▼                                                      │
│  TopBarBackdrop  ──┐                                         │
│  AppShell nav      ├──►  NativeGlassCard                     │
│                    │         │                               │
│                    │         ├─ iOS  → UiKitView             │
│                    │         └─ else → BackdropFilter fallback│
└────────────────────┼─────────────────┬───────────────────────┘
                     │                 │
                     │   viewType      │ creationParams
                     │   "com.example.native_liquid_glass"     │
                     ▼                 ▼
┌──────────────────────────────────────────────────────────────┐
│ iOS (Swift)                                                   │
│                                                              │
│  AppDelegate                                                 │
│    registrar("SwiftUIGlassPlugin")                           │
│    register factory id: com.example.native_liquid_glass      │
│                                                              │
│  SwiftUIGlassFactory  →  GlassPlatformView                   │
│                              │                               │
│                              ▼                               │
│                     UIHostingController                      │
│                       backgroundColor = .clear               │
│                              │                               │
│                              ▼                               │
│                       SwiftUIGlassView                       │
│                    .glassEffect(.clear) / .ultraThinMaterial │
└──────────────────────────────────────────────────────────────┘
```

**Composition rule:** native glass is the **background layer only**. Flutter children sit in a `Stack` above the platform view so taps and layout stay in Dart.

## File map

| Layer | Path | Role |
|-------|------|------|
| Dart widget | `lib/presentation/widgets/native_glass_card.dart` | Chooses `UiKitView` vs fallback; encodes params |
| Top bar | `lib/presentation/widgets/top_bar_backdrop.dart` | Fills app bars with chrome-only glass |
| Bottom nav | `lib/presentation/widgets/app_shell.dart` | Glass behind capsule nav items |
| Registration | `ios/Runner/AppDelegate.swift` | Registers the platform-view factory |
| Factory | `ios/Runner/GlassViewFactory.swift` | `FlutterPlatformView` + `UIHostingController` |
| SwiftUI UI | `ios/Runner/SwiftUIGlassView.swift` | Liquid Glass / material rendering |

## Parameter bridge

Flutter → native uses `StandardMessageCodec` via `UiKitView.creationParams`.

| Key | Type | Purpose |
|-----|------|---------|
| `title` | `String` | Optional headline (empty = chrome-only) |
| `subtitle` | `String` | Optional subtitle (empty = chrome-only) |
| `topLeadingRadius` | `number` | Top-left corner radius |
| `topTrailingRadius` | `number` | Top-right corner radius |
| `bottomLeadingRadius` | `number` | Bottom-left corner radius |
| `bottomTrailingRadius` | `number` | Bottom-right corner radius |

Radii are derived from Flutter `BorderRadius` in `NativeGlassCard`. Examples:

- **Nav capsule:** uniform `24`
- **Top bar:** bottom-only `20` (`BorderRadius.vertical(bottom: Radius.circular(20))`)

### Chrome-only mode

When both `title` and `subtitle` are empty strings, SwiftUI renders a clear fill with glass applied to the full bounds — used for bars that keep their labels/icons in Flutter.

## iOS registration

Registration happens when the implicit Flutter engine initializes (not only in `didFinishLaunching`):

```swift
func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
  GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

  let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SwiftUIGlassPlugin")!
  let factory = SwiftUIGlassFactory(messenger: registrar.messenger())
  registrar.register(factory, withId: "com.example.native_liquid_glass")
}
```

- **Plugin key:** `SwiftUIGlassPlugin`
- **View type id:** `com.example.native_liquid_glass` (must match Dart `_viewType`)

New Swift sources must be listed in `ios/Runner.xcodeproj/project.pbxproj` under the Runner target’s Compile Sources.

## Transparency requirements

For materials to sample Flutter content underneath the platform view:

1. `UIHostingController.view.backgroundColor = .clear`
2. `hostingController.view.isOpaque = false`
3. Prefer ignoring safe-area insets on the hosted view so bars size to the Flutter frame

Without a clear hosting background, the glass samples an opaque UIKit backdrop and looks solid.

## Materials & system settings

| OS | Effect | Notes |
|----|--------|--------|
| iOS 26+ | `.glassEffect(.clear, in: shape)` | Highest transparency Liquid Glass; respects Reduce Transparency, tinted glass, Increase Contrast |
| iOS 15–25 | `.background(.ultraThinMaterial, in: shape)` | Thinnest classic material; still respects Reduce Transparency |

Do **not** hard-code opacity overrides that fight accessibility settings. Prefer system glass APIs and let Settings drive frosting.

Minimum deployment target is **iOS 15.0** (required for `.ultraThinMaterial`).

## Dart usage patterns

### Reusable card

```dart
NativeGlassCard(
  title: 'Nearby',
  subtitle: 'Posts within 2 km',
  height: 130,
)
```

### Top bar (all screens using `TopBarBackdrop`)

```dart
TopBarBackdrop(
  blurTintColor: colorScheme.surface, // retained for API compat; unused
  blendColor: colorScheme.surface,
  borderRadius: const BorderRadius.vertical(
    bottom: Radius.circular(20),
  ),
)
```

Internally the glass is bled ~48px above the bar so the parent clips away the top rim, then a black gradient (90% → 30% opacity, top → bottom) is stacked on the visible glass:

```dart
// Glass: Positioned(top: -48, …) + flat top radii
// Overlay: Colors.black @ 0.90 → 0.30
NativeGlassCard(
  title: '',
  subtitle: '',
  height: null,
  borderRadius: /* bottom-only */,
)
```

### Bottom navigation (`AppShell`)

```dart
Stack(
  fit: StackFit.expand,
  children: [
    NativeGlassCard(
      title: '',
      subtitle: '',
      height: navBarHeight,
    ),
    // Flutter nav icons / labels / create button
  ],
)
```

## Non-iOS fallback

On Android, Web, and desktop, `NativeGlassCard` does **not** call `UiKitView`. It uses:

- `BackdropFilter` with blur
- Low-alpha surface tint (~12%)
- Matching corner radii and a light border

That keeps the tree compiling and visually similar without native glass.

## Hit testing & stacking

```
Stack
 ├── NativeGlassCard / UiKitView   ← visual only (glass)
 └── Flutter Row / title / actions ← receives gestures
```

Keep interactive widgets **above** the platform view. Do not rely on the SwiftUI tree for buttons unless you also implement method channels for events.

## Adding a new hybrid surface

1. Prefer reusing `NativeGlassCard` (or `TopBarBackdrop` for app bars).
2. If you need new props, add keys to `_creationParams`, parse them in `GlassPlatformView`, and thread them into `SwiftUIGlassView`.
3. Keep the Dart API platform-agnostic: iOS uses native glass; everyone else gets the fallback.
4. Rebuild the iOS app after Swift changes (`flutter run` / Xcode). Hot reload does **not** pick up native registration or SwiftUI edits.

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| Solid gray / no blur | Hosting view not clear, or Flutter layer behind is opaque |
| Crash: unknown view type | Factory not registered, or view id mismatch |
| Glass wrong shape | Corner radius params not passed / clipped by parent |
| No update after Swift edit | Need full rebuild; hot reload insufficient |
| Works on iOS, blank on Android | Expected if you used `UiKitView` without the Dart fallback path |

## Related docs

- [Architecture](./architecture.md) — app layers
- [Screens & Navigation](./screens.md) — where top bars and shell appear
- [Flutter Guide](./flutter_guide.md) — Flutter basics
