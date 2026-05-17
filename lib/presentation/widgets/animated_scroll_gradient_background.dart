import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated color-field background that reacts to scroll offset.
///
/// Uses mathematically-generated moving radial blobs for a fluid look.
class AnimatedScrollGradientBackground extends StatefulWidget {
  const AnimatedScrollGradientBackground({
    super.key,
    this.scrollController,
    this.opacity = 0.2,
  });

  final ScrollController? scrollController;
  final double opacity;

  @override
  State<AnimatedScrollGradientBackground> createState() =>
      _AnimatedScrollGradientBackgroundState();
}

class _AnimatedScrollGradientBackgroundState
    extends State<AnimatedScrollGradientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    final controller = widget.scrollController;
    if (controller != null) {
      controller.addListener(_handleScroll);
      _scrollOffset = controller.hasClients ? controller.position.pixels : 0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedScrollGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleScroll);
      widget.scrollController?.addListener(_handleScroll);
      _scrollOffset = widget.scrollController?.hasClients == true
          ? widget.scrollController!.position.pixels
          : 0;
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleScroll);
    _animationController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    if (!mounted) return;
    final nextOffset = controller.position.pixels;
    if ((nextOffset - _scrollOffset).abs() > 0.5) {
      setState(() => _scrollOffset = nextOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, _) {
            return CustomPaint(
              painter: _ScrollReactiveGradientPainter(
                colorScheme: colorScheme,
                t: _animationController.value,
                scrollOffset: _scrollOffset,
                opacity: widget.opacity,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _ScrollReactiveGradientPainter extends CustomPainter {
  const _ScrollReactiveGradientPainter({
    required this.colorScheme,
    required this.t,
    required this.scrollOffset,
    required this.opacity,
  });

  final ColorScheme colorScheme;
  final double t;
  final double scrollOffset;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final isLight = colorScheme.brightness == Brightness.light;

    // --- Background fill ---
    final basePaint = Paint()
      ..color = isLight
          ? const Color(0xFFF0EFFF) // warm off-white with a hint of lavender
          : const Color(0xFF0A0A14); // deep dark navy
    canvas.drawRect(Offset.zero & size, basePaint);

    // --- Rich, saturated palettes ---
    final palette = isLight
        ? <Color>[
            const Color(0xFF5B6FFF), // vivid blue
            const Color(0xFFD946EF), // fuchsia
            const Color(0xFF06C6F0), // electric cyan
            const Color(0xFFF97316), // orange
            const Color(0xFF8B5CF6), // violet
            const Color(0xFF10B981), // emerald
            const Color(0xFFEC4899), // hot pink
          ]
        : <Color>[
            const Color(0xFFFF2D78), // neon red-pink
            const Color(0xFF5B6FFF), // electric blue
            const Color(0xFF00E5FF), // laser cyan
            const Color(0xFFA855F7), // vivid purple
            const Color(0xFFFF7A00), // neon orange
            const Color(0xFF00FF94), // mint green
            const Color(0xFFFF4ECD), // hot magenta
          ];

    // Opacity multipliers — subtle tint, not overwhelming
    final centerOpacity = isLight ? opacity * 0.85 : opacity * 0.9;
    final midOpacity    = isLight ? opacity * 0.30 : opacity * 0.25;

    // --- 9 dynamic blobs with layered motion ---
    for (var i = 0; i < 9; i++) {
      final seed  = i * 17.173 + 0.91;

      // Primary rotation — each blob has a unique speed
      final speed1 = 0.4  + _rand(seed + 2.0) * 1.2;
      final phase1 = seed * 3.1;
      final theta1 = t * math.pi * 2 * speed1 + phase1;

      // Secondary counter-rotation — creates figure-8 / Lissajous paths
      final speed2 = 0.25 + _rand(seed + 3.5) * 0.9;
      final phase2 = seed * 1.7;
      final theta2 = t * math.pi * 2 * speed2 + phase2;

      // Pulsing scale over time
      final pulseSpeed = 0.6 + _rand(seed + 5.0) * 1.4;
      final pulsePhase = seed * 2.3;
      final pulse = 1.0 +
          0.28 * math.sin(t * math.pi * 2 * pulseSpeed + pulsePhase);

      // Base anchor — spread blobs evenly across the canvas
      final baseX = size.width  * (0.1 + _rand(seed + 4.0) * 0.8);
      final baseY = size.height * (0.1 + _rand(seed + 6.0) * 0.8);

      // Primary orbit amplitude
      final orbitX1 = size.width  * (0.14 + _rand(seed + 8.0)  * 0.28);
      final orbitY1 = size.height * (0.14 + _rand(seed + 10.0) * 0.26);

      // Secondary (smaller) orbit for the Lissajous wobble
      final orbitX2 = size.width  * (0.06 + _rand(seed + 9.0)  * 0.12);
      final orbitY2 = size.height * (0.06 + _rand(seed + 11.0) * 0.10);

      // Scroll parallax — different layers move at different rates
      final scrollDepth = 0.003 + i * 0.0008;
      final scrollX = scrollOffset * scrollDepth * math.cos(seed);
      final scrollY = scrollOffset * (scrollDepth + 0.004);

      final cx = baseX
          + math.cos(theta1) * orbitX1
          + math.sin(theta2 * 1.31) * orbitX2
          + scrollX;
      final cy = baseY
          + math.sin(theta1 * 0.88) * orbitY1
          + math.cos(theta2 * 0.97) * orbitY2
          + scrollY;

      // Larger base radius + pulse
      final radius =
          size.shortestSide * (0.38 + _rand(seed + 12.0) * 0.30) * pulse;

      final color = palette[i % palette.length];

      final paint = Paint()
        ..blendMode = isLight ? BlendMode.multiply : BlendMode.plus
        ..shader = RadialGradient(
          center: Alignment(
            (cx / size.width)  * 2 - 1,
            (cy / size.height) * 2 - 1,
          ),
          radius: radius / size.shortestSide,
          colors: [
            color.withValues(alpha: centerOpacity),
            color.withValues(alpha: midOpacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Offset.zero & size);

      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // --- Subtle vignette so content stays readable ---
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.88,
        colors: [
          Colors.transparent,
          isLight
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.35),
        ],
        stops: const [0.6, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  double _rand(double x) => _fract(math.sin(x * 12.9898) * 43758.5453);

  double _fract(double x) => x - x.floorToDouble();

  @override
  bool shouldRepaint(covariant _ScrollReactiveGradientPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.opacity != opacity ||
        oldDelegate.colorScheme != colorScheme;
  }
}