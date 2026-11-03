import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/repositories/dashboard_repository.dart';

/// Tiga kartu statistik dan bilah kapasitas lahan.
class OperationalStats extends StatelessWidget {
  const OperationalStats({
    super.key,
    required this.summary,
    this.onOpenVehicles,
  });

  final HomeSummary summary;
  final VoidCallback? onOpenVehicles;

  @override
  Widget build(BuildContext context) {
    final occupancyColor = summary.occupancyPercent > 80
        ? AppColors.spWarn
        : AppColors.spPrimary600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatCard(
          label: 'Sedang Parkir',
          value: '${summary.parked}',
          valueColor: AppColors.spPrimary,
          icon: Icons.local_parking_rounded,
          badgeText: '${summary.occupancyPercent}% Penuh',
          onTap: onOpenVehicles,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Check-In Hari Ini',
                value: '${summary.checkedInToday}',
                valueColor: AppColors.spInk,
                icon: Icons.arrow_downward_rounded,
                badgeText: 'Total Masuk',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Check-Out Hari Ini',
                value: '${summary.checkedOutToday}',
                valueColor: AppColors.spInk,
                icon: Icons.arrow_upward_rounded,
                badgeText: 'Total Keluar',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.spBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Kapasitas Lahan Utama',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spInk2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${summary.parked} / ${summary.capacity} Slot',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: summary.occupancy,
                  minHeight: 8,
                  backgroundColor: AppColors.spTint2,
                  valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.badgeText,
    this.onTap,
  });

  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final String badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
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
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spInk3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(icon, size: 16, color: valueColor.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spPrimary600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
