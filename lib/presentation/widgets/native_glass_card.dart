import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native iOS liquid-glass card via platform view; Dart blur fallback elsewhere.
class NativeGlassCard extends StatelessWidget {
  const NativeGlassCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.height = 130.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final String title;
  final String subtitle;

  /// When null, expands to fill the parent instead of a fixed height.
  final double? height;
  final BorderRadius borderRadius;

  static const _viewType = 'com.example.native_liquid_glass';

  Map<String, dynamic> get _creationParams {
    final topLeft = borderRadius.topLeft.x;
    final topRight = borderRadius.topRight.x;
    final bottomLeft = borderRadius.bottomLeft.x;
    final bottomRight = borderRadius.bottomRight.x;
    return <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'topLeadingRadius': topLeft,
      'topTrailingRadius': topRight,
      'bottomLeadingRadius': bottomLeft,
      'bottomTrailingRadius': bottomRight,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final view = UiKitView(
        viewType: _viewType,
        creationParams: _creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
      if (height == null) {
        return SizedBox.expand(child: view);
      }
      return SizedBox(height: height, width: double.infinity, child: view);
    }

    return _FallbackGlassCard(
      title: title,
      subtitle: subtitle,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

class _FallbackGlassCard extends StatelessWidget {
  const _FallbackGlassCard({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.borderRadius,
  });

  final String title;
  final String subtitle;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showsText = title.isNotEmpty || subtitle.isNotEmpty;

    final card = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.12),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: showsText
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: theme.textTheme.titleMedium,
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );

    if (height == null) {
      return SizedBox.expand(child: card);
    }
    return SizedBox(height: height, width: double.infinity, child: card);
  }
}
