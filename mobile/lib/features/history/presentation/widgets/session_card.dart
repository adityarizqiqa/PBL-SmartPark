import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/history_item.dart';

/// Kartu satu baris riwayat sesi.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.item, required this.onDetail});

  final HistoryItem item;
  final VoidCallback onDetail;

  bool get _hasDifferentPlates =>
      item.plateOut != null &&
      item.plateOut!.isNotEmpty &&
      item.plateOut != item.plateIn;

  int get _durationMinutes {
    final end = item.checkedOutAt;
    if (end != null) return end.difference(item.checkedInAt).inMinutes;
    return DateTime.now().difference(item.checkedInAt).inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final isManual = item.status == 'manual_verified';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.spBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusPill.forSessionStatus(item.status, dense: true),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isManual
                            ? AppColors.spWarnBg
                            : AppColors.spNeutralBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isManual ? 'Disetujui Manual' : 'Sesi Selesai',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isManual ? AppColors.spWarn : AppColors.spSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '#${item.id}',
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.spInk3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasDifferentPlates)
            _ComparePlates(item: item)
          else
            _VerifiedPlate(item: item),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.spNeutralBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.spBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: AppColors.spPrimary700,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'NIM Mahasiswa:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.spSlate,
                      ),
                    ),
                  ],
                ),
                Text(
                  item.nim,
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spNavy,
                  ),
                ),
              ],
            ),
          ),
          if (item.verificationNote != null &&
              item.verificationNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteBanner(note: item.verificationNote!, isManual: isManual),
          ],
          const SizedBox(height: 10),
          _TimePanel(item: item, durationMinutes: _durationMinutes),
          const SizedBox(height: 10),
          InkWell(
            onTap: onDetail,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.spInfoBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.spInfoBorder),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lihat Detail Sesi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spPrimary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.spPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedPlate extends StatelessWidget {
  const _VerifiedPlate({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final isManual = item.status == 'manual_verified';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.spNeutralBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.spInfoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.spInfoBorder),
                  ),
                  child: const Icon(
                    Icons.directions_car_rounded,
                    size: 16,
                    color: AppColors.spPrimary700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAT TERVERIFIKASI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.spInk3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PlateChip(plate: item.plateIn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isManual
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            size: 20,
            color: isManual ? AppColors.spWarn : AppColors.spSuccess,
          ),
        ],
      ),
    );
  }
}

class _ComparePlates extends StatelessWidget {
  const _ComparePlates({required this.item});

  final HistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.spDangerBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.spInfoBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.spSlate,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Plat Check-In:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.spSlate,
                    ),
                  ),
                ],
              ),
              PlateChip(plate: item.plateIn, dense: true),
            ],
          ),
          const Divider(height: 12, color: AppColors.spInfoBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.compare_arrows_rounded,
                    size: 14,
                    color: AppColors.spDanger,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Plat Check-Out:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spDangerInk,
                    ),
                  ),
                ],
              ),
              PlateChip(
                plate: item.plateOut ?? '-',
                dense: true,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.note, required this.isManual});

  final String note;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isManual
            ? AppColors.spWarnBg
            : AppColors.spNeutralBg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isManual ? AppColors.spWarnInk : AppColors.spSlate,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isManual ? Icons.info_outline : Icons.note_outlined,
            size: 14,
            color: isManual ? AppColors.spWarnInk : AppColors.spSlate,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Catatan: $note',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isManual ? AppColors.spWarnInk : AppColors.spSlate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePanel extends StatelessWidget {
  const _TimePanel({required this.item, required this.durationMinutes});

  final HistoryItem item;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spInfoBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.spInfoBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TimeCell(
              label: 'MASUK',
              value: Formatters.time(item.checkedInAt),
            ),
          ),
          Container(width: 1, height: 26, color: AppColors.spInfoBorder),
          Expanded(
            child: _TimeCell(
              label: 'KELUAR',
              value: item.checkedOutAt == null
                  ? '-'
                  : Formatters.time(item.checkedOutAt!),
            ),
          ),
          Container(width: 1, height: 26, color: AppColors.spInfoBorder),
          Expanded(
            child: _TimeCell(
              label: 'DURASI PARKIR',
              value: Formatters.duration(durationMinutes),
              color: AppColors.spPrimary700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.spInk2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color ?? AppColors.spNavy,
          ),
        ),
      ],
    );
  }
}

/// Plat nomor bergaya papan kendaraan.
class PlateChip extends StatelessWidget {
  const PlateChip({
    super.key,
    required this.plate,
    this.dense = false,
    this.danger = false,
  });

  final String plate;
  final bool dense;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: danger ? AppColors.spDanger : AppColors.spNavy,
        borderRadius: BorderRadius.circular(dense ? 4 : 6),
      ),
      child: Text(
        plate,
        style: TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: dense ? 11 : 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Bar navigasi halaman riwayat.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.rangeLabel,
    required this.pageNumber,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  final String rangeLabel;
  final int pageNumber;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rangeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.spInk3,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 20,
                color: AppColors.spPrimary,
                disabledColor: AppColors.spBorder,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.spTint2,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$pageNumber / $pageCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spPrimary700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 20,
                color: AppColors.spPrimary,
                disabledColor: AppColors.spBorder,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
