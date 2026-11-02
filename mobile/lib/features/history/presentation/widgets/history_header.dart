import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/history_filter.dart';

/// Kartu judul + ringkasan harian.
class HistoryBanner extends StatelessWidget {
  const HistoryBanner({
    super.key,
    required this.areaLabel,
    required this.total,
    required this.matched,
    required this.manual,
    required this.active,
  });

  final String areaLabel;
  final int total;
  final int matched;
  final int manual;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.spInfoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RIWAYAT SESI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.spPrimary700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Pos Operasional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.spInk2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat Sesi Parkir',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.spNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Shared Device • $areaLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.spSlate,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.spBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryBox(
                    label: 'TOTAL',
                    value: '$total',
                    background: const Color(0xFFF8FAFC),
                    valueColor: AppColors.spPrimary,
                    labelColor: AppColors.spInk3,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SummaryBox(
                    label: 'SESUAI',
                    value: '$matched',
                    background: const Color(0x66ECFDF5),
                    valueColor: AppColors.spSuccessInk,
                    labelColor: AppColors.spSuccessInk,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SummaryBox(
                    label: 'MANUAL',
                    value: '$manual',
                    background: const Color(0x66FFFBEB),
                    valueColor: AppColors.spWarn,
                    labelColor: AppColors.spWarn,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _SummaryBox(
                    label: 'AKTIF',
                    value: '$active',
                    background: const Color(0x66FFF1F2),
                    valueColor: const Color(0xFFBE123C),
                    labelColor: const Color(0xFF9F1239),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({
    required this.label,
    required this.value,
    required this.background,
    required this.valueColor,
    required this.labelColor,
  });

  final String label;
  final String value;
  final Color background;
  final Color valueColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris filter periode dan tab status.
class HistoryFilters extends StatelessWidget {
  const HistoryFilters({
    super.key,
    required this.period,
    required this.status,
    required this.onPeriodChanged,
    required this.onStatusChanged,
  });

  final HistoryPeriod period;
  final HistoryStatusFilter status;
  final ValueChanged<HistoryPeriod> onPeriodChanged;
  final ValueChanged<HistoryStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in HistoryPeriod.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: option.label,
                    selected: option == period,
                    icon: option == HistoryPeriod.custom
                        ? Icons.calendar_today_rounded
                        : null,
                    onTap: () => onPeriodChanged(option),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in HistoryStatusFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Chip(
                    label: option.label,
                    selected: option == status,
                    dense: true,
                    onTap: () => onStatusChanged(option),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 14,
          vertical: dense ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.spPrimary : AppColors.spSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.spPrimary : AppColors.spBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppColors.spSlate,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: dense ? 11 : 12,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : AppColors.spSlate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom pencarian riwayat.
class HistorySearchBar extends StatelessWidget {
  const HistorySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Cari NIM atau Plat Nomor...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
