import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'animated_scroll_gradient_background.dart';

const _navVisibilityQueryKey = 'fromNav';

/// Persistent shell with capsule-shaped bottom navigation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(notificationStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        final notification = next.value!;
        ref.read(notificationsProvider.notifier).addNotification(notification);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.message),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.go(RoutePaths.notifications),
            ),
          ),
        );
      }
    });

    final user = ref.watch(currentUserProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final selectedIndex = _calculateSelectedIndex(context);
    final routerState = GoRouterState.of(context);
    final location = routerState.uri.path;
    final isNavTriggered =
        routerState.uri.queryParameters[_navVisibilityQueryKey] == '1';
    final isProfileDetailRoute = location.startsWith('/profile/') &&
        !location.startsWith(RoutePaths.editProfile);
    final isMainNavRoute = location.startsWith(RoutePaths.feed) ||
        location.startsWith(RoutePaths.search) ||
        location.startsWith(RoutePaths.notifications) ||
        isProfileDetailRoute;
    final isHomeRoute = location.startsWith(RoutePaths.feed);
    final showNavigationBar = isHomeRoute || (isMainNavRoute && isNavTriggered);
    final showCreateButton = showNavigationBar && location.startsWith(RoutePaths.feed);
    final colorScheme = Theme.of(context).colorScheme;

    final activeColor = colorScheme.primary;
    final selectedContentColor = colorScheme.onPrimary;
    final capsuleColor = colorScheme.surfaceContainerHighest;
    final inactiveColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final overlayBaseColor =
        Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.black;
    const navBarHeight = 75.0;
    const navBottomMargin = 10.0;
    final bottomSafeInset = MediaQuery.paddingOf(context).bottom;
    final bottomGradientHeight = navBarHeight + navBottomMargin + bottomSafeInset;
    const navLabels = <String>['Home', 'Search', 'Notifications', 'Profile'];
    const navIcons = <IconData>[
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.notifications_rounded,
      Icons.person_rounded,
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AnimatedScrollGradientBackground(opacity: 0.18),
          ),
          child,
          if (showNavigationBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomGradientHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        overlayBaseColor.withValues(alpha: 0.8),
                        overlayBaseColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation);
          return ClipRect(
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            ),
          );
        },
        child: showNavigationBar
            ? SafeArea(
                key: const ValueKey('nav-visible'),
                top: false,
                child: Padding(
                  // Generous horizontal margin + comfortable bottom breathing room
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, navBottomMargin),
                  child: Material(
                    elevation: 20,
                    shadowColor: colorScheme.scrim.withValues(alpha: 0.28),
                    color: capsuleColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      // Taller bar: more breathing room top/bottom
                      height: navBarHeight,
                      child: Padding(
                        // Inner horizontal padding so edge items aren't flush
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                    // Guard: if LayoutBuilder hands us zero/negative width
                    // (can happen during first frame or in nested scrollables),
                    // render nothing to avoid assertion errors.
                    final totalWidth = constraints.maxWidth;
                    if (totalWidth <= 0) return const SizedBox.shrink();
                    // Dynamic slot count:
                    // - Home route: 4 tabs + create action
                    // - Other routes: 4 tabs only
                    final navTrackWidth = totalWidth;
                    final slotCount = showCreateButton ? 5 : 4;
                    final createSlotWidth = showCreateButton ? 44.0 : 0.0;

                    // Selected slot = 38 %, unselected slots share the rest.
                    // Use max(0, …) on unselectedWidth so it never goes negative
                    // even if the spring overshoots and temporarily reports a
                    // larger selectedWidth during an in-progress animation.
                    final selectedWidth = (navTrackWidth * 0.38).clamp(0.0, navTrackWidth);
                    final remaining = (navTrackWidth - selectedWidth).clamp(0.0, navTrackWidth);
                    final unselectedWidth = remaining / (slotCount - 1);

                    double widthFor(int i) =>
                        selectedIndex == i ? selectedWidth : unselectedWidth;

                    final widths = List<double>.generate(4, widthFor);
                    final selectedLeft = widths
                        .take(selectedIndex)
                        .fold<double>(0.0, (s, w) => s + w);

                    final labelStyle = TextStyle(
                      color: selectedContentColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.1,
                    );

                    final selectedLabelWidth = _measureTextWidth(
                      navLabels[selectedIndex],
                      labelStyle,
                      Directionality.of(context),
                    );

                    final hasSelectedBadge =
                        selectedIndex == 2 && unreadCount > 0;

                    // Pill width: icon(22) + gap(7) + label + badge(10) + h-padding(24)
                    final desiredHighlightWidth =
                        24.0 + 22.0 + 7.0 + selectedLabelWidth +
                        (hasSelectedBadge ? 10.0 : 0.0);

                    final selectedSlotWidth = widths[selectedIndex];
                    // Ensure the clamp range is always valid (min <= max).
                    final clampMax = (selectedSlotWidth - 8.0).clamp(48.0, double.infinity);
                    final highlightWidth =
                        desiredHighlightWidth.clamp(48.0, clampMax);

                    final highlightLeft = (selectedLeft +
                            (selectedSlotWidth - highlightWidth) / 2)
                        .clamp(0.0, (totalWidth - highlightWidth).clamp(0.0, double.infinity));

                    return Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Animated highlight pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 1500),
                          curve: const _SpringCurve(),
                          left: highlightLeft,
                          // Vertically centred in 75 px bar: (75 - 46) / 2 = 14.5
                          top: 14.5,
                          width: highlightWidth,
                          height: 46,
                          child: _GlowPill(color: activeColor),
                        ),

                        // Nav items row with inline center create button.
                        Row(
                          children: [
                            _FixedNavSlot(
                              width: widthFor(0),
                              child: _CapsuleNavItem(
                                isSelected: selectedIndex == 0,
                                label: navLabels[0],
                                icon: navIcons[0],
                                selectedColor: selectedContentColor,
                                inactiveColor: inactiveColor,
                                badgeBackgroundColor: colorScheme.error,
                                badgeCount: 0,
                                onTap: () => _onItemTapped(0, context, user?.id),
                              ),
                            ),
                            _FixedNavSlot(
                              width: widthFor(1),
                              child: _CapsuleNavItem(
                                isSelected: selectedIndex == 1,
                                label: navLabels[1],
                                icon: navIcons[1],
                                selectedColor: selectedContentColor,
                                inactiveColor: inactiveColor,
                                badgeBackgroundColor: colorScheme.error,
                                badgeCount: 0,
                                onTap: () => _onItemTapped(1, context, user?.id),
                              ),
                            ),
                            _FixedNavSlot(
                              width: widthFor(2),
                              child: _CapsuleNavItem(
                                isSelected: selectedIndex == 2,
                                label: navLabels[2],
                                icon: navIcons[2],
                                selectedColor: selectedContentColor,
                                inactiveColor: inactiveColor,
                                badgeBackgroundColor: colorScheme.error,
                                badgeCount: unreadCount,
                                onTap: () => _onItemTapped(2, context, user?.id),
                              ),
                            ),
                            _FixedNavSlot(
                              width: widthFor(3),
                              child: _CapsuleNavItem(
                                isSelected: selectedIndex == 3,
                                label: navLabels[3],
                                icon: navIcons[3],
                                selectedColor: selectedContentColor,
                                inactiveColor: inactiveColor,
                                badgeBackgroundColor: colorScheme.error,
                                badgeCount: 0,
                                onTap: () => _onItemTapped(3, context, user?.id),
                              ),
                            ),
                            _FixedNavSlot(
                              width: createSlotWidth,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: animation,
                                        child: child,
                                      ),
                                    ),
                                child: showCreateButton
                                    ? _CreateNavItem(
                                        key: const ValueKey('create-visible'),
                                        onTap: () => context.push(RoutePaths.createPost),
                                        backgroundColor: activeColor,
                                        iconColor: selectedContentColor,
                                      )
                                    : const SizedBox(
                                        key: ValueKey('create-hidden'),
                                        width: 1,
                                        height: 1,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                        },
                      ),
                    ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(key: ValueKey('nav-hidden')),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(RoutePaths.feed)) return 0;
    if (location.startsWith(RoutePaths.search)) return 1;
    if (location.startsWith(RoutePaths.notifications)) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, String? userId) {
    switch (index) {
      case 0:
        context.go('${RoutePaths.feed}?$_navVisibilityQueryKey=1');
        break;
      case 1:
        context.go('${RoutePaths.search}?$_navVisibilityQueryKey=1');
        break;
      case 2:
        context.go('${RoutePaths.notifications}?$_navVisibilityQueryKey=1');
        break;
      case 3:
        if (userId != null && userId.isNotEmpty) {
          context.go('/profile/$userId?$_navVisibilityQueryKey=1');
        } else {
          context.go('${RoutePaths.feed}?$_navVisibilityQueryKey=1');
        }
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Glow pill — the animated highlight behind the selected item
// ---------------------------------------------------------------------------

class _GlowPill extends StatelessWidget {
  const _GlowPill({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual nav item
// ---------------------------------------------------------------------------

class _CapsuleNavItem extends StatefulWidget {
  const _CapsuleNavItem({
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.selectedColor,
    required this.inactiveColor,
    required this.badgeBackgroundColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final bool isSelected;
  final String label;
  final IconData icon;
  final Color selectedColor;
  final Color inactiveColor;
  final Color badgeBackgroundColor;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<_CapsuleNavItem> createState() => _CapsuleNavItemState();
}

class _CapsuleNavItemState extends State<_CapsuleNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // Subtle press-down then return to original size.
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.5)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _bounceController.forward(from: 0);
    widget.onTap();
  }

@override
Widget build(BuildContext context) {
  final iconColor = widget.isSelected ? widget.selectedColor : widget.inactiveColor;

  final iconWidget = AnimatedSwitcher(
    duration: const Duration(milliseconds: 400),
    transitionBuilder: (child, anim) =>
        FadeTransition(opacity: anim, child: child),
    child: Icon(
      widget.icon,
      key: ValueKey(widget.isSelected),
      size: 22,
      color: iconColor,
    ),
  );

  return GestureDetector(
    onTap: _handleTap,
    behavior: HitTestBehavior.opaque,
    child: ScaleTransition(
      scale: _scaleAnim,
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge wraps the icon when count > 0
              if (widget.badgeCount > 0)
                Badge(
                  isLabelVisible: true,
                  backgroundColor: widget.badgeBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  label: Text(
                    widget.badgeCount > 99
                        ? '99+'
                        : widget.badgeCount.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: iconWidget,
                )
              else
                iconWidget,

              // Label - use Flexible to prevent overflow
              if (widget.isSelected)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7),
                    child: _SlideFadeLabel(
                      label: widget.label,
                      color: widget.selectedColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

// ---------------------------------------------------------------------------
// Label that slides in from the right + fades in when item is selected
// ---------------------------------------------------------------------------

class _SlideFadeLabel extends StatefulWidget {
  const _SlideFadeLabel({
    required this.label,
    required this.color,
  });
  final String label;
  final Color color;

  @override
  State<_SlideFadeLabel> createState() => _SlideFadeLabelState();
}

class _SlideFadeLabelState extends State<_SlideFadeLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.30, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Text(
          widget.label,
          style: TextStyle(
            color: widget.color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slot uses Expanded+flex so widths always sum to exactly the Row's width.
// Fixed pixel widths caused overflow when the spring curve temporarily
// reported values that didn't sum correctly during animation frames.
// ---------------------------------------------------------------------------

class _FixedNavSlot extends StatelessWidget {
  const _FixedNavSlot({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      width: width,
      child: child,
    );
  }
}

class _CreateNavItem extends StatelessWidget {
  const _CreateNavItem({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Padding(
          // Match nav item vertical spacing so + sits like other icons.
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 22,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom spring curve: overshoots slightly then settles (feels physical)
// ---------------------------------------------------------------------------

class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    const damping = 16.0;
    const frequency = 5.2;
    return 1 - (math.exp(-damping * t) * math.cos(frequency * math.pi * t));
  }
}

// ---------------------------------------------------------------------------
// Text measurement helper
// ---------------------------------------------------------------------------

double _measureTextWidth(
  String text,
  TextStyle style,
  TextDirection textDirection,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: textDirection,
  )..layout();
  return painter.width;
}