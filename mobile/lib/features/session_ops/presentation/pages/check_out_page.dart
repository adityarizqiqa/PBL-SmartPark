import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'camera_capture_page.dart';

import '../../../../core/entities/lookup_result.dart';
import '../../../../core/entities/parking_session.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/di/providers.dart';
import '../providers/session_providers.dart';

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

  const CheckOutPage({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
    this.nim = '',
    this.checkInPlate = '',
    this.checkInTime = '',
    this.initialSession,
  });

  @override
  ConsumerState<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends ConsumerState<CheckOutPage> {
  int _selectedNavIndex = 0;

  // Sesi & hasil pencarian aktif
  SessionDetail? _session;
  String? _matchMethod;
  List<LookupCandidate> _candidates = const [];
  String? _lookupMessage;

  // Kontroler formulir
  late final TextEditingController _outPlateController;
  late final TextEditingController _nimFallbackController;
  final TextEditingController _manualNoteController = TextEditingController();
  final TextEditingController _actionNoteController = TextEditingController();

  // Status operasi
  bool _ktmChecked = false;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _showManualForm = false;
  bool _showNimSearch = false;
  String? _outPhotoPath;
  Uint8List? _inPhotoBytes;
  bool _isLoadingInPhoto = false;
  bool _inPhotoLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _outPlateController = TextEditingController();
    _outPlateController.addListener(_onOutPlateChanged);
    _nimFallbackController = TextEditingController(text: widget.nim);

    _outPhotoPath = null;
    _inPhotoBytes = null;
    _isLoadingInPhoto = false;
    _inPhotoLoadFailed = false;
    _ktmChecked = false;
    _showManualForm = false;

    if (widget.initialSession != null) {
      _session = widget.initialSession;
      _matchMethod = _session!.matchMethod ?? 'plate_exact';
      if (_nimFallbackController.text.isEmpty && _session!.nim.isNotEmpty) {
        _nimFallbackController.text = _session!.nim;
      }
      final path = _session!.plateInPhotoPath?.trim();
      if (path != null && path.isNotEmpty) {
        _isLoadingInPhoto = true;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInPhoto());
    } else {
      _session = null;
      _matchMethod = null;

      // Bila ada plat yang diteruskan dan token shift aktif, lakukan lookup backend riil
      final plateToLookup = widget.checkInPlate.trim();
      if (plateToLookup.isNotEmpty &&
          ref.read(sessionStoreProvider).shiftToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _performLookup(plateToLookup,
              nim: widget.nim.isNotEmpty ? widget.nim : null);
        });
      }
    }
  }

  void _onOutPlateChanged() {
    setState(() {});
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

  String get _currentCheckOutPlate => _outPlateController.text.trim().toUpperCase();

  String get _checkInPlate =>
      _session?.plateIn ?? (widget.checkInPlate.isNotEmpty ? widget.checkInPlate : '-');

  String get _currentNim =>
      _session?.nim ?? (widget.nim.isNotEmpty ? widget.nim : '-');

  String get _checkInTime {
    if (_session != null) {
      return _formatTime(_session!.checkedInAt);
    }
    return widget.checkInTime.isNotEmpty ? widget.checkInTime : '-';
  }

  String get _checkOutTime => _formatTime(DateTime.now());

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  String get _duration {
    if (_session == null) return '-';
    final diff = DateTime.now().difference(_session!.checkedInAt.toLocal());
    final totalMinutes = diff.inMinutes;
    if (totalMinutes <= 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) return '${mins}m';
    return '${hours}j ${mins}m';
  }

  String get _sessionId {
    if (_session != null) {
      return 'ID: PRK-${_session!.id.toString().padLeft(6, '0')}';
    }
    return '-';
  }

  bool get _isPlateMatched {
    if (_session == null) return false;
    final outP = _currentCheckOutPlate.replaceAll(' ', '').toUpperCase();
    if (outP.isEmpty) return false;
    final inP = _session!.plateIn.replaceAll(' ', '').toUpperCase();
    if (inP.isEmpty) return false;
    return inP == outP;
  }

  Future<void> _performLookup(String plate, {String? nim}) async {
    final cleanPlate = plate.trim().toUpperCase();
    if (cleanPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan plat nomor untuk mencari sesi.')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _lookupMessage = null;
      _candidates = const [];
      _outPhotoPath = null;
      _inPhotoBytes = null;
      _isLoadingInPhoto = false;
      _inPhotoLoadFailed = false;
      _ktmChecked = false;
      _showManualForm = false;
    });

    try {
      final result = await ref.read(sessionRepositoryProvider).lookup(
            plate: cleanPlate,
            nim: nim,
          );
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _matchMethod = result.matchMethod;
        if (result.session != null) {
          _session = result.session;
          _candidates = const [];
          _lookupMessage = null;
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
          _lookupMessage = result.message ?? 'Sesi tidak ditemukan.';
        }
      });
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _lookupMessage = failure.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(failure.message),
        ),
      );
    }
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
        _showManualForm = true;
        _outPhotoPath = null;
        _inPhotoBytes = null;
        _isLoadingInPhoto = false;
        _inPhotoLoadFailed = false;
        _ktmChecked = false;
        _nimFallbackController.text = detail.nim;
      });
      _loadInPhoto();
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(failure.message),
        ),
      );
    } catch (e) {
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
    if (path == null || !mounted) return;
    setState(() {
      _outPhotoPath = path;
    });
  }

  /// Mengambil snapshot plat saat masuk untuk perbandingan visual.
  ///
  /// Menangani state loading, foto tidak tersedia (null/kosong), dan kegagalan muat.
  Future<void> _loadInPhoto() async {
    final session = _session;
    if (session == null) {
      if (mounted) {
        setState(() {
          _inPhotoBytes = null;
          _isLoadingInPhoto = false;
          _inPhotoLoadFailed = false;
        });
      }
      return;
    }

    final photoPath = session.plateInPhotoPath?.trim();
    if (photoPath == null || photoPath.isEmpty) {
      if (mounted) {
        setState(() {
          _inPhotoBytes = null;
          _isLoadingInPhoto = false;
          _inPhotoLoadFailed = false;
        });
      }
      return;
    }

    setState(() {
      _isLoadingInPhoto = true;
      _inPhotoLoadFailed = false;
      _inPhotoBytes = null;
    });

    try {
      final bytes = await ref
          .read(sessionRepositoryProvider)
          .sessionPhoto(session.id, 'in');
      if (!mounted) return;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _inPhotoBytes = null;
          _isLoadingInPhoto = false;
          _inPhotoLoadFailed = true;
        });
        return;
      }
      setState(() {
        _inPhotoBytes = bytes;
        _isLoadingInPhoto = false;
        _inPhotoLoadFailed = false;
      });
    } on Failure {
      if (!mounted) return;
      setState(() {
        _inPhotoBytes = null;
        _isLoadingInPhoto = false;
        _inPhotoLoadFailed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inPhotoBytes = null;
        _isLoadingInPhoto = false;
        _inPhotoLoadFailed = true;
      });
    }
  }

  Future<void> _handleConfirmCheckOut() async {
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada sesi aktif yang dipilih.')),
      );
      return;
    }

    final isMatched = _isPlateMatched;
    final note = _manualNoteController.text.trim();

    if (!isMatched && note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text('Verifikasi manual wajib disertai catatan.'),
        ),
      );
      setState(() {
        _showManualForm = true;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final closedSession = await ref.read(sessionRepositoryProvider).checkOut(
            id: _session!.id,
            plate: _currentCheckOutPlate,
            status: isMatched ? 'matched' : 'manual_verified',
            note: isMatched ? null : note,
            matchMethod:
                _matchMethod ?? (isMatched ? 'plate_exact' : 'plate_similar'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(
            failure.message.isNotEmpty ? failure.message : 'Gagal check-out.',
          ),
        ),
      );
    }
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
            Expanded(
              child: Text(
                'Konfirmasi Manual?',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
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

  /// Reset penuh terhadap seluruh form dan status sesi check-out.
  void _clearSessionState() {
    setState(() {
      _session = null;
      _matchMethod = null;
      _candidates = const [];
      _lookupMessage = null;
      _outPhotoPath = null;
      _inPhotoBytes = null;
      _isLoadingInPhoto = false;
      _inPhotoLoadFailed = false;
      _outPlateController.clear();
      _nimFallbackController.clear();
      _manualNoteController.clear();
      _actionNoteController.clear();
      _ktmChecked = false;
      _isSearching = false;
      _isSubmitting = false;
      _showManualForm = false;
      _showNimSearch = false;
    });
  }

  Future<void> _submitReject(String note) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .reject(_session!.id, note: note);
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spWarn,
          content: Text('Check-out sesi #${_session!.id} berhasil ditolak. Sesi tetap aktif.'),
        ),
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(failure.message),
        ),
      );
    }
  }

  Future<void> _submitVoid(String note) async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(sessionRepositoryProvider)
          .voidSession(_session!.id, note: note);
      if (!mounted) return;
      _clearSessionState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spSuccess,
          content: Text('Sesi check-in berhasil dibatalkan (voided).'),
        ),
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(failure.message),
        ),
      );
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
                        if (_lookupMessage != null) ...[
                          const SizedBox(height: 12),
                          _buildLookupMessageBanner(),
                        ],
                        const SizedBox(height: 14),
                        _buildLiveStatusBanner(),
                        const SizedBox(height: 14),
                        _buildPlateComparisonCard(),
                        const SizedBox(height: 14),
                        _buildActiveSessionMetadata(),
                        const SizedBox(height: 14),
                        if (!_isPlateMatched || _showManualForm) ...[
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
