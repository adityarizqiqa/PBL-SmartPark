import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Nada warna status.
enum PillTone { success, warning, danger, info, neutral }

/// Label status berwarna, dipakai di daftar kendaraan, riwayat, dan detail.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = PillTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool dense;

  /// Memetakan status sesi dari backend ke label dan warna.
  factory StatusPill.forSessionStatus(String status, {Key? key}) {
    final (label, tone, icon) = switch (status) {
      'matched' => ('Sesuai', PillTone.success, Icons.check_circle_rounded),
      'manual_verified' => (
          'Verifikasi Manual',
          PillTone.warning,
          Icons.warning_amber_rounded,
        ),
      'active' => ('Aktif', PillTone.info, Icons.local_parking_rounded),
      'voided' => ('Dibatalkan', PillTone.danger, Icons.cancel_rounded),
      'rejected' => ('Ditolak', PillTone.danger, Icons.block_rounded),
      _ => (status, PillTone.neutral, Icons.info_outline_rounded),
    };
    return StatusPill(key: key, label: label, tone: tone, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      PillTone.success => (AppColors.spSuccessBg, AppColors.spSuccessInk),
      PillTone.warning => (AppColors.spWarnBg, AppColors.spWarn),
      PillTone.danger => (AppColors.spDangerBg, AppColors.spDangerInk),
      PillTone.info => (AppColors.spInfoBg, AppColors.spPrimary600),
      PillTone.neutral => (const Color(0xFFF1F5F9), AppColors.spSlate),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
