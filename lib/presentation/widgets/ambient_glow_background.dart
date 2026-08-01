import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Deep midnight base for dark mode ambient glow.
const Color _kMidnightBase = Color(0xFF0A0F1C);

/// Soft slate base for light mode.
const Color _kLightSlateBase = Color(0xFFF0F2FA);

/// Premium animated ambient background — drifting radial light sources.
///
/// Layer order (bottom → top):
/// 1. Solid slate / midnight base
/// 2. Purple-indigo glow (slow Lissajous path)
/// 3. Teal-blue glow (independent async path)
/// 4. Optional [child] wrapped in [SafeArea]
///
/// Use without [child] when the UI lives in a sibling [Stack] layer (e.g. [AppShell]).
class AmbientGlowBackground extends StatefulWidget {
  const AmbientGlowBackground({super.key, this.child});

  final Widget? child;

  @override
  State<AmbientGlowBackground> createState() => _AmbientGlowBackgroundState();
}

class _AmbientGlowBackgroundState extends State<AmbientGlowBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 56),
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_driftController.isAnimating) _driftController.repeat();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _driftController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return AnimatedBuilder(
            animation: _driftController,
            builder: (context, _) {
              final t = _driftController.value * math.pi * 2;
              final purple = _purpleOrbLayout(width, height, t);
              final teal = _tealOrbLayout(width, height, t);

              return Stack(
                clipBehavior: Clip.hardEdge,
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: isDark ? _kMidnightBase : _kLightSlateBase,
                  ),
                  RepaintBoundary(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: purple.left,
                          top: purple.top,
                          child: _GlowOrb(
                            size: purple.size,
                            gradient: _purpleGradient(isDark, t),
                          ),
                        ),
                        Positioned(
                          left: teal.left,
                          top: teal.top,
                          child: _GlowOrb(
                            size: teal.size,
                            gradient: _tealGradient(isDark, t),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.child != null) SafeArea(child: widget.child!),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Large purple orb — drifts from the upper-left quadrant.
  _OrbLayout _purpleOrbLayout(double width, double height, double t) {
    final size = width * (1.12 + 0.04 * math.sin(t * 0.11));

    final baseLeft = -width * 0.30;
    final baseTop = -height * 0.24;

    // Incommensurate frequencies → fluid, non-rigid motion within each cycle.
    final dx =
        math.sin(t * 0.31) * width * 0.11 +
        math.cos(t * 0.17 + 0.6) * width * 0.07 +
        math.sin(t * 0.09 + 1.1) * width * 0.04;
    final dy =
        math.cos(t * 0.23 + 0.4) * height * 0.09 +
        math.sin(t * 0.13) * height * 0.06 +
        math.cos(t * 0.07 + 2.0) * height * 0.03;

    return _OrbLayout(
      left: baseLeft + dx,
      top: baseTop + dy,
      size: size,
    );
  }

  /// Teal orb — independent path through the middle / right side.
  _OrbLayout _tealOrbLayout(double width, double height, double t) {
    final size = width * (0.92 + 0.03 * math.cos(t * 0.14 + 0.8));

    final baseLeft = width * 0.38;
    final baseTop = height * 0.12;

    final dx =
        math.cos(t * 0.19 + 1.2) * width * 0.13 +
        math.sin(t * 0.27 + 0.3) * width * 0.08 +
        math.cos(t * 0.11 + 2.4) * width * 0.05;
    final dy =
        math.sin(t * 0.21 + 0.9) * height * 0.11 +
        math.cos(t * 0.15 + 1.7) * height * 0.07 +
        math.sin(t * 0.08) * height * 0.04;

    return _OrbLayout(
      left: baseLeft + dx,
      top: baseTop + dy,
      size: size,
    );
  }

  RadialGradient _purpleGradient(bool isDark, double t) {
    final breathe = 1 + 0.06 * math.sin(t * 0.25);
    final centerAlpha = (isDark ? 0.20 : 0.10) * breathe;
    final midAlpha = (isDark ? 0.05 : 0.03) * breathe;

    return RadialGradient(
      center: Alignment.center,
      radius: 0.72,
      colors: [
        const Color(0xFF9333EA).withValues(alpha: centerAlpha.clamp(0.0, 0.24)),
        const Color(0xFF312E81).withValues(alpha: midAlpha.clamp(0.0, 0.08)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.48, 1.0],
    );
  }

  RadialGradient _tealGradient(bool isDark, double t) {
    final breathe = 1 + 0.05 * math.cos(t * 0.22 + 0.5);
    final centerAlpha = (isDark ? 0.15 : 0.08) * breathe;
    final midAlpha = centerAlpha * 0.45;

    return RadialGradient(
      center: Alignment.center,
      radius: 0.68,
      colors: [
        const Color(0xFF14B8A6).withValues(alpha: centerAlpha.clamp(0.0, 0.18)),
        const Color(0xFF2563EB).withValues(alpha: midAlpha.clamp(0.0, 0.10)),
        Colors.transparent,
      ],
      stops: const [0.0, 0.42, 1.0],
    );
  }
}

class _OrbLayout {
  const _OrbLayout({
    required this.left,
    required this.top,
    required this.size,
  });

  final double left;
  final double top;
  final double size;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.gradient,
  });

  final double size;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
          ),
        ),
      ),
    );
  }
}
