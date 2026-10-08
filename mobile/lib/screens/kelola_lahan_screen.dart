import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/spv_app_bar.dart';
import '../widgets/spv_bottom_nav.dart';
import 'login_screen.dart';

/// Data model for a parking lot (lahan parkir)
class ParkingLotItem {
  final String code;
  String name;
  bool isActive;
  int openShifts;

  ParkingLotItem({
    required this.code,
    required this.name,
    this.isActive = true,
    this.openShifts = 0,
  });
}

/// Kelola Lahan Parkir — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/14-kelola-lahan.html
class KelolaLahanScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;

  const KelolaLahanScreen({
    super.key,
    this.officerName = 'Dewi Kartika',
    this.officerRole = 'Pengawas (SPV)',
  });

  @override
  State<KelolaLahanScreen> createState() => _KelolaLahanScreenState();
}

class _KelolaLahanScreenState extends State<KelolaLahanScreen> {
  final TextEditingController _kodeController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();

  final List<ParkingLotItem> _lots = [
    ParkingLotItem(
      code: 'POS-UTAMA',
      name: 'Pos Parkir Utama',
      isActive: true,
      openShifts: 1,
    ),
    ParkingLotItem(
      code: 'POS-CLIMBING',
      name: 'Pos Parkir Climbing',
      isActive: true,
    ),
    ParkingLotItem(
      code: 'POS-FT',
      name: 'Pos Parkir Fakultas Teknik',
      isActive: false,
    ),
  ];

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  int get _activeCount => _lots.where((lot) => lot.isActive).length;
  int get _inactiveCount => _lots.where((lot) => !lot.isActive).length;

  void _showFeedback(String title, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.spDanger : AppColors.spPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.info_outline,
              color: Colors.white,
            ),
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

  void _handleAdd() {
    final code = _kodeController.text.trim().toUpperCase();
    final name = _namaController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      _showFeedback(
        'Data belum lengkap',
        'Kode dan nama lahan wajib diisi.',
        isError: true,
      );
      return;
    }

    if (_lots.any((lot) => lot.code == code)) {
      _showFeedback(
        'Kode sudah dipakai',
        'Kode lahan $code sudah terdaftar.',
        isError: true,
      );
      return;
    }

    setState(() {
      _lots.add(ParkingLotItem(code: code, name: name));
    });
    _kodeController.clear();
    _namaController.clear();
    FocusScope.of(context).unfocus();
    _showFeedback('Lahan ditambahkan', '$name ($code) berhasil ditambahkan.');
  }

  void _toggleActive(ParkingLotItem lot) {
    if (lot.isActive && lot.openShifts > 0) {
      _showFeedback(
        'Tidak bisa dinonaktifkan',
        'Tutup ${lot.openShifts} shift terbuka di lahan ini terlebih dahulu.',
        isError: true,
      );
      return;
    }

    setState(() {
      lot.isActive = !lot.isActive;
    });
    _showFeedback(
      lot.isActive ? 'Lahan diaktifkan' : 'Lahan dinonaktifkan',
      lot.isActive
          ? '${lot.name} kembali muncul saat mulai bertugas.'
          : '${lot.name} disembunyikan dari daftar pilih saat mulai bertugas.',
    );
  }

  Future<void> _editLot(ParkingLotItem lot) async {
    final controller = TextEditingController(text: lot.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_location_alt_outlined,
                color: AppColors.spPrimary, size: 22),
            SizedBox(width: 10),
            Text(
              'Ubah Nama Lahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.spInk,
          ),
          decoration: InputDecoration(
            labelText: 'Nama Lahan',
            filled: true,
            fillColor: AppColors.spTint1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.spInk3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    final trimmed = newName?.trim() ?? '';
    if (trimmed.isNotEmpty && trimmed != lot.name) {
      setState(() {
        lot.name = trimmed;
      });
      _showFeedback('Lahan diperbarui', 'Nama lahan menjadi "$trimmed".');
    }
    controller.dispose();
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Keluar dari Konsol Pengawas?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.spInk,
          ),
        ),
        content: const Text(
          'Anda akan kembali ke halaman masuk.',
          style: TextStyle(fontSize: 14, color: AppColors.spInk2, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.spInk3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spDanger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.spBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                SpvAppBar(pageTitle: 'Kelola Lahan', onLogout: _handleLogout),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeading(),
                        const SizedBox(height: 16),
                        _buildStatsRow(),
                        const SizedBox(height: 16),
                        _buildAddForm(),
                        const SizedBox(height: 16),
                        _buildLotList(),
                        const SizedBox(height: 16),
                        _buildNote(),
                        const SizedBox(height: 16),
                      ],
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

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Kelola Lahan\nParkir',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
            color: AppColors.spInk,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Tambah, ubah, dan nonaktifkan lahan parkir kampus',
          style: TextStyle(fontSize: 13, color: AppColors.spInk2),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            value: '${_lots.length}',
            label: 'LAHAN',
            valueColor: AppColors.spPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '$_activeCount',
            label: 'AKTIF',
            valueColor: AppColors.spSuccessInk,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: '$_inactiveCount',
            label: 'NONAKTIF',
            valueColor: AppColors.spInk3,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
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
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.spInk3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Lahan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.spTint3,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BARU',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.spInk2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Kode Lahan'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _kodeController,
            hint: 'cth: POS-UTAMA',
            icon: Icons.tag_rounded,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Nama Lahan'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _namaController,
            hint: 'cth: Pos Parkir Utama',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _handleAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Tambah Lahan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.spPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 14, color: AppColors.spInk3),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Kode lahan harus unik. Kode dinormalisasi menjadi huruf besar.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.spInk3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.spInk,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.spInk,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.spInk4,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.spInk2),
        filled: true,
        fillColor: AppColors.spTint1,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.spPrimary600, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLotList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Lahan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
            Text(
              '${_lots.length} lahan terdaftar',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._lots.map(_buildLotCard),
      ],
    );
  }

  Widget _buildLotCard(ParkingLotItem lot) {
    final hasOpenShift = lot.openShifts > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.spBorder),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lot.code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.spInk3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lot.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: lot.isActive ? AppColors.spTint3 : AppColors.spDangerBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  lot.isActive ? 'AKTIF' : 'NONAKTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: lot.isActive
                        ? AppColors.spInk2
                        : AppColors.spDangerInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: hasOpenShift ? AppColors.spSuccessBg : AppColors.spTint1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasOpenShift
                        ? AppColors.spSuccess
                        : AppColors.spInk4,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasOpenShift
                      ? 'Shift terbuka: ${lot.openShifts}'
                      : 'Tidak ada shift terbuka',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: hasOpenShift
                        ? AppColors.spSuccessInk
                        : AppColors.spInk2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editLot(lot),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Ubah'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.spTint2,
                    foregroundColor: AppColors.spInk,
                    side: const BorderSide(color: AppColors.spBorderMid),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _toggleActive(lot),
                  icon: Icon(
                    lot.isActive
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(lot.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.spTint1,
                    foregroundColor: AppColors.spPrimary,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.spTint3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.spPrimary700,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Lahan tidak pernah dihapus. Menonaktifkan lahan menyembunyikannya dari daftar pilih saat mulai bertugas, dan mencegah shift baru dibuka di lahan itu.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.spInk2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return SpvBottomNav(
      currentIndex: 1,
      officerName: widget.officerName,
      officerRole: widget.officerRole,
      onLogout: _handleLogout,
    );
  }
}
