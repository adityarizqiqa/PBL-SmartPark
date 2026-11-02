import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema tunggal aplikasi.
///
/// Isinya sengaja hanya yang dipakai bersama (skema warna dan tipografi);
/// gaya per komponen tetap ditentukan layar agar tampilan tidak bergeser.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.spBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.spPrimary,
        primary: AppColors.spPrimary,
        surface: AppColors.spSurface,
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
