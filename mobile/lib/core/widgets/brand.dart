import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Merek SmartPark bersama: logo 34x34, ikon 18, judul 15.
class SmartParkBrand extends StatelessWidget {
  const SmartParkBrand({super.key, required this.subtitle, this.tag});

  final String subtitle;
  final Widget? tag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.spPrimary,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Center(
            child: Icon(Icons.directions_car, size: 18, color: Colors.white),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      'SmartPark',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.spPrimary,
                      ),
                    ),
                  ),
                  if (tag != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    tag!,
                  ],
                ],
              ),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

/// Label kecil "Campus" di samping judul SmartPark.
class CampusTag extends StatelessWidget {
  const CampusTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.spTint2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Campus',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.spPrimary600,
        ),
      ),
    );
  }
}

/// Pil peran kecil: "SPV" untuk pengawas.
class RolePill extends StatelessWidget {
  const RolePill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.spTint2,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.spPrimary600,
        ),
      ),
    );
  }
}
