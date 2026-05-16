import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    final activeColor = colorScheme.primary;
    final selectedContentColor = colorScheme.onPrimary;
    final capsuleColor = colorScheme.surfaceContainerHighest;
    final inactiveColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    const navLabels = <String>['Home', 'Search', 'Alerts', 'Profile'];
    const navIcons = <IconData>[
      Icons.home_rounded,
      Icons.explore_rounded,
      Icons.notifications_rounded,
      Icons.person_rounded,
    ];

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          // Generous horizontal margin + comfortable bottom breathing room
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
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
              height: 75,
              child: Padding(
                // Inner horizontal padding so edge items aren't flush
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Guard: if LayoutBuilder hands us zero/negative width
                    // (can happen during first frame or in nested scrollables),
                    // render nothing to avoid assertion errors.
                    final totalWidth = constraints.maxWidth;
                    if (totalWidth <= 0) return const SizedBox.shrink();

                    // Selected slot = 38 %, unselected slots share the rest.
                    // Use max(0, …) on unselectedWidth so it never goes negative
                    // even if the spring overshoots and temporarily reports a
                    // larger selectedWidth during an in-progress animation.
                    final selectedWidth = (totalWidth * 0.38).clamp(0.0, totalWidth);
                    final remaining = (totalWidth - selectedWidth).clamp(0.0, totalWidth);
                    final unselectedWidth = remaining / 3;

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

                        // Nav items row — use Expanded + flex instead of fixed
                        // widths so the Row itself is never asked to overflow.
                        Row(
                          children: List.generate(4, (i) {
                            return _NavSlot(
                              // Flex-based slot: pass a flex value rather than
                              // an absolute pixel width to avoid overflow when
                              // the spring curve briefly overshoots.
                              flex: selectedIndex == i ? 38 : 20,
                              child: _CapsuleNavItem(
                                isSelected: selectedIndex == i,
                                label: navLabels[i],
                                icon: navIcons[i],
                                selectedColor: selectedContentColor,
                                inactiveColor: inactiveColor,
                                badgeBackgroundColor: colorScheme.error,
                                badgeCount: i == 2 ? unreadCount : 0,
                                onTap: () =>
                                    _onItemTapped(i, context, user?.id),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(RoutePaths.feed)) return 0;
    if (location.startsWith(RoutePaths.search)) return 1;
    if (location.startsWith(RoutePaths.notifications)) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, String? userId) {
    switch (index) {
      case 0:
        context.go(RoutePaths.feed);
        break;
      case 1:
        context.go(RoutePaths.search);
        break;
      case 2:
        context.go(RoutePaths.notifications);
        break;
      case 3:
        if (userId != null && userId.isNotEmpty) {
          context.go('/profile/$userId');
        } else {
          context.go(RoutePaths.feed);
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
      // Fade-only transition to avoid icon size vibration on tab change.
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
        // SizedBox.expand makes the tap target fill the entire Expanded slot,
        // and gives the inner Row a concrete max-width to respect.
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              // max — fills slot width; content is centred via mainAxisAlignment
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Badge wraps the icon when count > 0
                widget.badgeCount > 0
                    ? Badge(
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
                    : iconWidget,

                // Label slides in — clipped so it never pushes past slot edge
                AnimatedSize(
                  duration: const Duration(milliseconds: 400),
                  curve: const _SpringCurve(),
                  clipBehavior: Clip.hardEdge,
                  child: widget.isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 7),
                          child: _SlideFadeLabel(
                            label: widget.label,
                            color: widget.selectedColor,
                          ),
                        )
                      : const SizedBox.shrink(),
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

class _NavSlot extends StatelessWidget {
  const _NavSlot({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: child,
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