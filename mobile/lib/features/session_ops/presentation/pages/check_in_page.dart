import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/entities/parking_session.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/session_providers.dart';
import '../../../../core/session/officer_identity.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/page_app_bar.dart';

/// Screen for Check-In Vehicle Flow (Steps 1, 1-alt, 2, 3)
/// Mapped from Figma prototypes:
/// - 05-checkin-scan-ktm.html (Step 1: Scan KTM Mahasiswa)
/// - 09-checkin-verifikasi-mahasiswa.html (Step 1 Alternate: Input NIM Manual)
/// - 08-checkin-scan-plat.html (Step 2: Scan Plat Kendaraan)
/// - 10-checkin-konfirmasi-sukses.html (Step 3: Konfirmasi & Sukses Masuk)
part 'check_in_chrome.dart';
part 'check_in_step_ktm.dart';
part 'check_in_step_manual_nim.dart';
part 'check_in_step_plate.dart';
part 'check_in_step_confirm.dart';

class CheckInPage extends ConsumerStatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;
  final CheckInStep initialStep;

  const CheckInPage({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
    this.initialStep = CheckInStep.ktm,
  });

  @override
  ConsumerState<CheckInPage> createState() => _CheckInPageState();
}

/// Urutan layar check-in: scan KTM → (opsional) NIM manual → plat → konfirmasi.
enum CheckInStep { ktm, manualNim, plate, confirm }

/// Kompatibilitas pemanggil lama yang memakai angka ajaib 1/10/2/3.
extension CheckInStepCode on CheckInStep {
  static CheckInStep fromCode(int code) {
    switch (code) {
      case 10:
        return CheckInStep.manualNim;
      case 2:
        return CheckInStep.plate;
      case 3:
        return CheckInStep.confirm;
      case 1:
      default:
        return CheckInStep.ktm;
    }
  }

  static CheckInStep? tryParse(Object? value) {
    if (value is CheckInStep) return value;
    if (value is int) return CheckInStepCode.fromCode(value);
    return null;
  }
}
class _CheckInPageState extends ConsumerState<CheckInPage>
    with SingleTickerProviderStateMixin {
  late CheckInStep _currentStep;
  bool _cameFromManual = false;
  late String _clockNow;

  String _nim = '';
  String _plateNumber = '';
  String? _platePhotoPath;
  SessionDetail? _createdSession;
  bool _isSubmitting = false;
  String? _errorMessage;
  // Interactive controls
  bool _flashlightOn = false;
  bool _manualKtmVerified = false;
  late TextEditingController _nimController;
  late TextEditingController _plateController;
  final TextEditingController _voidReasonController = TextEditingController();
  // Live QR scanner embedded in Step 1 viewfinder (no separate route).
  late final MobileScannerController _qrController;
  DateTime? _lastQrAt;
  String _lastQrCode = '';
  // Live plate camera embedded in Step 2 viewfinder.
  CameraController? _plateCamera;
  bool _plateCamReady = false;
  String? _plateCamError;
  bool _plateCapturing = false;
  bool _platePreviewing = false;

  // Laser animation for camera viewfinder
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _currentStep = CheckInStepCode.tryParse(widget.initialStep) ?? CheckInStep.ktm;
    _cameFromManual = _currentStep == CheckInStep.manualNim;
    _clockNow = Formatters.time(DateTime.now());
    _nimController = TextEditingController();
    _plateController = TextEditingController();
    _qrController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    if (_currentStep == CheckInStep.plate) unawaited(_ensurePlateCamera());
  }

  @override
  void dispose() {
    _animController.dispose();
    _qrController.dispose();
    _plateCamera?.dispose();
    _nimController.dispose();
    _plateController.dispose();
    _voidReasonController.dispose();
    super.dispose();
  }

  void _refreshClock() {
    _clockNow = Formatters.time(DateTime.now());
  }

  String get _posShortCode => areaShortLabel(widget.parkingLot);

  String get _posFullName => areaFullLabel(widget.parkingLot);

  void _copyNimToClipboard() {
    final nim = _nim.trim();
    if (nim.isEmpty) {
      AppSnackBar.error(context, 'NIM belum terisi.');
      return;
    }
    Clipboard.setData(ClipboardData(text: nim));
    AppSnackBar.success(context, 'NIM $nim berhasil disalin ke clipboard');
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
            Expanded(
              child: Text(
                'Koreksi Plat Manual',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
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
              final error = Validators.plate(_plateController.text);
              if (error != null) {
                AppSnackBar.error(context, error);
                return;
              }
              setState(() {
                _plateNumber = Validators.normalizePlate(_plateController.text);
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

  void _showNimEditDialog() {
    _nimController.text = _nim;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.edit_note_rounded, color: AppColors.spPrimary600),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ubah NIM Mahasiswa',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nomor induk mahasiswa yang sesuai:',
              style: TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nimController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.spPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.spInk3),
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
              final error = Validators.nim(_nimController.text);
              if (error != null) {
                AppSnackBar.error(context, error);
                return;
              }
              setState(() {
                _nim = _nimController.text.trim();
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

  /// Pindah step + serah-terima kamera: hanya satu kamera aktif.
  void _setStep(CheckInStep s) {
    setState(() {
      _currentStep = s;
      _refreshClock();
      if (s == CheckInStep.manualNim) _cameFromManual = true;
    });
    _applyCameraForStep(s);
  }

  void _goBack() {
    switch (_currentStep) {
      case CheckInStep.confirm:
        _setStep(CheckInStep.plate);
        break;
      case CheckInStep.plate:
        _setStep(_cameFromManual ? CheckInStep.manualNim : CheckInStep.ktm);
        break;
      case CheckInStep.manualNim:
        _setStep(CheckInStep.ktm);
        break;
      case CheckInStep.ktm:
        Navigator.of(context).pop();
        break;
    }
  }

  bool _tryNextFromKtm() {
    final error = Validators.nim(_nimController.text.isEmpty ? _nim : _nimController.text);
    if (error != null) {
      AppSnackBar.error(context, error);
      return false;
    }
    setState(() {
      _nim = _nimController.text.trim();
    });
    _setStep(CheckInStep.plate);
    return true;
  }

  bool _tryNextFromManual() {
    final error = Validators.nim(_nimController.text);
    if (error != null) {
      AppSnackBar.error(context, error);
      return false;
    }
    if (!_manualKtmVerified) {
      AppSnackBar.error(context, 'Centang verifikasi KTM fisik terlebih dahulu.');
      return false;
    }
    setState(() {
      _nim = _nimController.text.trim();
    });
    _setStep(CheckInStep.plate);
    return true;
  }

  bool _tryNextFromPlate() {
    final source = _plateController.text.isEmpty ? _plateNumber : _plateController.text;
    final error = Validators.plate(source);
    if (error != null) {
      AppSnackBar.error(context, error);
      return false;
    }
    setState(() {
      _plateNumber = Validators.normalizePlate(source);
    });
    _setStep(CheckInStep.confirm);
    return true;
  }

  void _openManualNim() {
    setState(() {
      _cameFromManual = true;
      _manualKtmVerified = false;
      _refreshClock();
      _currentStep = CheckInStep.manualNim;
    });
    _applyCameraForStep(CheckInStep.manualNim);
  }

  void _resetCheckInForm() {
    setState(() {
      _nim = '';
      _nimController.clear();
      _plateNumber = '';
      _plateController.clear();
      _platePhotoPath = null;
      _platePreviewing = false;
      _manualKtmVerified = false;
      _cameFromManual = false;
      _errorMessage = null;
      _refreshClock();
    });
  }

  void _applyCameraForStep(CheckInStep s) {
    try {
      if (s == CheckInStep.plate) {
        unawaited(_qrController.stop().catchError((_) {}));
        unawaited(_ensurePlateCamera());
      } else {
        unawaited(_plateCamera?.pausePreview().catchError((_) {}) ?? Future.value());
        if (s == CheckInStep.ktm) unawaited(_qrController.start().catchError((_) {}));
      }
    } catch (_) {
      // Perangkat tanpa kamera / plugin belum siap (widget test): abaikan.
    }
  }

  /// Inisialisasi kamera plat sekali saja; dipanggil saat masuk Step 2.
  Future<void> _ensurePlateCamera() async {
    try {
      if (_plateCamera != null) {
        await _plateCamera!.resumePreview();
        return;
      }
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _plateCamError = 'Tidak ada kamera di perangkat ini.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _plateCamera = controller;
        _plateCamReady = true;
        _plateCamError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _plateCamReady = false;
        _plateCamError = 'Kamera tidak tersedia. Ketik plat secara manual.';
      });
    }
  }

  /// Shutter inline: jepret dari preview live, tampilkan pratinjau hasil.
  Future<void> _capturePlateInline() async {
    final camera = _plateCamera;
    if (camera == null || !_plateCamReady || _plateCapturing) {
      AppSnackBar.info(context, 'Kamera belum siap. Tunggu sebentar lalu coba lagi.');
      return;
    }
    setState(() => _plateCapturing = true);
    try {
      final file = await camera.takePicture();
      await camera.pausePreview();
      if (!mounted) return;
      setState(() {
        _platePhotoPath = file.path;
        _platePreviewing = true;
        _plateCapturing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _plateCapturing = false);
      AppSnackBar.error(context, 'Gagal mengambil foto. Coba lagi.');
    }
  }

  /// Kembali ke preview live untuk foto ulang.
  void _retakePlate() {
    setState(() => _platePreviewing = false);
    try {
      unawaited(_plateCamera?.resumePreview().catchError((_) {}) ?? Future.value());
    } catch (_) {}
  }

  Future<void> _togglePlateTorch() async {
    final camera = _plateCamera;
    if (camera == null || !_plateCamReady) {
      AppSnackBar.info(context, 'Kamera belum siap.');
      return;
    }
    try {
      await camera.setFlashMode(_flashlightOn ? FlashMode.off : FlashMode.torch);
    } catch (_) {
      return; // Perangkat tanpa flash: abaikan.
    }
    if (!mounted) return;
    setState(() => _flashlightOn = !_flashlightOn);
  }

  /// Callback live scanner inline: isi NIM otomatis saat QR terbaca.
  /// Throttle 5 detik + abaikan kode sama agar tidak spam snackbar.
  void _onQrDetect(BarcodeCapture capture) {
    if (!mounted || _currentStep != CheckInStep.ktm) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        code = value.trim();
        break;
      }
    }
    if (code == null) return;
    final now = DateTime.now();
    if (code == _lastQrCode &&
        _lastQrAt != null &&
        now.difference(_lastQrAt!).inSeconds < 5) {
      return;
    }
    _lastQrCode = code;
    _lastQrAt = now;
    setState(() {
      _nim = code!;
      _nimController.text = code;
    });
    AppSnackBar.success(context, 'NIM terisi dari QR: $code');
  }

  /// Nyalakan ulang pemindaian setelah kode sama ingin dibaca lagi.
  void _rescanQrNim() {
    _lastQrCode = '';
    _lastQrAt = null;
    _qrController.start();
  }

  Future<void> _toggleQrTorch() async {
    try {
      await _qrController.toggleTorch();
    } catch (_) {
      return; // Perangkat tanpa flash / web: abaikan.
    }
    if (!mounted) return;
    setState(() {
      _flashlightOn = !_flashlightOn;
    });
  }

  Future<void> _submitCheckIn() async {
    final nimError = Validators.nim(_nim);
    if (nimError != null) {
      AppSnackBar.error(context, nimError);
      return;
    }
    final plateError = Validators.plate(_plateNumber);
    if (plateError != null) {
      AppSnackBar.error(context, plateError);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = await ref.read(sessionRepositoryProvider).checkIn(
            nim: _nim.trim(),
            plate: Validators.normalizePlate(_plateNumber),
            photoPath: _platePhotoPath,
          );

      if (!mounted) return;

      setState(() {
        _createdSession = session;
        _isSubmitting = false;
      });

      _finishCheckInSuccess(session);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = failure.message.isNotEmpty
            ? failure.message
            : 'Check-in gagal. Coba lagi.';
      });
      AppSnackBar.error(context, _errorMessage!);
    }
  }

  void _finishCheckInSuccess([SessionDetail? session]) {
    final activeSession = session ?? _createdSession;
    final displayPlate = activeSession?.plateIn ?? _plateNumber;
    final displayNim = activeSession?.nim ?? _nim;
    final displayArea = activeSession?.areaName ?? _posFullName;
    final displayTime = activeSession != null
        ? Formatters.time(activeSession.checkedInAt)
        : _clockNow;
    final sessionId = activeSession != null ? '#${activeSession.id}' : 'Sesi #089';

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
              'Kendaraan $displayPlate (NIM $displayNim) telah berhasil tercatat masuk di $displayArea.',
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
              child: Column(
                children: [
                  Row(
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
                        displayTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ID SESI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spInk2,
                        ),
                      ),
                      Text(
                        sessionId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.spPrimary600,
                        ),
                      ),
                    ],
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
                      _resetCheckInForm();
                      setState(() => _createdSession = null);
                      _setStep(CheckInStep.ktm);
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
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
            if (activeSession != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showVoidDialog(activeSession.id);
                },
                icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.spDanger),
                label: const Text(
                  'Batalkan Check-In',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spDanger,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVoidDialog(int sessionId) {
    _voidReasonController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_forever_outlined, color: AppColors.spDanger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Batalkan Check-In',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesi #$sessionId akan dibatalkan. NIM dan nomor plat akan segera bebas digunakan kembali.',
              style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _voidReasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tuliskan alasan pembatalan (contoh: salah input nomor plat/NIM)...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                filled: true,
                fillColor: AppColors.spTint1,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.spBorder),
                ),
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
            onPressed: () async {
              final note = _voidReasonController.text.trim();
              if (note.isEmpty) {
                AppSnackBar.error(context, 'Pembatalan check-in wajib disertai alasan.');
                return;
              }
              Navigator.of(ctx).pop();
              await _submitVoid(sessionId, note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Batalkan Check-In'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitVoid(int sessionId, String note) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(sessionRepositoryProvider).voidSession(
            sessionId,
            note: note,
          );
      if (!mounted) return;
      _resetCheckInForm();
      setState(() {
        _isSubmitting = false;
        _createdSession = null;
      });
      _setStep(CheckInStep.ktm);
      AppSnackBar.success(context, 'Sesi #$sessionId berhasil dibatalkan (void).');
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.error(context, failure.message);
    }
  }

  /// Memicu rebuild dari bagian UI yang dipisah ke `part` file.
  void rebuild(VoidCallback fn) => setState(fn);

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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case CheckInStep.ktm:
        return _buildStep1ScanKtm();
      case CheckInStep.manualNim:
        return _buildStep1AltManualNim();
      case CheckInStep.plate:
        return _buildStep2ScanPlat();
      case CheckInStep.confirm:
        return _buildStep3Konfirmasi();
    }
  }
}
