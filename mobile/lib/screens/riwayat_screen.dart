import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'beranda_screen.dart';
import 'kendaraan_screen.dart';

enum RiwayatStatusType {
  sesuai,
  verifikasiManual,
  ditolakAktif,
}

/// Data model for parking history transaction session
class ParkingHistoryItem {
  final String id;
  final String plateNumber;
  final String? attemptedExitPlate;
  final String nim;
  final String ownerName;
  final RiwayatStatusType statusType;
  final String entryTime;
  final String exitTime;
  final String duration;
  final String? note;
  final String gateName;

  const ParkingHistoryItem({
    required this.id,
    required this.plateNumber,
    this.attemptedExitPlate,
    required this.nim,
    required this.ownerName,
    required this.statusType,
    required this.entryTime,
    required this.exitTime,
    required this.duration,
    this.note,
    this.gateName = 'Pos Parkir Utama',
  });
}

/// Screen 04 — Riwayat Sesi Parkir
/// Mapped from Figma node 15:608 (tmp/uiux/04-riwayat-transaksi-parkir.html)
class RiwayatScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;

  const RiwayatScreen({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
  });

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedPeriodIndex = 0; // 0: Hari Ini, 1: Kemarin, 2: Pilih Tanggal
  int _selectedStatusTabIndex = 0; // 0: Semua, 1: Sesuai, 2: Verifikasi Manual, 3: Aktif
  int _selectedNavIndex = 2; // 2: Riwayat

  // Master history sessions list
  final List<ParkingHistoryItem> _allHistory = const [
    ParkingHistoryItem(
      id: '#089',
      plateNumber: 'N 1234 ABC',
      nim: '244107020204',
      ownerName: 'Ahmad Faiz Fauzan',
      statusType: RiwayatStatusType.sesuai,
      entryTime: '07:32 WIB',
      exitTime: '10:56 WIB',
      duration: '3j 24m',
      gateName: 'Pos Parkir Climbing',
    ),
    ParkingHistoryItem(
      id: '#077',
      plateNumber: 'B 3821 SDE',
      nim: '214172019901',
      ownerName: 'Rian Saputra',
      statusType: RiwayatStatusType.verifikasiManual,
      entryTime: '08:15 WIB',
      exitTime: '11:20 WIB',
      duration: '3j 05m',
      note: 'Catatan: KTM fisik diperiksa petugas pos',
      gateName: 'Pos Parkir Climbing',
    ),
    ParkingHistoryItem(
      id: '#062',
      plateNumber: 'N 8890 XY',
      attemptedExitPlate: 'B 9988 XYZ',
      nim: '204172018889',
      ownerName: 'Siti Rahmawati',
      statusType: RiwayatStatusType.ditolakAktif,
      entryTime: '06:50 WIB',
      exitTime: '12:10 WIB (Upaya)',
      duration: '5j 20m',
      note: 'Status: Check-out ditolak — sesi tetap aktif',
      gateName: 'Pos Parkir Climbing',
    ),
    ParkingHistoryItem(
      id: '#054',
      plateNumber: 'N 8921 DEF',
      nim: '234107020118',
      ownerName: 'Nabila Putri Cahyani',
      statusType: RiwayatStatusType.sesuai,
      entryTime: '08:51 WIB',
      exitTime: '10:00 WIB',
      duration: '1j 09m',
      gateName: 'Pos Gerbang Timur',
    ),
    ParkingHistoryItem(
      id: '#042',
      plateNumber: 'L 1945 POL',
      nim: '244107020015',
      ownerName: 'Bayu Arya Permana',
      statusType: RiwayatStatusType.sesuai,
      entryTime: '09:12 WIB',
      exitTime: '11:30 WIB',
      duration: '2j 18m',
      gateName: 'Pos Parkir Utama',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ParkingHistoryItem> get _filteredHistory {
    final query = _searchController.text.trim().toLowerCase();
    return _allHistory.where((item) {
      // Filter by status tab
      if (_selectedStatusTabIndex == 1 && item.statusType != RiwayatStatusType.sesuai) {
        return false;
      }
      if (_selectedStatusTabIndex == 2 && item.statusType != RiwayatStatusType.verifikasiManual) {
        return false;
      }
      if (_selectedStatusTabIndex == 3 && item.statusType != RiwayatStatusType.ditolakAktif) {
        return false;
      }

      if (query.isEmpty) return true;

      return item.id.toLowerCase().contains(query) ||
          item.plateNumber.toLowerCase().contains(query) ||
          item.nim.toLowerCase().contains(query) ||
          item.ownerName.toLowerCase().contains(query);
    }).toList();
  }

  void _showDetailModal(ParkingHistoryItem item) {
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

              // Title row with session ID
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
                          Icons.receipt_long_rounded,
                          color: AppColors.spPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Detail Sesi ${item.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.spInk,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusPill(item.statusType),
                ],
              ),

              const SizedBox(height: 16),

              // Plate Container
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
                        item.plateNumber,
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
                          'Durasi Parkir',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.spInk3,
                          ),
                        ),
                        Text(
                          item.duration,
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

              if (item.attemptedExitPlate != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x99FFF1F2),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFBE123C)),
                          SizedBox(width: 6),
                          Text(
                            'Upaya Check-Out:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFBE123C),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.attemptedExitPlate!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _buildDetailInfoTile(
                icon: Icons.badge_outlined,
                title: 'NIM Mahasiswa',
                value: item.nim,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.person_outline,
                title: 'Nama Pemilik',
                value: item.ownerName,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.login_rounded,
                title: 'Waktu Masuk',
                value: item.entryTime,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.logout_rounded,
                title: 'Waktu Keluar',
                value: item.exitTime,
              ),
              const Divider(height: 14, color: AppColors.spBorderSoft),
              _buildDetailInfoTile(
                icon: Icons.location_on_outlined,
                title: 'Pos Gerbang',
                value: item.gateName,
              ),

              if (item.note != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.statusType == RiwayatStatusType.verifikasiManual
                        ? AppColors.spWarnBg
                        : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: item.statusType == RiwayatStatusType.verifikasiManual
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFFECDD3),
                    ),
                  ),
                  child: Text(
                    item.note!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: item.statusType == RiwayatStatusType.verifikasiManual
                          ? const Color(0xFF78350F)
                          : const Color(0xFF9F1239),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.spPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
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

  Widget _buildStatusPill(RiwayatStatusType type) {
    Color bg;
    Color textColor;
    IconData icon;
    String label;

    switch (type) {
      case RiwayatStatusType.sesuai:
        bg = AppColors.spSuccessBg;
        textColor = AppColors.spSuccessInk;
        icon = Icons.check_circle_rounded;
        label = 'Sesuai';
        break;
      case RiwayatStatusType.verifikasiManual:
        bg = AppColors.spWarnBg;
        textColor = AppColors.spWarn;
        icon = Icons.warning_amber_rounded;
        label = 'Verifikasi Manual';
        break;
      case RiwayatStatusType.ditolakAktif:
        bg = const Color(0xFFFFF1F2);
        textColor = const Color(0xFFBE123C);
        icon = Icons.cancel_rounded;
        label = 'Aktif';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
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
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
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
    final filtered = _filteredHistory;

    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPosBanner(),
                          const SizedBox(height: 14),
                          _buildDailySummaryStats(),
                          const SizedBox(height: 14),
                          _buildPeriodFilters(),
                          const SizedBox(height: 12),
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildStatusTabs(),
                          const SizedBox(height: 14),
                          _buildSessionCardsList(filtered),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Top Canonical App Bar
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
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.spPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.directions_car, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
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
                        'Riwayat Sesi',
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
                onPressed: () => _showFeedback('Pengaturan', 'Koneksi pos normal.'),
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

  /// 2. Banner / Kartu Info Pos
  Widget _buildPosBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spInfoBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'RIWAYAT SESI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppColors.spPrimary700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Pos Operasional',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.spInk2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Riwayat Sesi Parkir',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: AppColors.spNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Shared Device • ${widget.parkingLot}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.spSlate,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Statistik Ringkasan Harian
  Widget _buildDailySummaryStats() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryBox(
              label: 'TOTAL',
              value: '852',
              bg: const Color(0xFFF8FAFC),
              textColor: AppColors.spPrimary,
              labelColor: AppColors.spInk3,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSummaryBox(
              label: 'SESUAI',
              value: '835',
              bg: const Color(0x66ECFDF5),
              textColor: AppColors.spSuccessInk,
              labelColor: AppColors.spSuccessInk,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSummaryBox(
              label: 'MANUAL',
              value: '11',
              bg: const Color(0x66FFFBEB),
              textColor: AppColors.spWarn,
              labelColor: AppColors.spWarn,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSummaryBox(
              label: 'AKTIF',
              value: '6',
              bg: const Color(0x66FFF1F2),
              textColor: const Color(0xFFBE123C),
              labelColor: const Color(0xFF9F1239),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required Color bg,
    required Color textColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Filter Periode (Hari Ini, Kemarin, Pilih Tanggal)
  Widget _buildPeriodFilters() {
    final periods = ['Hari Ini', 'Kemarin', 'Pilih Tanggal'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriodIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPeriodIndex = index;
                });
                if (index == 2) {
                  _showFeedback('Pilih Tanggal', 'Kalender pemilihan rentang waktu dibuka.');
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.spPrimary : AppColors.spSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.spPrimary : AppColors.spBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 2) ...[
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: isSelected ? Colors.white : AppColors.spSlate,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      periods[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.spSlate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 5. Kolom Pencarian
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Cari NIM atau Plat Nomor...',
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  /// 6. Filter Status Tab
  Widget _buildStatusTabs() {
    final tabs = ['Semua', 'Sesuai', 'Verifikasi Manual', 'Aktif'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedStatusTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedStatusTabIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.spPrimary : AppColors.spSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.spPrimary : AppColors.spBorder,
                  ),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.spSlate,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 7. Riwayat Sesi List
  Widget _buildSessionCardsList(List<ParkingHistoryItem> historyList) {
    if (historyList.isEmpty) {
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
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.spInk4),
            SizedBox(height: 12),
            Text(
              'Tidak ada sesi ditemukan',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.spInk),
            ),
            SizedBox(height: 4),
            Text(
              'Coba ubah kata kunci pencarian atau tab status yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.spInk3),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: historyList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = historyList[index];
        return _buildSessionCard(item);
      },
    );
  }

  Widget _buildSessionCard(ParkingHistoryItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.spBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Badges & ID
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildStatusPill(item.statusType),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.statusType == RiwayatStatusType.ditolakAktif
                            ? const Color(0xFFFFF1F2)
                            : item.statusType == RiwayatStatusType.verifikasiManual
                                ? AppColors.spWarnBg
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.statusType == RiwayatStatusType.ditolakAktif
                            ? 'Sesi Masih Aktif'
                            : item.statusType == RiwayatStatusType.verifikasiManual
                                ? 'Disetujui Manual'
                                : 'Sesi Selesai',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.statusType == RiwayatStatusType.ditolakAktif
                              ? const Color(0xFFBE123C)
                              : item.statusType == RiwayatStatusType.verifikasiManual
                                  ? AppColors.spWarn
                                  : AppColors.spSlate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.id,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.spInk3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Plate section (Normal vs Compare if rejected)
          if (item.statusType == RiwayatStatusType.ditolakAktif && item.attemptedExitPlate != null)
            _buildComparePlateSection(item)
          else
            _buildStandardPlateSection(item),

          const SizedBox(height: 10),

          // NIM Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xCCE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.badge_outlined, size: 14, color: AppColors.spPrimary700),
                    SizedBox(width: 6),
                    Text(
                      'NIM Mahasiswa:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.spSlate),
                    ),
                  ],
                ),
                Text(
                  item.nim,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          if (item.note != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: item.statusType == RiwayatStatusType.verifikasiManual
                    ? const Color(0xCCFFFBEB)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: item.statusType == RiwayatStatusType.verifikasiManual
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFFECDD3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.statusType == RiwayatStatusType.verifikasiManual
                        ? Icons.info_outline
                        : Icons.cancel_outlined,
                    size: 14,
                    color: item.statusType == RiwayatStatusType.verifikasiManual
                        ? const Color(0xFF78350F)
                        : const Color(0xFF9F1239),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.note!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: item.statusType == RiwayatStatusType.verifikasiManual
                            ? const Color(0xFF78350F)
                            : const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Times Panel (Masuk | Keluar | Durasi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.spInfoBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'MASUK',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.entryTime,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFFBFDBFE)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.statusType == RiwayatStatusType.ditolakAktif ? 'UPAYA KELUAR' : 'KELUAR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: item.statusType == RiwayatStatusType.ditolakAktif
                              ? const Color(0xFFBE123C)
                              : AppColors.spInk2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.exitTime,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.statusType == RiwayatStatusType.ditolakAktif
                              ? const Color(0xFFBE123C)
                              : AppColors.spNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFFBFDBFE)),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.statusType == RiwayatStatusType.ditolakAktif ? 'DURASI JALAN' : 'DURASI PARKIR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: item.statusType == RiwayatStatusType.ditolakAktif
                              ? const Color(0xFFBE123C)
                              : AppColors.spPrimary700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.duration,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.statusType == RiwayatStatusType.ditolakAktif
                              ? const Color(0xFFBE123C)
                              : AppColors.spPrimary700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Detail Sesi Button
          InkWell(
            onTap: () => _showDetailModal(item),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.spInfoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Lihat Detail Sesi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.spPrimary),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.spPrimary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardPlateSection(ParkingHistoryItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xCCF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xCCE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.spInfoBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: const Icon(Icons.directions_car_rounded, size: 16, color: AppColors.spPrimary700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLAT TERVERIFIKASI',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.spInk3),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.spNavy,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.plateNumber,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            item.statusType == RiwayatStatusType.verifikasiManual
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            size: 20,
            color: item.statusType == RiwayatStatusType.verifikasiManual
                ? const Color(0xFFD97706)
                : AppColors.spSuccess,
          ),
        ],
      ),
    );
  }

  Widget _buildComparePlateSection(ParkingHistoryItem item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x99FFF1F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.access_time_rounded, size: 14, color: AppColors.spSlate),
                  SizedBox(width: 4),
                  Text(
                    'Plat Check-In:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.spSlate),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.spNavy,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.plateNumber,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12, color: Color(0xCCFECDD3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.cancel_rounded, size: 14, color: Color(0xFFE11D48)),
                  SizedBox(width: 4),
                  Text(
                    'Upaya Check-Out:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFBE123C)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.attemptedExitPlate ?? '-',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 8. Canonical Bottom Navigation
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
          } else if (index == 1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => KendaraanScreen(
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
            if (index != 2) {
              final titles = ['Beranda', 'Kendaraan', 'Riwayat', 'Pengaturan'];
              _showFeedback(titles[index], 'Navigasi ke halaman ${titles[index]}');
            }
          }
        },
        backgroundColor: AppColors.spSurface,
        selectedItemColor: AppColors.spPrimary,
        unselectedItemColor: AppColors.spInk3,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
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
