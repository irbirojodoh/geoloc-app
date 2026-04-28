import 'package:flutter/material.dart';

/// Gradient hairline used inside bottom sheets to separate the title from
/// the action list. Faded at the edges for the "old-money" look.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            outline,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
