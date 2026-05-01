import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralised text style tokens for the Geoloc design system.
///
/// Prefer these static style resolvers over calling `GoogleFonts.xxx()` at
/// every call site. All resolvers accept a [BuildContext] so light/dark
/// colour resolution happens in one place.
class AppTextStyles {
  AppTextStyles._();

  // ── PT Serif (display / headline / title) ──────────────────

  /// 24 pt serif page title — "Welcome to Geoloc."
  static TextStyle pageTitle(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 22 pt serif — "Create Account"
  static TextStyle sectionTitle(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 20 pt serif — empty-state / error-state titles
  static TextStyle emptyTitle(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 17 pt italic serif — AppBar titles
  static TextStyle appBarTitle(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 17,
        fontStyle: FontStyle.italic,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 11 pt bold serif ALL CAPS — section labels
  /// ("COMMENTS", "ACCOUNT", "ADD MEDIA", "REPORT")
  static TextStyle sectionLabel(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: AppColors.gold(context),
      );

  /// 10 pt serif ALL CAPS — divider ornament ("OR SIGN IN USING")
  static TextStyle dividerOrnament(BuildContext context) => GoogleFonts.ptSerif(
        fontSize: 10,
        letterSpacing: 1.5,
        color: AppColors.textMuted(context),
      );

  // ── Plus Jakarta Sans (body / label) ────────────────────────

  /// 15 pt body — primary body text, form fields, list titles
  static TextStyle body(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 14 pt body — post content, notification text, form fields
  static TextStyle bodyMedium(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 14 pt body with 1.5 line-height — post content body
  static TextStyle postContent(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 14 pt semibold — usernames, emphasis
  static TextStyle username(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 13 pt — secondary labels, form hints, tab labels
  static TextStyle bodySmall(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 13 pt light — muted body, subtitle text
  static TextStyle bodySmallLight(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w300,
        color: AppColors.textMuted(context),
      );

  /// 12 pt light — location text, minor metadata
  static TextStyle caption(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: AppColors.textMuted(context),
      );

  /// 14 pt medium — form labels, button text
  static TextStyle label(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 12 pt medium ALL CAPS — small CTA labels ("CREATE POST", "RETRY")
  static TextStyle actionLabel(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: AppColors.gold(context),
      );

  /// 13 pt semibold — link text ("Sign Up", "Read all")
  static TextStyle link(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.gold(context),
      );

  /// 15 pt — dialog / action-sheet items
  static TextStyle sheetItem(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 15 pt bold — destructive sheet items ("Log Out")
  static TextStyle sheetItemDestructive(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.error,
      );

  // ── Fira Code (mono / data) ─────────────────────────────────

  /// 13 pt mono — numeric data, counts
  static TextStyle monoData(BuildContext context) => GoogleFonts.firaCode(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  /// 12 pt mono — email addresses
  static TextStyle monoSmall(BuildContext context) => GoogleFonts.firaCode(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted(context),
      );

  /// 11 pt mono — timestamps, counts in actions
  static TextStyle monoCaption(BuildContext context) => GoogleFonts.firaCode(
        fontSize: 11,
        color: AppColors.textMuted(context),
      );

  /// 10 pt mono — post timestamp
  static TextStyle monoTimestamp(BuildContext context) => GoogleFonts.firaCode(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted(context),
      );

  /// 22 pt mono — overflow image "+N" counter
  static TextStyle monoOverlay(BuildContext context) => GoogleFonts.firaCode(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onPrimary,
      );

  // ── Button text helpers ──────────────────────────────────────

  /// 13 pt ALL CAPS button — "SIGN IN", "CREATE ACCOUNT"
  static TextStyle buttonCaps(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.5,
        color: AppColors.gold(context),
      );

  /// 14 pt bold ALL CAPS — "SEND LINK", "UPDATE PASSWORD", "SUBMIT REPORT"
  static TextStyle buttonCapsBold(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.gold(context),
      );

  // ── Error / Form helpers ─────────────────────────────────────

  /// 13 pt error text
  static TextStyle errorText(BuildContext context) => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        color: AppColors.error,
      );

  /// 12 pt settings subtitle
  static TextStyle settingsSubtitle(BuildContext context) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        color: AppColors.textMuted(context),
      );
}

/// Prefer `context.pageTitle`, `context.body`, `context.monoCaption`, etc.
/// via the [GeolocThemeContext] extension.
