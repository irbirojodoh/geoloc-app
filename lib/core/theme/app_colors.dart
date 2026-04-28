import 'package:flutter/material.dart';

/// Old-money color palette — warm neutrals with gold accents
class AppColors {
  AppColors._();

  // ── Light Mode ──────────────────────────────────────────────
  static const bgLight        = Color(0xFFF5F0E8); // warm cream
  static const surfaceLight   = Color(0xFFEDE4D0); // parchment
  static const borderLight    = Color(0xFFD4C4A0); // aged linen
  static const textLight      = Color(0xFF1E1810); // rich ink
  static const textMutedLight = Color(0xFF7A6A50); // warm taupe

  // ── Dark Mode ───────────────────────────────────────────────
  static const bgDark         = Color(0xFF1A1714); // deep espresso
  static const surfaceDark    = Color(0xFF2C2420); // dark tobacco
  static const borderDark     = Color(0xFF3D3028);
  static const textDark       = Color(0xFFF5F0E8);
  static const textMutedDark  = Color(0xFF8A7A5A);

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
