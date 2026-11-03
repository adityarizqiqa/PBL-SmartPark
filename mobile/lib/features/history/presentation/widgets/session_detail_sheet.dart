import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/info_tile.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/history_item.dart';
import 'session_card.dart';

/// Detail lengkap satu sesi riwayat.
class SessionDetailSheet extends StatelessWidget {
  const SessionDetailSheet({
    super.key,
    required this.item,
    required this.areaLabel,
  });

  final HistoryItem item;
  final String areaLabel;

  static Future<void> show(
    BuildContext context, {
    required HistoryItem item,
    required String areaLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionDetailSheet(item: item, areaLabel: areaLabel),
    );
  }

  int get _durationMinutes {
    final end = item.checkedOutAt;
    if (end != null) return end.difference(item.checkedInAt).inMinutes;
    return DateTime.now().difference(item.checkedInAt).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final hasDifferentPlates = item.plateOut != null &&
        item.plateOut!.isNotEmpty &&
        item.plateOut != item.plateIn;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.spBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.spTint3,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.spPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Detail Sesi #${item.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.spInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill.forSessionStatus(item.status, dense: true),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PlateChip(plate: item.plateIn, dense: true),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Durasi Parkir',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spInk3,
                          ),
                        ),
                        Text(
                          Formatters.duration(_durationMinutes),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.spPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasDifferentPlates) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.spDangerBg,
                    border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.compare_arrows_rounded,
                            size: 16,
                            color: AppColors.spDangerInk,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Plat Keluar:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spDangerInk,
                            ),
                          ),
                        ],
                      ),
                      PlateChip(plate: item.plateOut!, dense: true, danger: true),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              InfoTile(
                icon: Icons.badge_outlined,
                title: 'NIM Mahasiswa',
                value: item.nim,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              InfoTile(
                icon: Icons.verified_user_outlined,
                title: 'Status Verifikasi',
                value: _statusLabel(item.status),
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              InfoTile(
                icon: Icons.login_rounded,
                title: 'Waktu Masuk',
                value: Formatters.dateTime(item.checkedInAt),
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              InfoTile(
                icon: Icons.logout_rounded,
                title: 'Waktu Keluar',
                value: item.checkedOutAt == null
                    ? '-'
                    : Formatters.dateTime(item.checkedOutAt!),
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              InfoTile(
                icon: Icons.location_on_outlined,
                title: 'Pos Gerbang',
                value: areaLabel,
              ),
              if (item.verificationNote != null &&
                  item.verificationNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.spWarnBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.spWarnInk),
                  ),
                  child: Text(
                    'Catatan: ${item.verificationNote}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.spWarnInk,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'matched' => 'Sesuai',
        'manual_verified' => 'Verifikasi Manual',
        'voided' => 'Dibatalkan',
        'active' => 'Sedang Parkir',
        _ => status,
      };
}
