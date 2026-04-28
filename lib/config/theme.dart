import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// Old-money luxury theme — refined, restrained, timeless
class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════
  // Light Theme
  // ═══════════════════════════════════════════════════════════════
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: const ColorScheme.light(
        surface: AppColors.surfaceLight,
        primary: AppColors.goldDeep,
        onPrimary: AppColors.bgLight,
        onSurface: AppColors.textLight,
        outline: AppColors.borderLight,
        error: AppColors.error,
        onError: AppColors.bgLight,
      ),

      // ── Typography ───────────────────────────────────────────
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: GoogleFonts.ptSerif(
          color: AppColors.textLight,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedLight,
          fontWeight: FontWeight.w300,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedLight,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: GoogleFonts.firaCode(
          color: AppColors.textMutedLight,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bgLight,
        foregroundColor: AppColors.textLight,
        titleTextStyle: GoogleFonts.ptSerif(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: AppColors.textLight,
        ),
      ),

      // ── Cards ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        color: AppColors.surfaceLight,
      ),

      // ── Buttons ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.goldDeep,
          foregroundColor: AppColors.bgLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.goldDeep,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          side: const BorderSide(color: AppColors.goldDeep, width: 1),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldDeep,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Inputs ───────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 14,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.goldDeep, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedLight,
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedLight,
          fontSize: 14,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────
      dividerColor: AppColors.borderLight,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 0.5,
        space: 1,
      ),

      // ── Bottom Nav ───────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.goldDeep,
        unselectedItemColor: AppColors.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Chips ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.goldDeep.withAlpha(30),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),

      // ── SnackBar ─────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // ── TabBar ───────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.goldDeep,
        unselectedLabelColor: AppColors.textMutedLight,
        indicatorColor: AppColors.goldDeep,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Dark Theme
  // ═══════════════════════════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surfaceDark,
        primary: AppColors.goldBright,
        onPrimary: AppColors.bgDark,
        onSurface: AppColors.textDark,
        outline: AppColors.borderDark,
        error: AppColors.error,
        onError: AppColors.textDark,
      ),

      // ── Typography ───────────────────────────────────────────
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w400,
        ),
        headlineSmall: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w400,
        ),
        titleLarge: GoogleFonts.ptSerif(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedDark,
          fontWeight: FontWeight.w300,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          color: AppColors.textDark,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedDark,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: GoogleFonts.firaCode(
          color: AppColors.textMutedDark,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── AppBar ───────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bgDark,
        foregroundColor: AppColors.textDark,
        titleTextStyle: GoogleFonts.ptSerif(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: AppColors.textDark,
        ),
      ),

      // ── Cards ────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.borderDark, width: 1),
        ),
        color: AppColors.surfaceDark,
      ),

      // ── Buttons ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.goldBright,
          foregroundColor: AppColors.bgDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.goldBright,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          side: const BorderSide(color: AppColors.goldBright, width: 1),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.goldBright,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Inputs ───────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 14,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.goldBright, width: 1.5),
        ),
        errorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedDark,
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMutedDark,
          fontSize: 14,
        ),
      ),

      // ── Divider ──────────────────────────────────────────────
      dividerColor: AppColors.borderDark,
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 0.5,
        space: 1,
      ),

      // ── Bottom Nav ───────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.goldBright,
        unselectedItemColor: AppColors.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Chips ────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedColor: AppColors.goldBright.withAlpha(50),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),

      // ── SnackBar ─────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),

      // ── TabBar ───────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.goldBright,
        unselectedLabelColor: AppColors.textMutedDark,
        indicatorColor: AppColors.goldBright,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
