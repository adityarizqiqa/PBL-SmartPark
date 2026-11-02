import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pita galat ringkas dengan tombol coba lagi opsional.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.spDanger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.spDanger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppColors.spDanger,
              ),
              onPressed: onRetry,
              tooltip: 'Coba lagi',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}
