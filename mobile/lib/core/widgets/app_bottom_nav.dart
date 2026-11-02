import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Satu tujuan pada [AppBottomNav].
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Kerangka visual bottom navigation.
///
/// Tidak tahu rute apa pun: pemanggil menentukan [currentIndex] dan bereaksi
/// pada [onTap], sehingga tidak ada salinan navigasi di tiap layar.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
  });

  final int currentIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onTap;

  static const List<NavDestination> officerDestinations = [
    NavDestination(
      label: 'Beranda',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    NavDestination(
      label: 'Kendaraan',
      icon: Icons.directions_car_outlined,
      activeIcon: Icons.directions_car_rounded,
    ),
    NavDestination(
      label: 'Riwayat',
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
    ),
  ];

  static const List<NavDestination> supervisorDestinations = [
    NavDestination(
      label: 'Beranda',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    NavDestination(
      label: 'Lahan',
      icon: Icons.local_parking_outlined,
      activeIcon: Icons.local_parking_rounded,
    ),
    NavDestination(
      label: 'Shift',
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule_rounded,
    ),
    NavDestination(
      label: 'Petugas',
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
    ),
    NavDestination(
      label: 'Keluar',
      icon: Icons.logout_rounded,
      activeIcon: Icons.logout_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        border: const Border(
          top: BorderSide(color: AppColors.spBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.md),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: AppColors.spSurface,
        selectedItemColor: AppColors.spPrimary,
        unselectedItemColor: AppColors.spInk3,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: [
          for (final destination in destinations)
            BottomNavigationBarItem(
              icon: Icon(destination.icon),
              activeIcon: Icon(destination.activeIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
