import 'package:flutter/material.dart';

/// Custom refresh indicator with gold-tinted dots — old-money aesthetic
class CustomRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      strokeWidth: 2,
      edgeOffset: 0,
      child: child,
    );
  }
}
