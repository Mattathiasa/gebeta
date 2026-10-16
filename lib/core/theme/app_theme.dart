import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';

/// One family everywhere: NotoSansEthiopic carries both Latin and Ge'ez
/// in matching weights, so an Amharic string never falls back to a
/// mismatched system face mid-sentence.
const String _fontFamily = 'NotoSansEthiopic';

abstract final class GebetaTheme {
  static ThemeData light() => _base(
        brightness: Brightness.light,
        background: GebetaColors.cream,
        surface: GebetaColors.creamDeep,
        onSurface: GebetaColors.ink,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        background: GebetaColors.darkBackground,
        surface: GebetaColors.darkSurface,
        onSurface: GebetaColors.onDark,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: GebetaColors.gold,
      onPrimary: GebetaColors.woodDarkest,
      secondary: GebetaColors.wood,
      onSecondary: GebetaColors.onDark,
      tertiary: GebetaColors.honey,
      onTertiary: GebetaColors.woodDarkest,
      surface: surface,
      onSurface: onSurface,
      error: GebetaColors.danger,
      onError: GebetaColors.onDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: _fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: onSurface,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 40,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 24,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 16,
          color: onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: onSurface.withValues(alpha: 0.8),
        ),
        labelLarge: TextStyle(
          fontFamily: _fontFamily,
          fontWeight: FontWeight.w600,
          fontSize: 15,
          letterSpacing: 0.3,
          color: onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GebetaColors.gold,
          foregroundColor: GebetaColors.woodDarkest,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(GebetaRadius.md)),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: onSurface.withValues(alpha: 0.3)),
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(GebetaRadius.md)),
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: GebetaRadius.card,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: const OutlineInputBorder(
          borderRadius: GebetaRadius.card,
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: GebetaSpacing.md,
          vertical: GebetaSpacing.md,
        ),
      ),
    );
  }
}
