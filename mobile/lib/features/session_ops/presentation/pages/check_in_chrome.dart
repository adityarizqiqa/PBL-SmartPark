part of 'check_in_page.dart';

extension _CheckInChrome on _CheckInPageState {
    Widget _buildAppBar() {
      String pageTitle = 'Scan KTM Mahasiswa';
      if (_currentStep == 10) pageTitle = 'Verifikasi Mahasiswa';
      if (_currentStep == 2) pageTitle = 'Scan Plat Kendaraan';
      if (_currentStep == 3) pageTitle = 'Konfirmasi Check-In';

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
            // Lead with back button
            Expanded(
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_currentStep == 3) {
                        _setStep(2);
                      } else if (_currentStep == 2) {
                        _setStep(1);
                      } else if (_currentStep == 10) {
                        _setStep(1);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppColors.spPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.spPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.directions_car,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: const Text(
                                'SmartPark',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: AppColors.spPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
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
                            ),
                          ],
                        ),
                        Text(
                          pageTitle,
                          maxLines: 1,
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
              ),
            ),

            // Tools: Shift Badge & Settings
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.spSuccessBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spSuccess.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.spSuccess,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Shift Aktif',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spSuccessInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengaturan Perangkat POS')),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  color: AppColors.spInk3,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildBottomNav() {
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
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            if (index == 0) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (index == 1) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else if (index == 2) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } else {
              rebuild(() {
                _selectedNavIndex = index;
              });
            }
          },
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
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car_rounded),
              label: 'Kendaraan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
      );
    }
}
