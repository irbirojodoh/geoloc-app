import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import 'animated_scroll_gradient_background.dart';

const _navVisibilityQueryKey = 'fromNav';
const _navDirectionQueryKey = 'navDir';

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
    final screenSize = MediaQuery.sizeOf(context);
    const createGlowCenterFromRight = 44.0;
    final createGlowCenterFromBottom =
        bottomSafeInset + navBottomMargin + (navBarHeight / 2);
    final createGlowCenterX = screenSize.width - createGlowCenterFromRight;
    final createGlowCenterY = screenSize.height - createGlowCenterFromBottom;
    final createGlowAlignment = Alignment(
      ((createGlowCenterX / screenSize.width) * 2) - 1,
      ((createGlowCenterY / screenSize.height) * 2) - 1,
    );
    final bottomGradientHeight = navBarHeight + navBottomMargin + bottomSafeInset;
    const navLabels = <String>['Home', 'Search', 'Notifications', 'Profile'];
    const navIcons = <IconData>[
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.notifications_rounded,
      Icons.person_rounded,
    ];
    final createButtonLayerLink = LayerLink();

    final scaffold = Scaffold(
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
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
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
                                onTap: () => _onItemTapped(
                                  0,
                                  currentIndex: selectedIndex,
                                  context: context,
                                  userId: user?.id,
                                ),
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
                                onTap: () => _onItemTapped(
                                  1,
                                  currentIndex: selectedIndex,
                                  context: context,
                                  userId: user?.id,
                                ),
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
                                onTap: () => _onItemTapped(
                                  2,
                                  currentIndex: selectedIndex,
                                  context: context,
                                  userId: user?.id,
                                ),
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
                                onTap: () => _onItemTapped(
                                  3,
                                  currentIndex: selectedIndex,
                                  context: context,
                                  userId: user?.id,
                                ),
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
                                        onTap: () {
                                          // Create post is treated as virtual index 5.
                                          setShellNavTransitionDirection(1);
                                          context.push(RoutePaths.createPost);
                                        },
                                        backgroundColor: activeColor,
                                        iconColor: selectedContentColor,
                                        layerLink: createButtonLayerLink,
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

    return Stack(
      children: [
        scaffold,
        if (showNavigationBar)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final scale = Tween<double>(
                    begin: 0.08,
                    end: 1,
                  ).animate(animation);
                  return ScaleTransition(
                    scale: scale,
                    alignment: createGlowAlignment,
                    child: child,
                  );
                },
                child: showCreateButton
                    ? _CreatePostAttentionGlow(
                        key: const ValueKey('create-glow-visible'),
                        color: activeColor,
                        layerLink: createButtonLayerLink,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('create-glow-hidden'),
                      ),
              ),
            ),
          ),
      ],
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

  void _onItemTapped(
    int index, {
    required int currentIndex,
    required BuildContext context,
    required String? userId,
  }) {
    // Directionality rule:
    // Home=0, Search=1, Notifications=2, Profile=3
    // target > current => incoming from right (outgoing left)
    // target < current => incoming from left (outgoing right)
    final direction = index > currentIndex
        ? 1
        : index < currentIndex
            ? -1
            : 0;
    setShellNavTransitionDirection(direction);
    final navQuery = '$_navVisibilityQueryKey=1&$_navDirectionQueryKey=$direction';
    switch (index) {
      case 0:
        context.go('${RoutePaths.feed}?$navQuery');
        break;
      case 1:
        context.go('${RoutePaths.search}?$navQuery');
        break;
      case 2:
        context.go('${RoutePaths.notifications}?$navQuery');
        break;
      case 3:
        if (userId != null && userId.isNotEmpty) {
          context.go('/profile/$userId?$navQuery');
        } else {
          context.go('${RoutePaths.feed}?$navQuery');
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
    return CustomPaint(
      painter: _GlowPillPainter(color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _GlowPillPainter extends CustomPainter {
  const _GlowPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);

    final glowNear = Paint()
      ..blendMode = BlendMode.screen
      ..color = color.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(rrect.shift(const Offset(0, 4)), glowNear);

    final glowFar = Paint()
      ..blendMode = BlendMode.screen
      ..color = color.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawRRect(rrect, glowFar);

    final fill = Paint()..color = color;
    canvas.drawRRect(rrect, fill);
  }

  @override
  bool shouldRepaint(covariant _GlowPillPainter oldDelegate) {
    return oldDelegate.color != color;
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

class _CreatePostAttentionGlow extends StatefulWidget {
  const _CreatePostAttentionGlow({
    super.key,
    required this.color,
    required this.layerLink,
  });

  final Color color;
  final LayerLink layerLink;

  @override
  State<_CreatePostAttentionGlow> createState() => _CreatePostAttentionGlowState();
}

class _CreatePostAttentionGlowState extends State<_CreatePostAttentionGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: widget.layerLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.center,
      followerAnchor: Alignment.center,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _sine01(_controller.value);
          return SizedBox(
            width: 520,
            height: 520,
            child: CustomPaint(
              painter: _CreatePostAttentionGlowPainter(
                color: widget.color,
                t: t,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreatePostAttentionGlowPainter extends CustomPainter {
  _CreatePostAttentionGlowPainter({
    required this.color,
    required this.t,
  });

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final radius = 100.0 + (t * 150.0);
    const maxAlpha = 0.4; // I0
    const mu = 3.8; // Attenuation coefficient for I(x)=I0*e^(-mu*x)

    const sampleCount = 16;
    final stops = <double>[];
    final colors = <Color>[];

    for (var i = 0; i < sampleCount; i++) {
      final stop = (i / (sampleCount - 1)) * 0.96;
      final x = stop; // normalized distance from center [0..1]
      final normalized = math.exp(-mu * x).clamp(0.0, 1.0);
      // Smoothly force the rim toward transparent to avoid a harsh edge ring.
      final edgeSoftening = math.pow((1 - x).clamp(0.0, 1.0), 1.6).toDouble();

      stops.add(stop);
      colors.add(
        color.withValues(alpha: maxAlpha * normalized * edgeSoftening),
      );
    }

    // Force edge to transparent so the glow cleanly terminates at radius.
    stops.add(1.0);
    colors.add(Colors.transparent);

    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CreatePostAttentionGlowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.t != t;
  }
}

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

class _CreateNavItem extends StatefulWidget {
  const _CreateNavItem({
    super.key,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    required this.layerLink,
  });

  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final LayerLink layerLink;

  @override
  State<_CreateNavItem> createState() => _CreateNavItemState();
}

class _CreateNavItemState extends State<_CreateNavItem> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Padding(
          // Match nav item vertical spacing so + sits like other icons.
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: CompositedTransformTarget(
              link: widget.layerLink,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.backgroundColor,
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: widget.iconColor,
                ),
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




double _sine01(double t) {
  return (math.sin((t * 2 * math.pi) - (math.pi / 2)) + 1) / 2;
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