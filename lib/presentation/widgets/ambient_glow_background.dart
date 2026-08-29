import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Animated ambient backdrop — a top-down water surface. Crossing families of
/// ripples weave a caustic net of light over the app's own surface color, the
/// way sunlight pools on the bottom of a pool.
///
/// Each ripple crest is warped by a slow spatial field, so the straight wave
/// fronts bend into an organic, interlocking mesh. Brightness along a crest is
/// deliberately patchy, so most of the screen keeps reading as the plain app
/// background instead of a full-screen wash.
///
/// Dark mode composites with [BlendMode.screen] (crests read as light on the
/// water); light mode uses [BlendMode.multiply] with pastel tints (crests read
/// as colored ripples rather than grey haze).
///
/// Every oscillator uses an **integer** multiple of the controller phase and
/// crest travel is padded past the canvas edge, so the loop is seamless — no
/// snap or pop when the controller wraps.
///
/// Use without [child] when the UI lives in a sibling [Stack] layer (e.g.
/// [AppShell]).
class AmbientGlowBackground extends StatefulWidget {
  const AmbientGlowBackground({super.key, this.child, this.seed});

  final Widget? child;

  /// Fixes the random layout — supply in tests/goldens for a stable frame.
  final int? seed;

  /// One full pass of the slowest oscillator.
  static const period = Duration(seconds: 90);

  @override
  State<AmbientGlowBackground> createState() => _AmbientGlowBackgroundState();
}

class _AmbientGlowBackgroundState extends State<AmbientGlowBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  late final List<_Ripples> _families;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _families = _buildFamilies(math.Random(widget.seed));
    _drift = AnimationController(
      vsync: this,
      duration: AmbientGlowBackground.period,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  /// Animate only while foregrounded and motion is allowed.
  void _syncTicker() {
    if (!mounted) return;
    final allowed = _appActive && !MediaQuery.disableAnimationsOf(context);
    if (allowed && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!allowed && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AmbientPainter(
                    phase: _drift.value * 2 * math.pi,
                    isDark: isDark,
                    base: colorScheme.surface,
                    families: _families,
                  ),
                  isComplex: true,
                  willChange: _drift.isAnimating,
                );
              },
            ),
          ),
          if (widget.child != null) SafeArea(child: widget.child!),
        ],
      ),
    );
  }
}

/// One family of parallel ripples travelling in a single direction. Two or
/// three of these crossing each other is what produces the caustic mesh.
class _Ripples {
  const _Ripples({
    required this.dark,
    required this.light,
    required this.angle,
    required this.wavelength,
    required this.speed,
    required this.warp,
    required this.warpCounts,
    required this.harmonics,
    required this.phase,
    required this.darkAlpha,
    required this.lightAlpha,
  });

  /// Emissive hue for dark mode (screen blend).
  final Color dark;

  /// Pastel tint for light mode (multiply blend).
  final Color light;

  /// Direction the crests travel, in radians.
  final double angle;

  /// Crest spacing as a fraction of the shortest side.
  final double wavelength;

  /// Wavelengths travelled per loop — integer keeps the loop seamless.
  final int speed;

  /// How far crests bend, as a fraction of [wavelength].
  final double warp;

  /// Spatial frequency of the warp field, in cycles across the canvas.
  final (int, int) warpCounts;

  /// Integer oscillator speeds — keeps the loop seamless.
  final (int, int) harmonics;

  final double phase;
  final double darkAlpha;
  final double lightAlpha;
}

/// Cool indigo → teal core with a warm gold accent that ties into the brand.
const _palette = <(Color, Color)>[
  (Color(0xFF7C4DFF), Color(0xFFCBB8FF)),
  (Color(0xFF06B6D4), Color(0xFF9FE3F2)),
  (Color(0xFF2563EB), Color(0xFFB6D2FF)),
  (Color(0xFFC9A84C), Color(0xFFFFE0A8)),
  (Color(0xFFDB2777), Color(0xFFFFC2D8)),
];

const _harmonics = <(int, int)>[(1, 2), (1, 3), (2, 3), (2, 5), (3, 5), (1, 5)];

/// Segments used to trace each crest — enough for a smooth curve on phones.
const _segments = 36;

/// Sample points of the brightness envelope along a crest.
const _envelopeStops = <double>[0.0, 0.25, 0.5, 0.75, 1.0];

List<_Ripples> _buildFamilies(math.Random random) {
  double between(double min, double max) =>
      min + random.nextDouble() * (max - min);

  final hues = [..._palette]..shuffle(random);
  final count = 2 + random.nextInt(2);
  // Spread the families apart in angle so they genuinely cross instead of
  // running nearly parallel.
  final lead = random.nextDouble() * math.pi;

  return List<_Ripples>.generate(count, (i) {
    final (dark, light) = hues[i % hues.length];

    return _Ripples(
      dark: dark,
      light: light,
      angle: lead + i * (math.pi / count) + between(-0.20, 0.20),
      wavelength: between(0.26, 0.42),
      speed: 1 + random.nextInt(2),
      warp: between(0.30, 0.60),
      warpCounts: (1 + random.nextInt(2), 2 + random.nextInt(2)),
      harmonics: _harmonics[random.nextInt(_harmonics.length)],
      phase: random.nextDouble() * 2 * math.pi,
      darkAlpha: between(0.26, 0.38),
      lightAlpha: between(0.18, 0.28),
    );
  });
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter({
    required this.phase,
    required this.isDark,
    required this.base,
    required this.families,
  });

  final double phase;
  final bool isDark;
  final Color base;
  final List<_Ripples> families;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final blend = isDark ? BlendMode.screen : BlendMode.multiply;
    final center = size.center(Offset.zero);

    for (final family in families) {
      final wavelength = size.shortestSide * family.wavelength;
      final travel = family.direction;
      final along = Offset(-travel.dy, travel.dx);

      // Half-extent of the canvas measured along the travel direction, so the
      // crest indices always cover the whole surface.
      final depth =
          (size.width * travel.dx).abs() / 2 +
          (size.height * travel.dy).abs() / 2;
      // Pad past the edge by the full distance travelled in one loop, so no
      // crest pops into view when the controller wraps.
      final crests = (depth / wavelength).ceil() + family.speed + 1;
      final shift = family.speed * wavelength * phase / (2 * math.pi);
      final reach = size.longestSide;

      final color = isDark ? family.dark : family.light;
      final peak = isDark ? family.darkAlpha : family.lightAlpha;

      for (var n = -crests; n <= crests; n++) {
        final offset = n * wavelength + shift;
        final crest = _crest(
          family,
          anchor: center + travel * offset,
          along: along,
          reach: reach,
          wavelength: wavelength,
        );
        final envelope = _envelope(family, n);

        final start = crest.first;
        final end = crest.last;

        // Wide soft pass reads as the glow under the surface, the hairline on
        // top as the lit crest itself.
        canvas.drawPath(
          crest.path,
          Paint()
            ..blendMode = blend
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = wavelength * 0.34
            ..shader = _shader(start, end, color, envelope, peak * 0.42),
        );
        canvas.drawPath(
          crest.path,
          Paint()
            ..blendMode = blend
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 1.4
            ..shader = _shader(start, end, color, envelope, peak),
        );
      }
    }
  }

  /// Traces one crest across the canvas, bending it with the warp field so the
  /// wave fronts interlock instead of staying ruler-straight.
  _Crest _crest(
    _Ripples family, {
    required Offset anchor,
    required Offset along,
    required double reach,
    required double wavelength,
  }) {
    final (fast, slow) = family.harmonics;
    final (nearCount, farCount) = family.warpCounts;
    final travel = family.direction;
    final amplitude = wavelength * family.warp;
    final path = Path();
    late Offset first;
    late Offset last;

    for (var i = 0; i <= _segments; i++) {
      final t = (i / _segments - 0.5) * 2 * reach;
      final straight = anchor + along * t;
      // Two counter-travelling components, so the bend reshapes over time
      // rather than sliding along rigidly.
      final bend =
          math.sin(nearCount * t / reach * math.pi + fast * phase + family.phase) *
              0.62 +
          math.sin(
                farCount * t / reach * math.pi -
                    slow * phase +
                    family.phase * 1.9,
              ) *
              0.38;
      final point = straight + travel * (amplitude * bend);

      if (i == 0) {
        first = point;
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      last = point;
    }

    return _Crest(path: path, first: first, last: last);
  }

  /// Brightness along a crest. Biased dark so light gathers in a few bright
  /// patches and the surface color shows through everywhere else.
  List<double> _envelope(_Ripples family, int n) {
    final (fast, slow) = family.harmonics;

    return List<double>.generate(_envelopeStops.length, (i) {
      final a =
          math.sin(family.phase + n * 0.8 + i * 1.9 + slow * phase) * 0.5 + 0.5;
      final b =
          math.sin(family.phase * 1.7 + n * 1.6 + i * 1.1 - fast * phase) *
              0.5 +
          0.5;
      return math.pow(a * 0.65 + b * 0.35, 1.9).toDouble();
    });
  }

  ui.Shader _shader(
    Offset from,
    Offset to,
    Color color,
    List<double> envelope,
    double scale,
  ) {
    return ui.Gradient.linear(
      from,
      to,
      [
        for (final level in envelope)
          color.withValues(alpha: (level * scale).clamp(0.0, 1.0)),
      ],
      _envelopeStops,
    );
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.isDark != isDark ||
      oldDelegate.base != base ||
      !identical(oldDelegate.families, families);
}

/// A traced crest plus its endpoints, which the brightness gradient spans.
class _Crest {
  const _Crest({required this.path, required this.first, required this.last});

  final Path path;
  final Offset first;
  final Offset last;
}

extension on _Ripples {
  /// Unit vector the crests travel along.
  Offset get direction => Offset(math.cos(angle), math.sin(angle));
}
