import 'package:flutter/material.dart';

/// Gradient hairline used inside bottom sheets to separate the title from
/// the action list. Faded at the edges for the "old-money" look.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surface.withValues(alpha: 0),
            colorScheme.outline,
            colorScheme.surface.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
