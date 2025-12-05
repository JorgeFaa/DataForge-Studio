import 'package:flutter/material.dart';

class AppColors {
  // --- Paleta Principal ---
  /// Gris carbón oscuro para fondos principales.
  static const Color background = Color(0xFF1E2022);
  /// Gris ligeramente más claro para superficies como AppBars y tarjetas.
  static const Color surface = Color(0xFF2D3033);
  /// Naranja vibrante para acciones principales y elementos destacados.
  static const Color primary = Color(0xFFFF7A00);
  /// Azul profesional de Postgres para información y acentos secundarios.
  static const Color secondary = Color(0xFF336791);
  /// Blanco roto para texto principal e íconos, para reducir la fatiga visual.
  static const Color onSurface = Color(0xFFF0F0F0);
  
  // --- Colores de Apoyo ---
  static const Color onPrimary = Colors.black;
  static const Color onSecondary = Colors.white;
  static const Color error = Colors.redAccent;
  static const Color onError = Colors.white;
}

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
    ),
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      error: AppColors.error,
      onError: AppColors.onError,
    ),
    textTheme: Typography.material2021(platform: TargetPlatform.android).white.apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    ),
    useMaterial3: true,
  );
}
