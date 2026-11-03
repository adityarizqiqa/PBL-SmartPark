import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema tunggal aplikasi.
///
/// Isinya sengaja hanya yang dipakai bersama (skema warna dan tipografi);
/// gaya per komponen tetap ditentukan layar agar tampilan tidak bergeser.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.spPrimary,
      primary: AppColors.spPrimary,
      surface: AppColors.spSurface,
    );
    final textTheme = Typography.material2021().black.apply(
          bodyColor: AppColors.spInk,
          displayColor: AppColors.spInk,
        );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.spBg,
      colorScheme: scheme,
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.spPrimary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.spPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

/// Jarak baku antarelemen.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Radius sudut baku.
class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}
