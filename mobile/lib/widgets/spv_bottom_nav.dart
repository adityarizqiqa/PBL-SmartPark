import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/beranda_spv_screen.dart';
import '../screens/kelola_lahan_screen.dart';
import '../screens/kelola_petugas_screen.dart';
import '../screens/kelola_shift_screen.dart';

/// Bottom navigation for the SPV (pengawas) console.
/// Mirrors the bottom nav used in tmp/uiux/14-16 screens.
class SpvBottomNav extends StatelessWidget {
  final int currentIndex;
  final String officerName;
  final String officerRole;
  final VoidCallback onLogout;

  const SpvBottomNav({
    super.key,
    required this.currentIndex,
    required this.officerName,
    required this.officerRole,
    required this.onLogout,
  });

  void _navigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => BerandaSpvScreen(
              officerName: officerName,
              officerRole: officerRole,
            ),
          ),
        );
        break;
      case 1:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => KelolaLahanScreen(
              officerName: officerName,
              officerRole: officerRole,
            ),
          ),
        );
        break;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => KelolaShiftScreen(
              officerName: officerName,
              officerRole: officerRole,
            ),
          ),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => KelolaPetugasScreen(
              officerName: officerName,
              officerRole: officerRole,
            ),
          ),
        );
        break;
      case 4:
        onLogout();
        break;
    }
  }

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
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => _navigate(context, index),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map_rounded),
            label: 'Lahan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            activeIcon: Icon(Icons.schedule_rounded),
            label: 'Shift',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups_rounded),
            label: 'Petugas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout_rounded),
            activeIcon: Icon(Icons.logout_rounded),
            label: 'Keluar',
          ),
        ],
      ),
    );
  }
}
