import 'package:flutter/material.dart';

import 'native_glass_card.dart';

/// Bottom sheet chrome shared by login and register.
class AuthGlassSheet extends StatelessWidget {
  const AuthGlassSheet({super.key, required this.child});

  final Widget child;

  static const foreground = Colors.white;
  static const radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned.fill(
              child: NativeGlassCard(
                title: '',
                subtitle: '',
                height: null,
                borderRadius: radius,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    backgroundBlendMode: BlendMode.multiply,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
