import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material Design 3 theme (Material You) for Geoloc.
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFFEB5E28);

  static ColorScheme _buildColorScheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.light) {
      return scheme.copyWith(
        surface: const Color(0xFFFFFCF2),
        onSurface: const Color(0xFF252422),
        onSurfaceVariant: const Color(0xFF403D39),
        surfaceContainerHighest: const Color(0xFFE8E3DC),
        outlineVariant: const Color(0xFFCCC5B9),
        outline: const Color(0xFF8A847C),
      );
    }

    return scheme.copyWith(
      surface: const Color(0xFF1A1917),
      onSurface: const Color(0xFFFFFCF2),
      onSurfaceVariant: const Color(0xFFCCC5B9),
      surfaceContainerHighest: const Color(0xFF403D39),
      outlineVariant: const Color(0xFF4E4A45),
      outline: const Color(0xFF8A847C),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
    );
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = _buildColorScheme(brightness);
    final textTheme = _buildTextTheme(brightness);
    final pillInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );
    final focusedPillBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.primary,
        scrolledUnderElevation: 3,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelSmall!;
          if (states.contains(WidgetState.selected)) {
            return base.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return base.copyWith(color: colorScheme.onSurfaceVariant);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        shape: const StadiumBorder(),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: pillInputBorder,
        enabledBorder: pillInputBorder,
        focusedBorder: focusedPillBorder,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: colorScheme.secondaryContainer,
          selectedForegroundColor: colorScheme.onSecondaryContainer,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.primaryContainer,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: colorScheme.primary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
}
