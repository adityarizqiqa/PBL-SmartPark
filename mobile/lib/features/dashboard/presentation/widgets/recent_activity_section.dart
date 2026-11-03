import 'package:flutter/material.dart';

import '../../../../core/entities/parking_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';

/// Daftar aktivitas sesi terakhir di pos.
class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.sessions,
    this.onSeeAll,
  });

  final List<SessionDetail> sessions;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
                  'AKTIVITAS TERAKHIR DI POS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.spPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spPrimary600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (sessions.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Belum ada aktivitas',
            message: 'Belum ada aktivitas sesi di pos ini.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sessions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _ActivityCard(session: sessions[index]),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.session});

  final SessionDetail session;

  @override
  Widget build(BuildContext context) {
    final isCheckIn = session.status == 'active';
    final plate = (session.plateOut != null && session.plateOut!.isNotEmpty)
        ? session.plateOut!
        : session.plateIn;
    final time = session.checkedOutAt != null
        ? Formatters.time(session.checkedOutAt!)
        : Formatters.time(session.checkedInAt);

    final (label, color, icon) = switch (session.status) {
      'matched' => (
          'Sesuai',
          AppColors.spPrimary600,
          Icons.check_circle_rounded,
        ),
      'manual_verified' => (
          'Verifikasi Manual',
          AppColors.spWarn,
          Icons.assignment_turned_in_rounded,
        ),
      'voided' => ('Dibatalkan', AppColors.spDanger, Icons.cancel_rounded),
      _ => (
          'Sedang Parkir',
          AppColors.spPrimary600,
          Icons.local_parking_rounded,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    PlateBadge(plate: plate),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'NIM ${session.nim}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.spInk3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _DirectionChip(isCheckIn: isCheckIn),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.spTint1,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: AppColors.spInk3,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spInk2,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  const _DirectionChip({required this.isCheckIn});

  final bool isCheckIn;

  @override
  Widget build(BuildContext context) {
    final background =
        isCheckIn ? AppColors.spTint4 : AppColors.spTint5;
    final foreground =
        isCheckIn ? AppColors.spPrimary700 : AppColors.spPrimary800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCheckIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            size: 11,
            color: foreground,
          ),
          const SizedBox(width: 3),
          Text(
            isCheckIn ? 'Masuk' : 'Keluar',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tampilan plat nomor gaya papan kendaraan.
class PlateBadge extends StatelessWidget {
  const PlateBadge({super.key, required this.plate});

  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.spNavy,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        plate,
        style: const TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
