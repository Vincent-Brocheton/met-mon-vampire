import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Couleurs relevées dans les maquettes (spec, « Identité visuelle »).
abstract final class AppColors {
  static const background = Color(0xFF120E10);
  static const surface = Color(0xFF1A1315);
  static const card = Color(0xFF1C1618);
  static const navActive = Color(0xFF2A2023);
  static const border = Color(0xFF3A2E31);
  static const fieldBorder = Color(0xFF4A3B3F);
  static const text = Color(0xFFEEE6D8);
  static const textSoft = Color(0xFFD9D0C2);
  static const textSecondary = Color(0xFFB5A99A);
  static const textMuted = Color(0xFF8F8377);
  static const accent = Color(0xFFB3262F);
  static const accentIcon = Color(0xFFE0575F);
  static const link = Color(0xFFE0707A);
  static const linkHover = Color(0xFFF0A0A6);
  static const gold = Color(0xFFC8A96A);
  static const goldLight = Color(0xFFE3C98E);
  static const success = Color(0xFF8FD3B8);
  static const narrator = Color(0xFFC3B5F0);
  static const offline = Color(0xFF8FB8E0);
  static const staffAvatar = Color(0xFF4A2226);
}

/// Largeur à partir de laquelle on affiche la mise en page Web.
const kWideBreakpoint = 900.0;

/// [withFonts] à false dans les tests : google_fonts télécharge les polices.
ThemeData buildTheme({bool withFonts = true}) {
  TextStyle serif(double size) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w600, height: 1.05, color: AppColors.text);
    return withFonts ? GoogleFonts.cormorantGaramond(textStyle: style) : style;
  }

  const body = TextTheme(
    bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: AppColors.textSoft),
    bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: AppColors.text),
    bodySmall: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textMuted),
    titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
    labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
    labelSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: AppColors.textSecondary),
  );
  final textTheme = (withFonts ? GoogleFonts.sourceSans3TextTheme(body) : body).copyWith(
    displayLarge: serif(76),
    displayMedium: serif(52),
    displaySmall: serif(44),
    headlineLarge: serif(40),
    headlineMedium: serif(34),
    headlineSmall: serif(24),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  OutlineInputBorder border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: c));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      surface: AppColors.background,
      onSurface: AppColors.text,
      error: AppColors.linkHover,
      outline: AppColors.fieldBorder,
    ),
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(AppColors.fieldBorder),
      enabledBorder: border(AppColors.fieldBorder),
      focusedBorder: border(AppColors.accentIcon),
      errorBorder: border(AppColors.link),
      focusedErrorBorder: border(AppColors.linkHover),
      errorStyle: const TextStyle(color: AppColors.linkHover),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: shape,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.fieldBorder),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: shape,
        textStyle: const TextStyle(fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.link,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontSize: 14),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : null),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.navActive,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.card),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.navActive,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
  );
}
