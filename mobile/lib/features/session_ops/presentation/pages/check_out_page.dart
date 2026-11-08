import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_capture_page.dart';

import '../../../../core/entities/lookup_result.dart';
import '../../../../core/entities/parking_session.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_banner.dart';
import '../../../../core/widgets/page_app_bar.dart';

/// Screen for Check-Out Flow & Vehicle Verification
/// Mapped from Figma prototypes:
/// - 06-checkout-verifikasi-kendaraan.html (Check-Out: Verifikasi Kendaraan & KTM)
/// - 13-verifikasi-manual-petugas.html (Verifikasi Manual Petugas)
part 'check_out_dialogs.dart';
part 'check_out_lookup.dart';
part 'check_out_verification.dart';

class CheckOutPage extends ConsumerStatefulWidget {
  final String officerName;
  final String officerRole;
  final bool isSupervisor;
  final String parkingLot;
  final String nim;
  final String checkInPlate;
  final String checkInTime;
  final SessionDetail? initialSession;
  final void Function(SessionDetail closed)? onFinished;

  const CheckOutPage({
    super.key,
    this.officerName = '',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = '',
    this.nim = '',
    this.checkInPlate = '',
    this.checkInTime = '',
    this.initialSession,
    this.onFinished,
  });

  @override
  ConsumerState<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends ConsumerState<CheckOutPage> {
  // Sesi & hasil pencarian aktif
  SessionDetail? _session;
  String? _matchMethod;
  List<LookupCandidate> _candidates = const [];
  String? _lookupMessage;
  String? _lookupError;
  String? _actionError;
  String? _lastPlate;
  String? _lastNim;
  bool _hasSearched = false;

  // Kontroler formulir
  late final TextEditingController _outPlateController;
  late final TextEditingController _nimFallbackController;
  final TextEditingController _manualNoteController = TextEditingController();
  final TextEditingController _actionNoteController = TextEditingController();

  // Status operasi
  bool _ktmChecked = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _showNimSearch = false;
  String? _outPhotoPath;
  Uint8List? _inPhotoBytes;

  /// Momen sesi ditemukan/dimuat; dipakai sekali untuk jam & durasi keluar.
  DateTime? _scanOutAt;

  @override
  void initState() {
    super.initState();
    _outPlateController = TextEditingController();
    _outPlateController.addListener(_onOutPlateChanged);
    _nimFallbackController = TextEditingController(text: widget.nim);
    _outPhotoPath = null;
    _inPhotoBytes = null;
    _ktmChecked = false;

    if (widget.initialSession != null) {
      _session = widget.initialSession;
      _matchMethod = _session!.matchMethod ?? 'plate_exact';
      if (_nimFallbackController.text.isEmpty && _session!.nim.isNotEmpty) {
        _nimFallbackController.text = _session!.nim;
      }
      _scanOutAt = DateTime.now();
      _hasSearched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInPhoto());
      return;
    }

    // Tanpa sesi awal: mulai kosong. Auto-lookup hanya bila ada token shift
    // dan ada benih plat/NIM; selain itu tampilkan hint input manual.
    _session = null;
    final hasToken = ref.read(sessionStoreProvider).shiftToken != null;
    final seedPlate = widget.checkInPlate.trim();
    final seedNim = widget.nim.trim();
    if (hasToken && (seedPlate.isNotEmpty || seedNim.isNotEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performLookup(seedPlate, nim: seedNim.isEmpty ? null : seedNim);
      });
    }
  }

  @override
  void dispose() {
    _outPlateController.removeListener(_onOutPlateChanged);
    _outPlateController.dispose();
    _nimFallbackController.dispose();
    _manualNoteController.dispose();
    _actionNoteController.dispose();
    super.dispose();
  }

  void _onOutPlateChanged() {
    setState(() {});
  }

  String get _currentCheckOutPlate =>
      Validators.normalizePlate(_outPlateController.text);

  String get _checkInPlate => _session?.plateIn ??
      (widget.checkInPlate.isNotEmpty ? widget.checkInPlate : '-');

  String get _currentNim =>
      _session?.nim ?? (widget.nim.isNotEmpty ? widget.nim : '-');

  String get _checkInTime {
    final session = _session;
    if (session != null) return Formatters.time(session.checkedInAt);
    return widget.checkInTime.isNotEmpty ? widget.checkInTime : '--';
  }

  String get _checkOutTime {
    final stamped = _scanOutAt;
    return stamped == null ? '--' : Formatters.time(stamped);
  }

  String get _durationText {
    final session = _session;
    if (session == null) return '--';
    return Formatters.elapsed(session.checkedInAt.toLocal(), _scanOutAt);
  }

  String get _sessionId {
    final session = _session;
    if (session != null) {
      return 'ID: PRK-${session.id.toString().padLeft(6, '0')}';
    }
    return 'ID: --';
  }

  bool get _isPlateMatched {
    if (_session == null) return false;
    final outP = _currentCheckOutPlate;
    if (outP.isEmpty) return false;
    final inP = Validators.normalizePlate(_session!.plateIn);
    if (inP.isEmpty) return false;
    return inP == outP;
  }

  Future<void> _performLookup(String plate, {String? nim}) async {
    final cleanPlate = Validators.normalizePlate(plate);
    final cleanNim = (nim ?? '').trim();
    if (cleanPlate.isEmpty && cleanNim.isEmpty) {
      AppSnackBar.info(
        context,
        'Masukkan plat nomor atau NIM untuk mencari sesi.',
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _lookupMessage = null;
      _lookupError = null;
      _actionError = null;
      _candidates = const [];
      _lastPlate = plate;
      _lastNim = nim;
      _outPhotoPath = null;
      _inPhotoBytes = null;
      _ktmChecked = false;
    });

    try {
      final result = await ref.read(sessionRepositoryProvider).lookup(
            plate: cleanPlate,
            nim: cleanNim.isEmpty ? null : cleanNim,
          );
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _matchMethod = result.matchMethod;
        if (result.session != null) {
          _session = result.session;
          _candidates = const [];
          _lookupMessage = null;
          _lookupError = null;
          _scanOutAt = DateTime.now();
          _outPhotoPath = null;
          _nimFallbackController.text = result.session!.nim;
          _loadInPhoto();
        } else if (result.candidates.isNotEmpty) {
          _session = null;
          _candidates = result.candidates;
          _lookupMessage = null;
        } else {
          _session = null;
          _candidates = const [];
          _lookupMessage =
              (result.message?.isNotEmpty == true) ? result.message : 'Sesi tidak ditemukan.';
        }
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _lookupError = failure.message;
      });
      AppSnackBar.error(context, failure.message);
    }
  }

  void _retryLookup() {
    final plate = _lastPlate;
    if (plate == null) {
      AppSnackBar.info(context, 'Masukkan plat nomor atau NIM terlebih dahulu.');
      return;
    }
    _performLookup(plate, nim: _lastNim);
  }

  Future<void> _selectCandidate(LookupCandidate candidate) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final detail =
          await ref.read(sessionRepositoryProvider).session(candidate.sessionId);
      if (!mounted) return;
      setState(() {
        _session = detail;
        _matchMethod = 'plate_similar';
        _candidates = const [];
        _isSearching = false;
        _scanOutAt = DateTime.now();
      });
      _loadInPhoto();
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      AppSnackBar.error(context, failure.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _captureOutPhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CameraCapturePage(title: 'Foto Plat Keluar'),
      ),
    );
    if (!mounted) return;
    if (path == null) {
      AppSnackBar.info(context, 'Pengambilan foto dibatalkan.');
      return;
    }
    setState(() {
      _outPhotoPath = path;
    });
  }

  /// Mengambil snapshot plat saat masuk untuk perbandingan visual.
  ///
  /// Gagal (404/foto belum ada) tidak menghalangi alur check-out; panel
  /// cukup menampilkan ikon placeholder.
  Future<void> _loadInPhoto() async {
    final session = _session;
    if (session == null || session.plateInPhotoPath == null) return;
    try {
      final bytes = await ref
          .read(sessionRepositoryProvider)
          .sessionPhoto(session.id, 'in');
      if (!mounted) return;
      setState(() => _inPhotoBytes = bytes);
    } on Failure {
      // Biarkan placeholder; bukan kesalahan yang menghambat check-out.
    }
  }

  /// Satu-satunya gerbang konfirmasi: wajib KTM, lalu cocok → langsung,
  /// selisih → dialog manual dengan catatan wajib.
  Future<void> _handleConfirmCheckOut() async {
    final session = _session;
    if (session == null) {
      setState(() {
        _actionError =
            'Tidak ada sesi aktif yang dipilih. Cari sesi lewat plat nomor atau NIM terlebih dahulu.';
      });
      return;
    }
    if (!_ktmChecked) {
      AppSnackBar.info(
        context,
        'Centang pemeriksaan KTM sebelum konfirmasi check-out.',
      );
      return;
    }
    if (!_isPlateMatched) {
      _showManualConfirmDialog(session);
      return;
    }
    await _submitCheckOut(session, status: 'matched');
  }

  Future<void> _submitCheckOut(
    SessionDetail session, {
    required String status,
    String? note,
  }) async {
    setState(() {
      _isSubmitting = true;
      _actionError = null;
    });

    try {
      final closedSession = await ref.read(sessionRepositoryProvider).checkOut(
            id: session.id,
            plate: _currentCheckOutPlate,
            status: status,
            note: note,
            matchMethod:
                _matchMethod ?? (status == 'matched' ? 'plate_exact' : 'plate_similar'),
            photoPath: _outPhotoPath,
          );

      if (!mounted) return;

      setState(() {
        _session = closedSession;
        _isSubmitting = false;
      });

      _showSuccessDialog(closedSession);
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.error(
        context,
        failure.message.isNotEmpty ? failure.message : 'Gagal check-out.',
      );
    }
  }

  Future<void> _submitReject(String note) async {
    final session = _session;
    if (session == null) {
      setState(() {
        _actionError =
            'Tidak ada sesi aktif yang dipilih. Cari sesi terlebih dahulu.';
      });
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .reject(session.id, note: note);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.info(
        context,
        'Check-out sesi #${session.id} berhasil ditolak. Sesi tetap aktif.',
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.error(context, failure.message);
    }
  }

  Future<void> _submitVoid(String note) async {
    final session = _session;
    if (session == null) {
      setState(() {
        _actionError =
            'Tidak ada sesi aktif yang dipilih. Cari sesi terlebih dahulu.';
      });
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .voidSession(session.id, note: note);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _clearSessionState();
      });
      AppSnackBar.success(context, 'Sesi check-in berhasil dibatalkan (voided).');
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppSnackBar.error(context, failure.message);
    }
  }

  /// Reset penuh: sesi + seluruh kontroler & status, siap untuk void/
  /// check-out ulang berikutnya.
  void _clearSessionState() {
    _session = null;
    _matchMethod = null;
    _candidates = const [];
    _lookupMessage = null;
    _lookupError = null;
    _actionError = null;
    _lastPlate = null;
    _lastNim = null;
    _hasSearched = false;
    _ktmChecked = false;
    _showNimSearch = false;
    _outPhotoPath = null;
    _inPhotoBytes = null;
    _scanOutAt = null;
    _outPlateController.clear();
    _nimFallbackController.clear();
    _manualNoteController.clear();
    _actionNoteController.clear();
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTesterSelector(),
                        const SizedBox(height: 12),
                        _buildLookupSearchCard(),
                        if (_candidates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildCandidatesSection(),
                        ],
                        if (_lookupError != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(
                            message: _lookupError!,
                            onRetry: _isSearching ? null : _retryLookup,
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (_session == null) ...[
                          _buildEmptyLookupState(),
                        ] else ...[
                          _buildLiveStatusBanner(),
                          const SizedBox(height: 14),
                          _buildPlateComparisonCard(),
                          const SizedBox(height: 14),
                          _buildActiveSessionMetadata(),
                          const SizedBox(height: 14),
                          if (!_isPlateMatched) ...[
                            _buildManualVerificationSection(),
                            const SizedBox(height: 14),
                          ],
                        ],
                        if (_actionError != null) ...[
                          ErrorBanner(message: _actionError!),
                          const SizedBox(height: 14),
                        ],
                        _buildActionControls(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 5. Session & Identity Metadata (Glance Zone)

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
}
