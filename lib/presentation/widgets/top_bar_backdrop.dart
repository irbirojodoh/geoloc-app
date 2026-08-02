import 'package:flutter/material.dart';

import 'native_glass_card.dart';

/// Shared top-bar visual treatment using the same liquid glass as the nav capsule.
///
/// On iOS this is native Liquid Glass / ultra-thin material; elsewhere it falls
/// back to a translucent [BackdropFilter] via [NativeGlassCard].
///
/// The glass is bled above the top of the bar so the glass rim/stroke is clipped
/// off-screen. A black gradient (90% → 30% opacity) tints the visible glass.
///
/// Tint/blend parameters are retained for call-site compatibility but are no
/// longer applied — glass follows system transparency settings instead.
class TopBarBackdrop extends StatelessWidget {
  const TopBarBackdrop({
    super.key,
    required this.blurTintColor,
    required this.blendColor,
    this.borderRadius = BorderRadius.zero,
    this.blurSigma = 8,
    this.blurTintOpacity = 0.86,
    this.blendOpacity = 0.04,
    this.blendMode = BlendMode.multiply,
    this.enableBlur = false,
  });

  /// Unused; kept for existing call sites.
  final Color blurTintColor;

  /// Unused; kept for existing call sites.
  final Color blendColor;

  final BorderRadius borderRadius;

  /// Unused; kept for existing call sites.
  final double blurSigma;

  /// Unused; kept for existing call sites.
  final double blurTintOpacity;

  /// Unused; kept for existing call sites.
  final double blendOpacity;

  /// Unused; kept for existing call sites.
  final BlendMode blendMode;

  /// Unused; kept for existing call sites.
  final bool enableBlur;

  /// Extra height above the bar so the glass top edge is clipped off-screen.
  static const double _topBleed = 48;

  @override
  Widget build(BuildContext context) {
    // Keep bottom rounding from callers; force a flat top so no lip shows.
    final effectiveRadius = BorderRadius.only(
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Bleed above bounds; parent AppBar/Stack clips so the glass rim
        // never appears at the top of the screen.
        Positioned(
          top: -_topBleed,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: effectiveRadius,
            child: NativeGlassCard(
              title: '',
              subtitle: '',
              height: null,
              borderRadius: effectiveRadius,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: effectiveRadius,
                backgroundBlendMode: BlendMode.multiply,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
