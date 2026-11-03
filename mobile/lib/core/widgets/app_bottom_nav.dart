import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Pesan tooltip/semantik item; bila null, dipakai [label].
  final String? tooltip;
}

/// Kerangka visual bottom navigation.
///
/// Tidak tahu rute apa pun: pemanggil menentukan [currentIndex] dan bereaksi
/// pada [onTap], sehingga tidak ada salinan navigasi di tiap layar.
/// [logoutIndex] menandai item aksi keluar: item itu dirender dengan
/// [ExcludeSemantics] agar screen reader tidak membacanya sebagai tab,
/// dan tooltip-nya diganti [logoutTooltip].
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.destinations,
    required this.onTap,
    this.logoutIndex,
    this.logoutTooltip = 'Keluar',
  });

  final int currentIndex;
  final List<NavDestination> destinations;
  final ValueChanged<int> onTap;

  /// Indeks item yang bertindak sebagai aksi (bukan tab), mis. Keluar.
  final int? logoutIndex;

  /// Tooltip/semantik khusus untuk item [logoutIndex].
  final String logoutTooltip;

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
      icon: Icons.map_outlined,
      activeIcon: Icons.map_rounded,
    ),
    NavDestination(
      label: 'Shift',
      icon: Icons.schedule_outlined,
      activeIcon: Icons.schedule_rounded,
    ),
    NavDestination(
      label: 'Petugas',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups_rounded,
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
          for (var i = 0; i < destinations.length; i++)
            _item(destinations[i], i == logoutIndex),
        ],
      ),
    );
  }

  BottomNavigationBarItem _item(NavDestination destination, bool isLogout) {
    final item = BottomNavigationBarItem(
      icon: Icon(destination.icon),
      activeIcon: Icon(destination.activeIcon),
      label: destination.label,
      tooltip: isLogout ? logoutTooltip : (destination.tooltip ?? destination.label),
    );
    if (!isLogout) return item;
    return BottomNavigationBarItem(
      icon: ExcludeSemantics(child: Icon(destination.icon)),
      activeIcon: ExcludeSemantics(child: Icon(destination.activeIcon)),
      label: destination.label,
      tooltip: logoutTooltip,
    );
  }
}
