import 'package:flutter/material.dart';

/// Clean dark theme: neutral grey surfaces (no brown tint), white text,
/// brand orange only as an accent.
ThemeData buildOpenFitnessTheme() {
  const accent = Color(0xFFFF6D00);
  const bg = Color(0xFF121212);
  const surface = Color(0xFF1D1D1F);
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: bg,
    surfaceContainerHighest: const Color(0xFF2A2A2D),
    primary: accent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    cardTheme: const CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    chipTheme: const ChipThemeData(showCheckmark: false),
  );
}
