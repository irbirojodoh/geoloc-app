import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
    final gold = AppColors.gold(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: gold,
      backgroundColor: Theme.of(context).colorScheme.surface,
      strokeWidth: 2,
      edgeOffset: 0,
      child: child,
    );
  }
}
