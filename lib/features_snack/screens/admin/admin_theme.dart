import 'package:flutter/material.dart';

abstract final class AdminColors {
  static const background = Color(0xFFE9E6F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF7F5FB);
  static const surfaceHighlight = Color(0xFFF0EDF8);
  static const border = Color(0xFFE2DEEA);
  static const borderLight = Color(0xFFD5CFE0);

  static const accent = Color(0xFF6B4EFF);
  static const accentSoft = Color(0xFF8B74FF);
  static const accentGlow = Color(0x1A6B4EFF);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);

  static const textPrimary = Color(0xFF1F1B2E);
  static const textSecondary = Color(0xFF5C5670);
  static const textMuted = Color(0xFF8A849C);

  static const sidebarBackground = Color(0xFFF3F1F8);
  static const sidebarActive = Color(0xFFE8E4F2);

  static const headerBackground = Color(0xFFFFFFFF);

  static LinearGradient get accentGradient => const LinearGradient(
        colors: [accent, Color(0xFF9B6BFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get cardGradient => const LinearGradient(
        colors: [surface, surfaceElevated],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

ThemeData appLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: AdminColors.accent,
    onPrimary: Colors.white,
    secondary: AdminColors.accentSoft,
    surface: AdminColors.surface,
    onSurface: AdminColors.textPrimary,
    error: AdminColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AdminColors.background,
    dividerColor: AdminColors.border,
    cardColor: AdminColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: AdminColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: AdminColors.textPrimary),
      bodyMedium: TextStyle(color: AdminColors.textSecondary),
      bodySmall: TextStyle(color: AdminColors.textMuted),
      labelLarge: TextStyle(
        color: AdminColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AdminColors.textSecondary),
      hintStyle: const TextStyle(color: AdminColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AdminColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.accent,
        side: const BorderSide(color: AdminColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
  );
}

ThemeData adminTheme() => appLightTheme();
