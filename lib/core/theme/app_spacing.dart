import 'package:flutter/widgets.dart';

/// 4-pt spacing scale used across the app.
///
/// Prefer these constants over magic numbers in `SizedBox`, `EdgeInsets`,
/// and `Padding` to keep density tunable from a single source of truth.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Common page-content horizontal padding.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: lg);

  /// Common card inset (16/12 H/V).
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
}

/// Border-radius tokens. The "old-money" 2-pt sharp corner is the default;
/// soft corners are used for transient surfaces (sheets/dialogs).
class AppRadii {
  AppRadii._();

  static const double sharp = 2;
  static const double soft = 8;
  static const double pill = 999;

  static const BorderRadius sharpAll = BorderRadius.all(Radius.circular(sharp));
  static const BorderRadius softAll = BorderRadius.all(Radius.circular(soft));

  /// Top-only soft radius for bottom sheets.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sharp),
  );
}

/// Standard icon-size ramp.
class AppIconSize {
  AppIconSize._();

  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
}

/// Minimum touch-target sizes (Apple HIG: 44, Material: 48).
class AppTapTarget {
  AppTapTarget._();

  static const double iosMinimum = 44;
  static const double materialMinimum = 48;
}
