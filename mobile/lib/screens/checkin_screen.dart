import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import 'beranda_screen.dart';
import 'kendaraan_screen.dart';
import 'riwayat_screen.dart';

/// Screen for Check-In Vehicle Flow (Steps 1, 1-alt, 2, 3)
/// Mapped from Figma prototypes:
/// - 05-checkin-scan-ktm.html (Step 1: Scan KTM Mahasiswa)
/// - 09-checkin-verifikasi-mahasiswa.html (Step 1 Alternate: Input NIM Manual)
/// - 08-checkin-scan-plat.html (Step 2: Scan Plat Kendaraan)
/// - 10-checkin-konfirmasi-sukses.html (Step 3: Konfirmasi & Sukses Masuk)
class CheckInScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;
  final int initialStep; // 1: Scan KTM, 2: Scan Plat, 3: Konfirmasi

  const CheckInScreen({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
    this.initialStep = 1,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  // Navigation & Step state
  late int _currentStep; // 1: Scan KTM, 10: Manual NIM, 2: Scan Plat, 3: Konfirmasi
  int _selectedNavIndex = 0;

  // Form & Detection Data
  String _nim = '244107020204';
  String _plateNumber = 'N 1234 ABC';
  final String _scanTime = '07:32 WIB';
  final String _manualInputTime = '07:34 WIB';
  final String _sessionId = 'Sesi #089';

  // Interactive controls
  bool _flashlightOn = false;
  bool _manualKtmVerified = true;
  late TextEditingController _nimController;
  late TextEditingController _plateController;

  // Laser animation for camera viewfinder
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _nimController = TextEditingController(text: _nim);
    _plateController = TextEditingController(text: _plateNumber);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _nimController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  String get _posShortCode {
    if (widget.parkingLot.contains('•')) {
      return widget.parkingLot.split('•').first.trim();
    }
    return 'POS-UTAMA';
  }

  String get _posFullName {
    if (widget.parkingLot.contains('•')) {
      return widget.parkingLot.split('•').last.trim();
    }
    return widget.parkingLot;
  }

  void _copyNimToClipboard() {
    Clipboard.setData(ClipboardData(text: _nim));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.spPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('NIM $_nim berhasil disalin ke clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPlateEditDialog() {
    _plateController.text = _plateNumber;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppColors.spPrimary600),
            SizedBox(width: 8),
            Text(
              'Koreksi Plat Manual',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubah nomor plat bila hasil deteksi kamera kurang akurat:',
              style: TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: AppColors.spPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.spPrimary600,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.directions_car, color: AppColors.spInk3),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.spInk3)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _plateNumber = _plateController.text.trim().toUpperCase();
              });
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _finishCheckInSuccess() {
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
                Icons.check_circle_rounded,
                color: AppColors.spSuccess,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Check-In Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.spInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kendaraan $_plateNumber (NIM $_nim) telah berhasil tercatat masuk di $_posFullName.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.spInk2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.spTint1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.spTint3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WAKTU MASUK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spInk2,
                    ),
                  ),
                  Text(
                    _scanTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _currentStep = 1;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.spBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Check-In Lagi',
                      style: TextStyle(
                        color: AppColors.spPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ke Beranda',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
                    child: _buildCurrentStepBody(),
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

  /// App Bar matching smartpark canonical header
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
                      setState(() => _currentStep = 2);
                    } else if (_currentStep == 2) {
                      setState(() => _currentStep = 1);
                    } else if (_currentStep == 10) {
                      setState(() => _currentStep = 1);
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

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 1:
        return _buildStep1ScanKtm();
      case 10:
        return _buildStep1AltManualNim();
      case 2:
        return _buildStep2ScanPlat();
      case 3:
      default:
        return _buildStep3Konfirmasi();
    }
  }

  // ===========================================================================
  // STEP 1: SCAN KTM MAHASISWA (05-checkin-scan-ktm.html)
  // ===========================================================================
  Widget _buildStep1ScanKtm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sub-header & Stepper Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.spTint3),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0E4FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'LANGKAH 1 DARI 3',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Color(0xFF001D35),
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.qr_code_scanner, size: 14, color: AppColors.spPrimary600),
                      SizedBox(width: 4),
                      Text(
                        'Scan KTM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.spPrimary600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Segment progress bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.spPrimary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.spTint4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.spTint4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'PETUGAS: ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.spInk2,
                    ),
                  ),
                  Text(
                    widget.officerName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Check-In Kendaraan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppColors.spInk,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Arahkan QR Code pada KTM mahasiswa ke area pemindaian.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.spInk2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Camera Scanning Viewfinder Container
        Container(
          height: 380,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0C1622),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.spTint3, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Radial glow in background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.6,
                      colors: [
                        AppColors.spScan.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Central Reticle Box & KTM Mockup
              Center(
                child: SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 4 Corner Brackets
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.spScan, width: 4),
                              left: BorderSide(color: AppColors.spScan, width: 4),
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.spScan, width: 4),
                              right: BorderSide(color: AppColors.spScan, width: 4),
                            ),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.spScan, width: 4),
                              left: BorderSide(color: AppColors.spScan, width: 4),
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.spScan, width: 4),
                              right: BorderSide(color: AppColors.spScan, width: 4),
                            ),
                            borderRadius: BorderRadius.only(
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      // Animated Scan Laser
                      AnimatedBuilder(
                        animation: _laserAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: 240 * _laserAnimation.value,
                            left: 12,
                            right: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.spScan.withValues(alpha: 0.25),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: AppColors.spScan,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.spScan,
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Simulated KTM Card Graphic inside Focus
                      Container(
                        width: 190,
                        height: 190,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.spTint2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Card header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.spPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Flexible(
                                        child: Text(
                                          'KTM KAMPUS',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.spPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                    'MHS',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.spInk2,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Realistic QR Graphic Container
                            Container(
                              width: 110,
                              height: 110,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.spBorder),
                              ),
                              child: CustomPaint(
                                painter: _QrPatternPainter(),
                              ),
                            ),

                            // Card footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Flexible(
                                  child: Text(
                                    'BARCODE #2024',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.spInk3,
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    'SMARTPARK',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.spPrimary600,
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

              // Top Overlay Controls
              Positioned(
                top: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xD9213145),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.spScan,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'QR Code Terdeteksi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              _flashlightOn = !_flashlightOn;
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _flashlightOn
                                  ? Colors.amber.withValues(alpha: 0.3)
                                  : const Color(0xCC213145),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _flashlightOn
                                    ? Colors.amber
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flash_on_rounded,
                                  size: 16,
                                  color: _flashlightOn ? Colors.amber : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Senter',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _flashlightOn ? Colors.amber : Colors.white,
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
              ),

              // Bottom Overlay
              Positioned(
                bottom: 14,
                left: 14,
                right: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC213145),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.crop_free, size: 12, color: Colors.white70),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Jarak 15 – 25 cm',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xD9022C22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x4D34D399)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Kamera Aktif',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6EE7B7),
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

        const SizedBox(height: 14),

        // Section - Detection Result Card below Viewfinder
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.spTint3),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD1FAE5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: AppColors.spSuccessInk,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'QR Code Terdeteksi',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
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
                          'Format NIM Valid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spSuccessInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Student NIM Display Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.spTint2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NIM MAHASISWA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.spInk2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nim,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.spPrimary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: _copyNimToClipboard,
                      tooltip: 'Salin NIM',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: AppColors.spInk2,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.spSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.spTint3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Integrated Metadata Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.spTint2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WAKTU SCAN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _scanTime,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.spTint2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'POS MASUK',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _posShortCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.spTint2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PETUGAS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.officerName.split(' ').first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Disclaimer note
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.spWarnBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xCCFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppColors.spWarn,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Catatan: Identitas mahasiswa diverifikasi secara visual oleh petugas melalui KTM.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78350F),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action Buttons
        ElevatedButton(
          onPressed: () {
            setState(() {
              _currentStep = 2; // Move to Step 2: Scan Plat
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Lanjut Scan Plat',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),

        const SizedBox(height: 10),


        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memulai ulang pemindaian KTM...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spTint2,
                  foregroundColor: AppColors.spPrimary,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.spTint3),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Scan Ulang KTM',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 10; // Switch to Manual NIM input
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spTint3,
                  foregroundColor: AppColors.spInk,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.keyboard_outlined, size: 18),
                label: const Text(
                  'Ketik NIM Manual',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ===========================================================================
  // STEP 1 ALTERNATE: INPUT NIM MANUAL (09-checkin-verifikasi-mahasiswa.html)
  // ===========================================================================
  Widget _buildStep1AltManualNim() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Intro Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.spTint3,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'MODE CADANGAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.spPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Input NIM Manual',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.spPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Gunakan fitur ini hanya jika QR Code KTM tidak dapat dibaca.',
          style: TextStyle(fontSize: 14, color: AppColors.spInk2),
        ),

        const SizedBox(height: 14),

        // Warning Note Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spTint3,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.spTint4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: AppColors.spPrimary600, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perhatian Petugas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spPrimary,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Input manual hanya digunakan sebagai cadangan saat QR gagal dibaca. Wajib melakukan verifikasi visual terhadap KTM mahasiswa.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.spInk2,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Form Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.spTint3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NIM MAHASISWA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.spPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Large NIM Input Box with Icon
              TextField(
                controller: _nimController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.spPrimary,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.spSurface,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.spInk2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.spTint4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.spPrimary600,
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: const [
                  Icon(Icons.verified_user_outlined, size: 14, color: AppColors.spPrimary600),
                  SizedBox(width: 6),
                  Text(
                    'Pastikan petugas telah memeriksa KTM secara visual.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.spInk2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Detail Grid
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WAKTU INPUT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _manualInputTime,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'POS MASUK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _posFullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PETUGAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.spInk2,
                      ),
                    ),
                    Text(
                      widget.officerName,
                      style: const TextStyle(
                        fontSize: 12,
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

        const SizedBox(height: 14),

        // Confirmation Checkbox Card
        InkWell(
          onTap: () {
            setState(() {
              _manualKtmVerified = !_manualKtmVerified;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.spTint1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.spTint3),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _manualKtmVerified,
                  onChanged: (val) {
                    setState(() {
                      _manualKtmVerified = val ?? false;
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
                        'KTM Mahasiswa Telah Diperiksa Fisik',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Petugas memastikan identitas pemilik sesuai secara visual.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.spInk2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons
        ElevatedButton(
          onPressed: _manualKtmVerified
              ? () {
                  setState(() {
                    _nim = _nimController.text.trim();
                    _currentStep = 2; // Move to Step 2
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'LANJUT SCAN PLAT KENDARAAN',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 10),

        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStep = 1; // Back to Step 1 camera
            });
          },
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.spSurface,
            foregroundColor: AppColors.spPrimary,
            side: const BorderSide(color: AppColors.spTint3),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text(
            'Kembali ke Scan QR KTM',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ===========================================================================
  // STEP 2: SCAN PLAT KENDARAAN (08-checkin-scan-plat.html)
  // ===========================================================================
  Widget _buildStep2ScanPlat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0E4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.spPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'ALUR CHECK-IN MASUK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF114976),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Langkah 2 dari 3',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Progress bar 3 segment
        Row(
          children: [
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.spPrimary600,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.spPrimary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.spTint4,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        const Text(
          'Scan Plat Kendaraan',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.spInk,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Arahkan kamera ke plat nomor kendaraan.',
          style: TextStyle(fontSize: 14, color: AppColors.spInk2),
        ),

        const SizedBox(height: 14),

        // Viewfinder & Camera Stream Mockup
        Container(
          height: 270,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF213145),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo Plate Checkin Asset with Fallback
              Image.asset(
                'assets/foto-plat-checkin.png',
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: const Color(0xFF213145),
                  child: const Center(
                    child: Icon(
                      Icons.camera_alt_outlined,
                      size: 48,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF213145).withValues(alpha: 0.4),
                      Colors.transparent,
                      const Color(0xFF213145).withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              // Animated Laser Line
              AnimatedBuilder(
                animation: _laserAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 270 * _laserAnimation.value,
                    left: 32,
                    right: 32,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.spScan,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.spScan,
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Bounding Box with Corners
              Center(
                child: Container(
                  width: 290,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      // Corners
                      Positioned(
                        top: -2,
                        left: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.spScan,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(2)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.spScan,
                            borderRadius: BorderRadius.only(topRight: Radius.circular(2)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        left: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.spScan,
                            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(2)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.spScan,
                            borderRadius: BorderRadius.only(bottomRight: Radius.circular(2)),
                          ),
                        ),
                      ),
                      // Tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xE6213145),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check, size: 14, color: AppColors.spScan),
                              SizedBox(width: 4),
                              Text(
                                'Plat Terdeteksi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Top Toolbar
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xCC213145),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.center_focus_strong, size: 14, color: AppColors.spScan),
                          SizedBox(width: 4),
                          Text(
                            'Auto-Focus Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _flashlightOn = !_flashlightOn;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _flashlightOn
                              ? Colors.amber.withValues(alpha: 0.3)
                              : const Color(0xCC213145),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.flash_on_rounded,
                          size: 18,
                          color: _flashlightOn ? Colors.amber : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom status feedback
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.spPrimary600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Kamera Smartphone Aktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Real-Time Floating OCR Result Card
        Container(
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: _showPlateEditDialog,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.spTint2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.edit_outlined, size: 14, color: AppColors.spPrimary),
                          SizedBox(width: 4),
                          Text(
                            'Koreksi Manual',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.spPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Embossed Vehicle Plate Display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF213145),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _plateNumber,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Student identity link
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD0E4FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: Color(0xFF001D35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NIM: $_nim',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk,
                            ),
                          ),
                          const Text(
                            'QR KTM berhasil dibaca',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.spInk2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.spPrimary600),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Ergonomic Primary Field Action Controls
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _currentStep = 3; // Move to Step 3: Konfirmasi
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spPrimary,
            foregroundColor: Colors.white,
            elevation: 2,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: const Text(
            'Gunakan Plat Ini',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Memindai ulang plat kendaraan...'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spTint3,
            foregroundColor: AppColors.spInk,
            elevation: 0,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Scan Ulang',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),

        const SizedBox(height: 12),

        // Secondary Info Note
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline, size: 16, color: AppColors.spPrimary600),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sistem OCR mendeteksi plat nomor langsung dari kamera smartphone. Tekan Koreksi Manual bila plat kotor atau tidak terbaca sempurna.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.spInk2,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ===========================================================================
  // STEP 3: KONFIRMASI CHECK-IN (10-checkin-konfirmasi-sukses.html)
  // ===========================================================================
  Widget _buildStep3Konfirmasi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'GERBANG POS MASUK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.spPrimary600,
                    ),
                  ),
                  Text(
                    'Konfirmasi Check-In',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: AppColors.spInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.spTint3,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _sessionId,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spPrimary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // MVP Check-In Data Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xCCDCE9FF)),
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
                        Icon(Icons.assignment_outlined, size: 18, color: AppColors.spPrimary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data Sesi Check-In',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
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
                      color: AppColors.spSuccessBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
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
                          'Siap Check-In',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.spSuccessInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 20, color: AppColors.spTint2),

              // 1. Nomor Induk Mahasiswa
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.spTint1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NOMOR INDUK MAHASISWA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _nim,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.spInk,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xE6D1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.check, size: 12, color: AppColors.spSuccessInk),
                          SizedBox(width: 4),
                          Text(
                            'Format NIM Valid',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spSuccessInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Plat Kendaraan Terdeteksi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF213145),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PLAT KENDARAAN TERDETEKSI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: Color(0xFFCBDBF5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x4D727780)),
                      ),
                      child: Center(
                        child: Text(
                          _plateNumber,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Colors.white,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3 & 4. Grid Waktu Masuk & Pos Lapangan
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WAKTU MASUK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: AppColors.spPrimary600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _scanTime,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.spInk,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.spTint1,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'POS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.spInk2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.spPrimary600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _posShortCode,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.spInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Note Guide
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.spWarnBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xB3FDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.spWarn,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Identitas mahasiswa diverifikasi secara visual oleh petugas melalui KTM.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF78350F),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Primary CTA Buttons
              ElevatedButton.icon(
                onPressed: _finishCheckInSuccess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spPrimary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 22),
                label: const Text(
                  'Konfirmasi Check-In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = 2; // Back to plate scan / edit
                  });
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.spTint1,
                  foregroundColor: AppColors.spPrimary,
                  side: const BorderSide(color: AppColors.spTint3),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Ubah Data',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
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

/// Custom QR Pattern Painter for realistic QR code representation
class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.spPrimary
      ..style = PaintingStyle.fill;

    final cellW = size.width / 21;
    final cellH = size.height / 21;

    void drawBox(int col, int row, int w, int h) {
      canvas.drawRect(
        Rect.fromLTWH(col * cellW, row * cellH, w * cellW, h * cellH),
        paint,
      );
    }

    // Corner Finder Patterns
    // Top-left
    drawBox(0, 0, 7, 7);
    // Top-right
    drawBox(14, 0, 7, 7);
    // Bottom-left
    drawBox(0, 14, 7, 7);

    // Inner clearings & centers
    final clearPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(1 * cellW, 1 * cellH, 5 * cellW, 5 * cellH), clearPaint);
    canvas.drawRect(Rect.fromLTWH(15 * cellW, 1 * cellH, 5 * cellW, 5 * cellH), clearPaint);
    canvas.drawRect(Rect.fromLTWH(1 * cellW, 15 * cellH, 5 * cellW, 5 * cellH), clearPaint);

    drawBox(2, 2, 3, 3);
    drawBox(16, 2, 3, 3);
    drawBox(2, 16, 3, 3);

    // Some simulated QR data points
    drawBox(8, 2, 2, 1);
    drawBox(11, 2, 1, 2);
    drawBox(9, 4, 1, 1);
    drawBox(8, 6, 1, 1);
    drawBox(10, 6, 1, 1);
    drawBox(12, 6, 1, 1);
    drawBox(6, 8, 1, 1);
    drawBox(8, 8, 3, 3);
    drawBox(12, 8, 1, 3);
    drawBox(14, 8, 2, 1);
    drawBox(17, 8, 2, 1);
    drawBox(9, 12, 1, 1);
    drawBox(10, 12, 2, 2);
    drawBox(13, 12, 1, 1);
    drawBox(8, 15, 1, 1);
    drawBox(10, 15, 2, 1);
    drawBox(14, 15, 2, 2);
    drawBox(17, 15, 1, 2);
    drawBox(15, 18, 3, 1);
    drawBox(14, 20, 2, 1);
    drawBox(17, 20, 2, 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
