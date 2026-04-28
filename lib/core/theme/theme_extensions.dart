import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ergonomic accessors for theme + brand tokens off [BuildContext].
///
/// Prefer `context.textTheme.titleLarge` over re-instantiating
/// `GoogleFonts.xxx()` per call site. Keeps typography centralized
/// in [ThemeData].
extension GeolocThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
  Brightness get brightness => Theme.of(this).brightness;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Brand gold resolved for the current brightness.
  Color get gold => AppColors.gold(this);

  /// Muted secondary text resolved for the current brightness.
  Color get mutedText => AppColors.textMuted(this);
}
