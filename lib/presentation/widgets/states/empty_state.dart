import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_extensions.dart';

/// Shared empty-state layout: gold icon + serif headline + muted body
/// + optional outlined "ALL CAPS" call-to-action button.
///
/// Replaces 4+ inline reimplementations across feed/profile/search/notifications.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  }) : assert(
         actionLabel == null || onAction != null,
         'If actionLabel is set, onAction must be provided.',
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.gold(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: gold.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.emptyTitle,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.bodyMedium?.copyWith(
                color: AppColors.textMuted(context),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.xxxl),
              OutlinedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add, size: 18, color: gold),
                label: Text(
                  actionLabel!.toUpperCase(),
                  style: context.actionLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
