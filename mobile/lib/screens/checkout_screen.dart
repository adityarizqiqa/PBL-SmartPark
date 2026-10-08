import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'beranda_screen.dart';
import 'kendaraan_screen.dart';
import 'riwayat_screen.dart';

/// Screen for Check-Out Flow & Vehicle Verification
/// Mapped from Figma prototypes:
/// - 06-checkout-verifikasi-kendaraan.html (Check-Out: Verifikasi Kendaraan & KTM)
/// - 13-verifikasi-manual-petugas.html (Verifikasi Manual Petugas)
class CheckOutScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;
  final String nim;
  final String checkInPlate;
  final String checkInTime;

  const CheckOutScreen({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
    this.nim = '244107020204',
    this.checkInPlate = 'N 1234 ABC',
    this.checkInTime = '07:32 WIB',
  });

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  int _selectedNavIndex = 0;

  // Verification state
  bool _ktmChecked = false;
  bool _isMismatchMode = false; // Toggle to demonstrate manual verification
  final String _checkOutPlateNormal = 'N 1234 ABC';
  final String _checkOutPlateMismatch = 'N 1234 ABD';
  final String _checkOutTime = '10:56 WIB';
  final String _duration = '3j 24m';
  final String _sessionId = 'ID: PRK-240502-089';

  // Manual verification note controller
  final TextEditingController _manualNoteController = TextEditingController();
  bool _showManualForm = false;

  @override
  void dispose() {
    _manualNoteController.dispose();
    super.dispose();
  }

  String get _currentCheckOutPlate =>
      _isMismatchMode ? _checkOutPlateMismatch : _checkOutPlateNormal;

  bool get _isPlateMatched => widget.checkInPlate == _currentCheckOutPlate;

  void _handleConfirmCheckOut() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.spSuccessBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.spSuccess,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check-Out Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.spInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sesi parkir kendaraan $_currentCheckOutPlate telah selesai. Palang keluar terbuka otomatis.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.spInk2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Summary receipt card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.spTint1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.spTint3),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NIM PEMILIK',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        widget.nim,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.spInk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DURASI PARKIR',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        _duration,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.spPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'TARIF',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.spInk2),
                      ),
                      Text(
                        'Rp 0 (Gratis)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.spSuccessInk),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.spPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Selesai & Ke Beranda',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleManualClearance() {
    if (_manualNoteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text('Harap masukkan catatan verifikasi fisik terlebih dahulu.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: AppColors.spPrimary600),
            SizedBox(width: 8),
            Text('Konfirmasi Manual?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Anda menyetujui pelepasan kendaraan $_currentCheckOutPlate dengan verifikasi visual fisik STNK & KTM.',
          style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.spInk3)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _handleConfirmCheckOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buka Palang Manual'),
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
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTesterSelector(),
                        const SizedBox(height: 12),
                        _buildLiveStatusBanner(),
                        const SizedBox(height: 14),
                        _buildPlateComparisonCard(),
                        const SizedBox(height: 14),
                        _buildActiveSessionMetadata(),
                        const SizedBox(height: 14),
                        if (_isMismatchMode || _showManualForm) ...[
                          _buildManualVerificationSection(),
                          const SizedBox(height: 14),
                        ],
                        _buildActionControls(),
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

  /// 1. Canonical App Bar
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
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
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
                      const Text(
                        'Verifikasi Check-Out',
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
                onPressed: () {},
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

  /// 2. Mode Tester Selector
  Widget _buildTesterSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spTint2,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'VERIFIKASI CHECK-OUT',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.spPrimary600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'POS KELUAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.spInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.spTint5,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.spPrimary600,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Petugas: ${widget.officerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spPrimary800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Live Status Highlight Banner
  Widget _buildLiveStatusBanner() {
    final isMatched = _isPlateMatched;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMatched ? AppColors.spTint5 : AppColors.spDangerBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isMatched ? AppColors.spPrimary600 : AppColors.spDanger,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isMatched ? AppColors.spPrimary600 : AppColors.spDanger)
                      .withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isMatched ? Icons.shield_rounded : Icons.gpp_bad_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMatched ? 'SESUAI' : 'PERLU VERIFIKASI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: isMatched ? AppColors.spInkStrong : AppColors.spDangerInk,
                      ),
                    ),
                    // Small test case switcher button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isMismatchMode = !_isMismatchMode;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          _isMismatchMode ? 'Uji: Normal' : 'Uji: Selisih',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spInk2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isMatched
                      ? 'Plat kendaraan keluar sesuai dengan data rekaman saat check-in.'
                      : 'Karakter plat nomor keluar berbeda dengan rekaman check-in. Perlu verifikasi manual petugas.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: isMatched ? AppColors.spPrimary800 : AppColors.spDangerInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Side-by-Side Visual & Plate Comparison Card
  Widget _buildPlateComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.camera_alt_outlined, size: 18, color: AppColors.spPrimary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PERBANDINGAN PLAT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.spPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.spTint2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Kamera HP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spInk2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Two side-by-side columns
          Row(
            children: [
              // 1. Saat Masuk
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.spTint1,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.spTint3),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: const Text(
                              '1. MASUK',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.spPrimary600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.checkInTime,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Ingress Photo Preview
                      Container(
                        height: 96,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF213145),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/foto-plat-checkin.png',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Center(
                                child: Icon(Icons.photo_camera, color: Colors.white24, size: 28),
                              ),
                            ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xD9213145),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Foto Saat Masuk',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Plate Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF213145),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Plat Check-In',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFCBDBF5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.checkInPlate,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Saat Keluar
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isPlateMatched ? AppColors.spTint1 : AppColors.spDangerBg.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isPlateMatched ? AppColors.spTint3 : AppColors.spDanger.withValues(alpha: 0.5),
                      width: _isPlateMatched ? 1 : 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '2. KELUAR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _isPlateMatched ? AppColors.spPrimary : AppColors.spDangerInk,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _checkOutTime,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Egress Photo Preview
                      Container(
                        height: 96,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: const Color(0xFF213145),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              'assets/foto-plat-checkout.png',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Center(
                                child: Icon(Icons.photo_camera, color: Colors.white24, size: 28),
                              ),
                            ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xD9213145),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Foto Saat Keluar',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Plate Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF213145),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Plat Check-Out',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFCBDBF5),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_isPlateMatched)
                              Text(
                                _currentCheckOutPlate,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              )
                            else
                              // Highlighted mismatch character
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'N 1234 AB',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.spDanger,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text(
                                      'D',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 5. Session & Identity Metadata (Glance Zone)
  Widget _buildActiveSessionMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.storage_rounded, size: 18, color: AppColors.spPrimary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data Sesi Aktif',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.spInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.spTint5,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _sessionId,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spPrimary800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2-column, 6-cell grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaCell('NIM', widget.nim, flexWidth: true),
              _buildMetaCell('PLAT CHECK-IN', widget.checkInPlate, flexWidth: true, isBrand: true),
              _buildMetaCell('WAKTU MASUK', widget.checkInTime, flexWidth: true),
              _buildMetaCell('WAKTU SCAN KELUAR', _checkOutTime, flexWidth: true),
              _buildMetaCell('DURASI', _duration, flexWidth: true, isBrand: true),
              _buildMetaCell(
                'STATUS',
                _isPlateMatched ? 'Sesuai' : 'Perlu Verifikasi',
                flexWidth: true,
                isBrand: _isPlateMatched,
                isDanger: !_isPlateMatched,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaCell(
    String label,
    String value, {
    bool flexWidth = false,
    bool isBrand = false,
    bool isDanger = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = flexWidth ? (constraints.maxWidth - 8) / 2 : null;
        return Container(
          width: itemWidth,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDanger ? AppColors.spDangerBg : AppColors.spTint1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDanger ? AppColors.spDangerInk : AppColors.spInk2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDanger
                      ? AppColors.spDangerInk
                      : isBrand
                          ? AppColors.spPrimary600
                          : AppColors.spInk,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Optional Manual Verification Card (13-verifikasi-manual-petugas.html)
  Widget _buildManualVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_late_outlined, color: AppColors.spDanger, size: 20),
              SizedBox(width: 8),
              Text(
                'Verifikasi Manual Petugas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.spDangerInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lakukan pencocokan STNK dan KTM secara langsung bila ada selisih karakter plat.',
            style: TextStyle(fontSize: 12, color: AppColors.spInk2),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualNoteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tuliskan catatan verifikasi (contoh: STNK asli cocok dengan NIM, plat belakang pudar)...',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
              filled: true,
              fillColor: AppColors.spTint1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.spBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _handleManualClearance,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary700,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.verified_user_rounded, size: 18),
            label: const Text('Setujui Pelepasan Manual', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// 6. Action Controls (Checkbox & Confirm Button)
  Widget _buildActionControls() {
    return Column(
      children: [
        // KTM Inspection Checkbox Card
        InkWell(
          onTap: () {
            setState(() {
              _ktmChecked = !_ktmChecked;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66C2C7D0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _ktmChecked,
                  onChanged: (val) {
                    setState(() {
                      _ktmChecked = val ?? false;
                    });
                  },
                  activeColor: AppColors.spPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'KTM telah diperiksa secara visual',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spInk,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pastikan KTM yang ditunjukkan sesuai dengan mahasiswa sebelum menyelesaikan Check-Out.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.spInk2,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Confirm Button
        ElevatedButton.icon(
          onPressed: (_ktmChecked && _isPlateMatched) ? _handleConfirmCheckOut : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.spPrimary.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white70,
            elevation: (_ktmChecked && _isPlateMatched) ? 2 : 0,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text(
            'Konfirmasi Check-Out',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 10),

        const SizedBox(height: 8),

        TextButton.icon(
          onPressed: () {
            setState(() {
              _showManualForm = !_showManualForm;
            });
          },
          icon: Icon(
            _showManualForm ? Icons.keyboard_arrow_up : Icons.assignment_late_outlined,
            size: 16,
            color: AppColors.spPrimary600,
          ),
          label: Text(
            _showManualForm ? 'Sembunyikan Form Verifikasi Manual' : 'Buka Form Verifikasi Manual',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.spPrimary600,
            ),
          ),
        ),
      ],
    );
  }

  /// Canonical Bottom Navigation
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
