import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Umpan balik singkat yang konsisten di seluruh layar.
class AppSnackBar {
  const AppSnackBar._();

  static void success(BuildContext context, String message) {
    _show(context, message, AppColors.spPrimary, Icons.check_circle_outline);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, AppColors.spDanger, Icons.error_outline);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, AppColors.spNavy, Icons.info_outline_rounded);
  }

  static void _show(
    BuildContext context,
    String message,
    Color background,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
