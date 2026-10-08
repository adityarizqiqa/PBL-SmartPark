import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'beranda_screen.dart';
import 'riwayat_screen.dart';

/// Data model for an active parked vehicle
class ParkedVehicleItem {
  final String nim;
  final String plateNumber;
  final String ownerName;
  final String duration;
  final String entryTime;
  final String entryGate;
  final bool isRejected;
  final String? rejectionReason;

  const ParkedVehicleItem({
    required this.nim,
    required this.plateNumber,
    required this.ownerName,
    required this.duration,
    required this.entryTime,
    required this.entryGate,
    this.isRejected = false,
    this.rejectionReason,
  });
}

/// Screen 12 — Kendaraan Sedang Parkir
/// Mapped from Figma node 15:2170 (tmp/uiux/12-kendaraan-sedang-parkir.html)
class KendaraanScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;

  const KendaraanScreen({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
  });

  @override
  State<KendaraanScreen> createState() => _KendaraanScreenState();
}

class _KendaraanScreenState extends State<KendaraanScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilterIndex = 0; // 0: Semua, 1: Check-out Ditolak
  int _selectedNavIndex = 1; // 1: Kendaraan

  // Master parked vehicles data from prototype
  final List<ParkedVehicleItem> _allVehicles = const [
    ParkedVehicleItem(
      nim: '244107020204',
      plateNumber: 'N 1234 ABC',
      ownerName: 'Ahmad Faiz Fauzan',
      duration: '3j 24m',
      entryTime: '07:32 WIB',
      entryGate: 'Pos Parkir Climbing',
      isRejected: false,
    ),
    ParkedVehicleItem(
      nim: '223105010042',
      plateNumber: 'B 3821 SDE',
      ownerName: 'Muhammad Rizki Pratama',
      duration: '2j 41m',
      entryTime: '08:15 WIB',
      entryGate: 'Pos Parkir Climbing',
      isRejected: false,
    ),
    ParkedVehicleItem(
      nim: '204172018889',
      plateNumber: 'N 8890 XY',
      ownerName: 'Siti Rahmawati',
      duration: '4j 06m',
      entryTime: '06:50 WIB',
      entryGate: 'Pos Parkir Climbing',
      isRejected: false,
    ),
    ParkedVehicleItem(
      nim: '214107020055',
      plateNumber: 'B 4567 KLA',
      ownerName: 'Dimas Aditya Nugraha',
      duration: '1j 18m',
      entryTime: '08:42 WIB',
      entryGate: 'Pos Parkir Utama',
      isRejected: true,
      rejectionReason: 'Plat nomor tidak sesuai data KTM saat tap keluar',
    ),
    ParkedVehicleItem(
      nim: '234107020118',
      plateNumber: 'N 8921 DEF',
      ownerName: 'Nabila Putri Cahyani',
      duration: '1j 09m',
      entryTime: '08:51 WIB',
      entryGate: 'Pos Gerbang Timur',
      isRejected: false,
    ),
    ParkedVehicleItem(
      nim: '244107020015',
      plateNumber: 'L 1945 POL',
      ownerName: 'Bayu Arya Permana',
      duration: '0j 48m',
      entryTime: '09:12 WIB',
      entryGate: 'Pos Parkir Utama',
      isRejected: false,
    ),
    ParkedVehicleItem(
      nim: '224107020301',
      plateNumber: 'AG 5541 VZ',
      ownerName: 'Fajar Eka Saputra',
      duration: '2j 05m',
      entryTime: '07:55 WIB',
      entryGate: 'Pos Parkir Fakultas Teknik',
      isRejected: true,
      rejectionReason: 'Masa berlaku STNK perlu verifikasi fisik',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ParkedVehicleItem> get _filteredVehicles {
    final query = _searchController.text.trim().toLowerCase();
    return _allVehicles.where((vehicle) {
      final matchesFilter = _selectedFilterIndex == 0 ||
          (_selectedFilterIndex == 1 && vehicle.isRejected);

      if (!matchesFilter) return false;

      if (query.isEmpty) return true;

      return vehicle.nim.toLowerCase().contains(query) ||
          vehicle.plateNumber.toLowerCase().contains(query) ||
          vehicle.ownerName.toLowerCase().contains(query);
    }).toList();
  }

  int get _rejectedCount =>
      _allVehicles.where((v) => v.isRejected).length;

  void _showDetailModal(ParkedVehicleItem vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.spBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row with status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.spTint3,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.spPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Detail Sesi Parkir',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.spInk,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: vehicle.isRejected ? AppColors.spDangerBg : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          vehicle.isRejected ? Icons.error_outline : Icons.check_circle_rounded,
                          size: 13,
                          color: vehicle.isRejected ? AppColors.spDangerInk : AppColors.spSuccessInk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          vehicle.isRejected ? 'Perlu Verifikasi' : 'Sedang Parkir',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: vehicle.isRejected ? AppColors.spDangerInk : AppColors.spSuccessInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // License Plate Highlight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF213145),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vehicle.plateNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Durasi Berjalan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spInk3,
                          ),
                        ),
                        Text(
                          vehicle.duration,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.spPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Detailed metadata list
              _buildDetailInfoTile(
                icon: Icons.badge_outlined,
                title: 'NIM Mahasiswa',
                value: vehicle.nim,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.person_outline,
                title: 'Nama Pemilik',
                value: vehicle.ownerName,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.access_time_rounded,
                title: 'Waktu Check-In',
                value: vehicle.entryTime,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.location_on_outlined,
                title: 'Pos Masuk',
                value: vehicle.entryGate,
              ),

              if (vehicle.isRejected && vehicle.rejectionReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.spDangerBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.spDangerInk, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vehicle.rejectionReason!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spDangerInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.spBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          color: AppColors.spInk2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showFeedback(
                          'Verifikasi Manual',
                          'Membuka sesi verifikasi petugas untuk plat ${vehicle.plateNumber}.',
                        );
                      },
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('Verifikasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.spPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.spPrimary600),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.spInk3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.spInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _showFeedback(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.spPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVehicles;

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Stack(
              children: [
                Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.spPrimary,
                        onRefresh: () async {
                          await Future.delayed(const Duration(milliseconds: 400));
                          if (mounted) setState(() {});
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeading(),
                              const SizedBox(height: 16),
                              _buildFilterBar(),
                              const SizedBox(height: 16),
                              _buildVehicleCardsList(filtered),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildBottomNav(),
                  ],
                ),

                // Floating Action Button: Scan Check-Out
                Positioned(
                  right: 16,
                  bottom: 74,
                  child: _buildFloatingScanButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Top Canonical App Bar with Back Button
  Widget _buildAppBar() {
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
                // Back Button
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => BerandaScreen(
                          officerName: widget.officerName,
                          officerRole: widget.officerRole,
                          isSupervisor: widget.isSupervisor,
                          parkingLot: widget.parkingLot,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  color: AppColors.spInk,
                  tooltip: 'Kembali ke Beranda',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),

                // Logo
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.spPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.directions_car,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title
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
                                fontSize: 15,
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
                      const Text(
                        'Kendaraan Parkir',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
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

          // Tools: Shift Badge & Devices Icon
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
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.spSuccess,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Shift Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spSuccessInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _showFeedback(
                  'Pengaturan Perangkat',
                  'Pos Gerbang terkoneksi normal.',
                ),
                icon: const Icon(Icons.settings_outlined, size: 20),
                color: AppColors.spInk3,
                tooltip: 'Pengaturan',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Heading: Title + Total Sesi Aktif
  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kendaraan Sedang\nParkir',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
            color: AppColors.spInk,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              size: 15,
              color: AppColors.spPrimary600,
            ),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.spInk2,
                ),
                children: [
                  const TextSpan(text: 'Total '),
                  TextSpan(
                    text: '${_allVehicles.length} ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.spPrimary,
                    ),
                  ),
                  const TextSpan(text: 'Sesi Aktif'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. Search Bar + Filter Chips
  Widget _buildFilterBar() {
    return Column(
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari NIM atau Plat Nomor...',
              hintStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.spInk4,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.spInk4,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.spBorderSoft),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.spBorderSoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.spPrimary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Horizontal Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                index: 0,
                label: 'Semua (${_allVehicles.length})',
                icon: Icons.format_list_bulleted_rounded,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                index: 1,
                label: 'Check-out Ditolak ($_rejectedCount)',
                icon: Icons.error_outline_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isActive = _selectedFilterIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilterIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.spPrimary : AppColors.spTint1,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : AppColors.spInk2,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.spInk2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 4. Vehicle Cards List
  Widget _buildVehicleCardsList(List<ParkedVehicleItem> vehicles) {
    if (vehicles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.spSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.spBorder),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.spInk4,
            ),
            SizedBox(height: 12),
            Text(
              'Tidak ada kendaraan ditemukan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Coba ubah kata kunci pencarian atau filter yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        return _buildVehicleCard(vehicle);
      },
    );
  }

  Widget _buildVehicleCard(ParkedVehicleItem vehicle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vehicle.isRejected
              ? AppColors.spDanger.withValues(alpha: 0.35)
              : const Color(0x4DC2C7D0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Vehicle Icon + NIM + Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.spTint3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.spPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NIM',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.spInk2,
                            ),
                          ),
                          Text(
                            vehicle.nim,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status Pill
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: vehicle.isRejected ? AppColors.spDangerBg : const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        vehicle.isRejected ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                        size: 12,
                        color: vehicle.isRejected ? AppColors.spDangerInk : AppColors.spSuccessInk,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          vehicle.isRejected ? 'Check-out Ditolak' : 'Sedang Parkir',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: vehicle.isRejected ? AppColors.spDangerInk : AppColors.spSuccessInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Physical Plate Pill + Durasi Berjalan
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.spTint1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Plate container
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF213145),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      vehicle.plateNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Durasi Berjalan',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.spInk2,
                      ),
                    ),
                    Text(
                      vehicle.duration,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.spPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Row 3: Meta Info (Waktu Masuk & Pos Masuk)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x66D3E4FE), // rgba(211, 228, 254, 0.4)
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Waktu Masuk
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: AppColors.spPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waktu Masuk',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.spInk2,
                              ),
                            ),
                            Text(
                              vehicle.entryTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Pos Masuk
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.spPrimary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pos Masuk',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.spInk2,
                              ),
                            ),
                            Text(
                              vehicle.entryGate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.spInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Row 4: Detail Sesi Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () => _showDetailModal(vehicle),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.spTint3,
                foregroundColor: AppColors.spPrimary700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.assignment_outlined, size: 18),
              label: const Text(
                'Detail Sesi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Floating Action Button: Scan Check-Out
  Widget _buildFloatingScanButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showFeedback(
          'Scan Check-Out',
          'Membuka pemindai plat nomor untuk validasi keluar.',
        ),
        borderRadius: BorderRadius.circular(30),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.spPrimary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.spPrimary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.spPrimary600,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Scan Check-Out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Scan plat untuk mulai',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8FBDF0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 6. Canonical Bottom Navigation
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => BerandaScreen(
                  officerName: widget.officerName,
                  officerRole: widget.officerRole,
                  isSupervisor: widget.isSupervisor,
                  parkingLot: widget.parkingLot,
                ),
              ),
            );
          } else if (index == 2) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RiwayatScreen(
                  officerName: widget.officerName,
                  officerRole: widget.officerRole,
                  isSupervisor: widget.isSupervisor,
                  parkingLot: widget.parkingLot,
                ),
              ),
            );
          } else {
            setState(() {
              _selectedNavIndex = index;
            });
            if (index != 1) {
              final titles = ['Beranda', 'Kendaraan', 'Riwayat', 'Pengaturan'];
              _showFeedback(
                titles[index],
                'Navigasi ke halaman ${titles[index]}',
              );
            }
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
