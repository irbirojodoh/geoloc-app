import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared top-bar visual treatment:
/// - background blur over scrolling content
/// - multiply tint to blend with content behind
class TopBarBackdrop extends StatelessWidget {
  const TopBarBackdrop({
    super.key,
    required this.blurTintColor,
    required this.blendColor,
    this.borderRadius = BorderRadius.zero,
    this.blurSigma = 16,
    this.blurTintOpacity = 0.70,
    this.blendOpacity = 0.20,
    this.blendMode = BlendMode.multiply,
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: blur + soft tint
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: blurTintColor.withValues(alpha: blurTintOpacity),
              ),
            ),
          ),

          // Layer 2: separate blend layer (multiply by default)
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

