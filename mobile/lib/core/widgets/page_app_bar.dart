import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand.dart';

/// Bilah atas bersama untuk layar di dalam shell petugas.
///
/// Menampilkan merek, judul halaman, dan slot aksi di kanan; tombol kembali
/// hanya muncul bila [onBack] diberikan.
class PageAppBar extends StatelessWidget {
  const PageAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        border: const Border(
          bottom: BorderSide(color: AppColors.spBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (onBack != null) ...[
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    color: AppColors.spInk,
                    tooltip: 'Kembali',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: SmartParkBrand(
                    subtitle: title,
                    tag: const CampusTag(),
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Lencana "Shift Aktif" yang dipakai di beberapa bilah atas.
class ShiftActiveBadge extends StatelessWidget {
  const ShiftActiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.spSuccessBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spSuccess.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(),
          SizedBox(width: 5),
          Text(
            'Shift Aktif',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.spSuccessInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: AppColors.spSuccess,
        shape: BoxShape.circle,
      ),
    );
  }
}
