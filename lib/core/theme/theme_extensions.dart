import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Ergonomic accessors for theme + brand tokens off [BuildContext].
///
/// Prefer `context.textTheme.titleLarge` or `context.styles.body` over
/// re-instantiating `GoogleFonts.xxx()` per call site. Keeps typography
/// centralized in [ThemeData] and [AppTextStyles].
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

  /// Typography tokens (PT Serif, Plus Jakarta Sans, Fira Code).
  /// Use: `context.body`, `context.pageTitle`, `context.monoTimestamp`, etc.
  TextStyle get pageTitle => AppTextStyles.pageTitle(this);
  TextStyle get sectionTitle => AppTextStyles.sectionTitle(this);
  TextStyle get emptyTitle => AppTextStyles.emptyTitle(this);
  TextStyle get appBarTitle => AppTextStyles.appBarTitle(this);
  TextStyle get sectionLabel => AppTextStyles.sectionLabel(this);
  TextStyle get dividerOrnament => AppTextStyles.dividerOrnament(this);
  TextStyle get body => AppTextStyles.body(this);
  TextStyle get bodyMedium => AppTextStyles.bodyMedium(this);
  TextStyle get postContent => AppTextStyles.postContent(this);
  TextStyle get username => AppTextStyles.username(this);
  TextStyle get bodySmall => AppTextStyles.bodySmall(this);
  TextStyle get bodySmallLight => AppTextStyles.bodySmallLight(this);
  TextStyle get caption => AppTextStyles.caption(this);
  TextStyle get label => AppTextStyles.label(this);
  TextStyle get actionLabel => AppTextStyles.actionLabel(this);
  TextStyle get link => AppTextStyles.link(this);
  TextStyle get sheetItem => AppTextStyles.sheetItem(this);
  TextStyle get sheetItemDestructive => AppTextStyles.sheetItemDestructive(this);
  TextStyle get monoData => AppTextStyles.monoData(this);
  TextStyle get monoSmall => AppTextStyles.monoSmall(this);
  TextStyle get monoCaption => AppTextStyles.monoCaption(this);
  TextStyle get monoTimestamp => AppTextStyles.monoTimestamp(this);
  TextStyle get monoOverlay => AppTextStyles.monoOverlay(this);
  TextStyle get buttonCaps => AppTextStyles.buttonCaps(this);
  TextStyle get buttonCapsBold => AppTextStyles.buttonCapsBold(this);
  TextStyle get errorText => AppTextStyles.errorText(this);
  TextStyle get settingsSubtitle => AppTextStyles.settingsSubtitle(this);
}
