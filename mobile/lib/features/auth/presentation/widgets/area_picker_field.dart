import 'package:flutter/material.dart';

import '../../../../core/entities/area.dart';
import '../../../../core/theme/app_colors.dart';

/// Pemilih lahan parkir; opsional untuk pengawas.
class AreaPickerField extends StatelessWidget {
  const AreaPickerField({
    super.key,
    required this.areas,
    required this.selected,
    required this.isSupervisor,
    required this.onSelected,
  });

  final List<Area> areas;
  final Area? selected;
  final bool isSupervisor;
  final ValueChanged<Area?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (isSupervisor) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Lahan Parkir',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.spInk,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.spInk3,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Area dipilih saat bergabung shift petugas.',
                  style: TextStyle(fontSize: 12, color: AppColors.spInk3),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const <Widget>[
            Text(
              'Pilih Lahan Parkir',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Diperlukan untuk petugas gerbang.',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: AppColors.spInk3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Area>(
          isExpanded: true,
          initialValue: selected,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.spTint1,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: AppColors.spInk2,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.spPrimary600,
                width: 1.5,
              ),
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.spInk2,
          ),
          items: [
            for (final area in areas)
              DropdownMenuItem<Area>(
                value: area,
                child: Text(
                  '${area.code} • ${area.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.spInk,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onSelected,
          validator: (value) {
            if (value == null) {
              return 'Pilih lahan parkir terlebih dahulu';
            }
            return null;
          },
        ),
      ],
    );
  }
}
