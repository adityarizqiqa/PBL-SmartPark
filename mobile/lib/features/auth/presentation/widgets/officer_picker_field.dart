import 'package:flutter/material.dart';

import '../../../../core/entities/officer.dart';
import '../../../../core/theme/app_colors.dart';

/// Daftar petugas sebagai pilihan tunggal (bukan dropdown) agar peran
/// terlihat langsung.
class OfficerPickerField extends StatelessWidget {
  const OfficerPickerField({
    super.key,
    required this.officers,
    required this.selected,
    required this.onSelected,
  });

  final List<Officer> officers;
  final Officer? selected;
  final ValueChanged<Officer> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nama Petugas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            Text(
              'Wajib Diisi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.spBorderMid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                for (var index = 0; index < officers.length; index++)
                  _OfficerRow(
                    officer: officers[index],
                    isSelected: officers[index].id == selected?.id,
                    isLast: index == officers.length - 1,
                    onTap: () => onSelected(officers[index]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pilih nama Anda. Peran menentukan menu yang muncul setelah masuk.',
          style: TextStyle(fontSize: 12, color: AppColors.spInk3),
        ),
      ],
    );
  }
}

class _OfficerRow extends StatelessWidget {
  const _OfficerRow({
    required this.officer,
    required this.isSelected,
    required this.isLast,
    required this.onTap,
  });

  final Officer officer;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            color: isSelected ? AppColors.spTint2 : Colors.transparent,
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: AppColors.spInk2,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        officer.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.spInk,
                        ),
                      ),
                      if (officer.isSupervisor) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.spTint3,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPV',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spPrimary600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.spPrimary,
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.spBorder,
          ),
      ],
    );
  }
}
