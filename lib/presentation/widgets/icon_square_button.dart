import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// 44×44 outlined-square icon button used across the top bars and toolbars.
///
/// Wraps the icon in a [Semantics] node and inflates the hit area to the
/// iOS minimum (44 pt) — most legacy call sites used 34×34 [GestureDetector]s
/// which are below both Apple HIG and Material guidelines.
class IconSquareButton extends StatelessWidget {
  const IconSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.iconColor,
    this.size = AppTapTarget.iosMinimum,
    this.iconSize = AppIconSize.md,
    this.tooltip,
  });

  /// The icon to render in the center of the square.
  final IconData icon;

  /// Tap handler. If null the button renders disabled (no ripple).
  final VoidCallback? onTap;

  /// Accessible label for screen readers (e.g. "Notifications", "Profile").
  /// **Strongly recommended** — icon-only buttons announce as "Button" otherwise.
  final String? semanticLabel;

  /// Override the icon color. Defaults to `colorScheme.onSurface` for neutral
  /// buttons; pass [AppColors.gold] for accent buttons.
  final Color? iconColor;

  /// Outer dimensions. Default is 44×44 — the Apple minimum.
  final double size;

  /// Glyph size inside the square.
  final double iconSize;

  /// Material tooltip shown on long-press (and read by some screen readers).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.onSurface;

    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadii.sharpAll,
        border: Border.all(color: cs.outline, width: 1),
      ),
      child: Icon(icon, size: iconSize, color: effectiveIconColor),
    );

    final wrapped = Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: size / 2,
        containedInkWell: true,
        child: core,
      ),
    );

    final t = tooltip;
    if (t != null) {
      return Tooltip(message: t, child: wrapped);
    }
    return wrapped;
  }
}
