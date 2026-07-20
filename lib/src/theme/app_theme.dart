import 'package:flutter/material.dart';

class AppTheme {
  static const brand = Color(0xFF0F766E);
  static const accent = Color(0xFF0891B2);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const canvas = Color(0xFFF6F8FB);

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: brand,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      error: Color(0xFFE11D48),
      outline: Color(0xFFE2E8F0),
      outlineVariant: Color(0xFFEEF2F6),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF8FAFC),
      surfaceContainer: Color(0xFFF1F5F9),
      surfaceContainerHigh: Color(0xFFEFF3F7),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: ink,
        ),
        headlineMedium: const TextStyle(
          fontSize: 27,
          height: 1.12,
          fontWeight: FontWeight.w900,
          letterSpacing: -.8,
          color: ink,
        ),
        titleLarge: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -.4,
          color: ink,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyLarge: const TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.45, color: ink),
        bodySmall: const TextStyle(fontSize: 12, height: 1.4, color: muted),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: .1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: .6,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -.4,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE8EDF3)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFEEF2F6),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: brand, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE11D48)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: ink,
          side: const BorderSide(color: Color(0xFFDCE3EA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFCCFBF1),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        modalBarrierColor: Color(0x990F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: brand),
    );
  }
}
