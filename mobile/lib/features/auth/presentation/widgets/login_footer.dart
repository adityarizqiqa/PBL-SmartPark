import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Kaki halaman: penanda keamanan dan identitas institusi.
class LoginFooter extends StatelessWidget {
  const LoginFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppColors.spPrimary,
            ),
            SizedBox(width: 6),
            Text(
              'Keamanan Data Kampus Terenkripsi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.25,
                color: AppColors.spInk2,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          'SmartPark Official • Divisi K3L & Keamanan Kampus',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.spInk3,
          ),
        ),
      ],
    );
  }
}
