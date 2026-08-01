import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared top-bar visual treatment.
///
/// On mobile, uses a semi-opaque tint by default (cheap). Soft blur is opt-in
/// via [enableBlur] for platforms/devices that can afford it.
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

  /// Color tint applied on top of the blur layer.
  final Color blurTintColor;

  /// Color of the separate blend layer.
  final Color blendColor;

  final BorderRadius borderRadius;

  /// Gaussian blur strength for the blur layer.
  final double blurSigma;

  /// Opacity of the blur tint layer.
  final double blurTintOpacity;

  /// Opacity of the blend layer.
  final double blendOpacity;

  /// Blend mode of the blend layer (default: multiply).
  final BlendMode blendMode;

  /// When true, applies [BackdropFilter] (expensive during scroll).
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final useBlur = enableBlur && !kIsWeb;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (useBlur)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: blurTintColor.withValues(alpha: blurTintOpacity * 0.55),
                ),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: blurTintColor.withValues(alpha: blurTintOpacity),
              ),
            ),
          CustomPaint(
            painter: _BlendLayerPainter(
              color: blendColor.withValues(alpha: blendOpacity),
              blendMode: blendMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlendLayerPainter extends CustomPainter {
  const _BlendLayerPainter({
    required this.color,
    required this.blendMode,
  });

  final Color color;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..blendMode = blendMode;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _BlendLayerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.blendMode != blendMode;
  }
}
