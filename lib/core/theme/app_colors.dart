import 'package:flutter/material.dart';

/// Accent / semantic palette used alongside Material 3 [ColorScheme].
///
/// **Source of truth for surfaces:** [AppTheme] / `ColorScheme` in
/// `lib/config/theme.dart` (+ AmbientGlowBackground).
/// Unused cream/parchment surface tokens below are retained only for migration
/// reference and must not be applied to scaffolds/cards.
class AppColors {
  AppColors._();

  // ── Deprecated surface tokens (do not use for UI surfaces) ──
  @Deprecated('Use ColorScheme.surface from AppTheme')
  static const bgLight = Color(0xFFF5F0E8);
  @Deprecated('Use ColorScheme.surfaceContainerHighest from AppTheme')
  static const surfaceLight = Color(0xFFEDE4D0);
  @Deprecated('Use ColorScheme.outlineVariant from AppTheme')
  static const borderLight = Color(0xFFD4C4A0);
  @Deprecated('Use ColorScheme.onSurface from AppTheme')
  static const textLight = Color(0xFF1E1810);

  static const textMutedLight = Color(0xFF7A6A50); // warm taupe

  // ── Deprecated dark surface tokens ──────────────────────────
  @Deprecated('Use ColorScheme.surface from AppTheme')
  static const bgDark = Color(0xFF1A1714);
  @Deprecated('Use ColorScheme.surfaceContainerHighest from AppTheme')
  static const surfaceDark = Color(0xFF2C2420);
  @Deprecated('Use ColorScheme.outlineVariant from AppTheme')
  static const borderDark = Color(0xFF3D3028);
  @Deprecated('Use ColorScheme.onSurface from AppTheme')
  static const textDark = Color(0xFFF5F0E8);
  static const textMutedDark = Color(0xFF8A7A5A);

  // ── Gold Accents ────────────────────────────────────────────
  static const goldDeep       = Color(0xFF8B6914); // light-mode primary
  static const goldBright     = Color(0xFFC9A84C); // dark-mode primary
  static const goldLight      = Color(0xFFE8C97A); // highlights (dark only)

  // ── Semantic ────────────────────────────────────────────────
  static const error   = Color(0xFFB44D4D); // muted red
  static const success = Color(0xFF5A8A5A); // muted green
  static const warning = Color(0xFFB8963E); // amber-gold
  static const info    = Color(0xFF5A7A8A); // muted teal

  /// Convenience — resolve gold accent for current brightness
  static Color gold(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? goldBright
        : goldDeep;
  }

  /// Convenience — resolve muted text for current brightness
  static Color textMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textMutedDark
        : textMutedLight;
  }
}
