import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/info_tile.dart';
import '../../domain/entities/active_vehicle.dart';
import 'vehicle_card.dart';

/// Detail satu kendaraan aktif, dibuka dari daftar sebagai bottom sheet.
class VehicleDetailSheet extends StatelessWidget {
  const VehicleDetailSheet({
    super.key,
    required this.vehicle,
    required this.fallbackArea,
    required this.onCheckOut,
  });

  final ActiveVehicle vehicle;
  final String fallbackArea;
  final VoidCallback onCheckOut;

  static Future<void> show(
    BuildContext context, {
    required ActiveVehicle vehicle,
    required String fallbackArea,
    required VoidCallback onCheckOut,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VehicleDetailSheet(
        vehicle: vehicle,
        fallbackArea: fallbackArea,
        onCheckOut: () {
          Navigator.of(ctx).pop();
          onCheckOut();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final areaName =
        vehicle.areaName.isNotEmpty ? vehicle.areaName : fallbackArea;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
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
                          Icons.directions_car_rounded,
                          color: AppColors.spPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Detail Sesi #${vehicle.id}',
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.spSuccessBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: AppColors.spSuccessInk,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sedang Parkir',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spSuccessInk,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  PlateBadge(plate: vehicle.plateIn, large: true),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Durasi Berjalan',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.spInk3,
                        ),
                      ),
                      Text(
                        Formatters.duration(vehicle.durationMinutes),
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
            const SizedBox(height: 16),
            InfoTile(
              icon: Icons.badge_outlined,
              title: 'NIM Mahasiswa',
              value: vehicle.nim,
            ),
            const Divider(height: 14, color: AppColors.spBorderSoft),
            InfoTile(
              icon: Icons.person_outline,
              title: 'Petugas Masuk',
              value: vehicle.checkedInBy,
            ),
            const Divider(height: 14, color: AppColors.spBorderSoft),
            InfoTile(
              icon: Icons.access_time_rounded,
              title: 'Waktu Check-In',
              value: Formatters.dateTime(vehicle.checkedInAt),
            ),
            const Divider(height: 14, color: AppColors.spBorderSoft),
            InfoTile(
              icon: Icons.location_on_outlined,
              title: 'Pos Masuk',
              value: areaName,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.spBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        color: AppColors.spInk2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCheckOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Check-Out'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
