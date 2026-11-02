import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Penjelasan dua peran yang bisa masuk.
class TwoEntryPathsCard extends StatelessWidget {
  const TwoEntryPathsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dua Jalur Masuk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.spInk,
            ),
          ),
          SizedBox(height: 12),
          _PathRow(
            icon: Icons.person_outline_rounded,
            title: 'Petugas Gerbang',
            description:
                'Memproses check-in dan check-out. Wajib memilih lahan jaga.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.spBorderSoft),
          ),
          _PathRow(
            icon: Icons.assignment_outlined,
            title: 'Pengawas (SPV)',
            description:
                'Menambah lahan dan mengatur shift jaga. Tidak perlu memilih lahan.',
          ),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.spTint2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.spPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.spInk3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
