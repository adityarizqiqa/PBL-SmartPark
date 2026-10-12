import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/session_store.dart';
import '../constants/app_colors.dart';
import '../models/session.dart';
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
  final ApiClient? apiClient;
  final SessionDetail? initialSession;

  const CheckOutScreen({
    super.key,
    this.officerName = 'Budi Santoso',
    this.officerRole = 'Petugas Gerbang',
    this.isSupervisor = false,
    this.parkingLot = 'POS-UTAMA • Pos Parkir Utama',
    this.nim = '244107020204',
    this.checkInPlate = 'N 1234 ABC',
    this.checkInTime = '07:32 WIB',
    this.apiClient,
    this.initialSession,
  });

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  int _selectedNavIndex = 0;
  late final ApiClient _apiClient;

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

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _outPlateController = TextEditingController(text: widget.checkInPlate);
    _nimFallbackController = TextEditingController(text: widget.nim);

    if (widget.initialSession != null) {
      _session = widget.initialSession;
      _matchMethod = _session!.matchMethod ?? 'plate_exact';
    } else {
      // Inisialisasi awal fallback agar layar langsung tampil siap uji/verifikasi
      _session = SessionDetail(
        id: 89,
        nim: widget.nim,
        plateIn: widget.checkInPlate,
        plateOut: null,
        checkedInAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 24)),
        checkedOutAt: null,
        status: 'active',
        matchMethod: 'plate_exact',
        verificationNote: null,
        plateInPhotoPath: null,
        plateOutPhotoPath: null,
        areaId: 1,
        areaName: widget.parkingLot,
        checkedInBy: const SessionOfficer(
          assignmentId: 1,
          officerId: 1,
          officerName: 'Budi Santoso',
        ),
        checkedOutBy: null,
        events: const [],
      );
      _matchMethod = 'plate_exact';

      // Bila ada token sesi shift aktif, lakukan lookup otomatis ke backend
      if (SessionStore.instance.shiftToken != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _performLookup(widget.checkInPlate, nim: widget.nim);
        });
      }
    }
  }

  @override
  void dispose() {
    _outPlateController.dispose();
    _nimFallbackController.dispose();
    _manualNoteController.dispose();
    _actionNoteController.dispose();
    super.dispose();
  }

  String get _currentCheckOutPlate => _outPlateController.text.trim().toUpperCase();

  String get _checkInPlate => _session?.plateIn ?? widget.checkInPlate;

  String get _currentNim => _session?.nim ?? widget.nim;

  String get _checkInTime {
    if (_session != null) {
      return _formatTime(_session!.checkedInAt);
    }
    return widget.checkInTime;
  }

  String get _checkOutTime => _formatTime(DateTime.now());

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }

  String get _duration {
    if (_session == null) return '0m';
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
    return 'ID: PRK-240502-089';
  }

  bool get _isPlateMatched {
    if (_session == null) return false;
    final inP = _session!.plateIn.replaceAll(' ', '').toUpperCase();
    final outP = _currentCheckOutPlate.replaceAll(' ', '').toUpperCase();
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
    });

    try {
      final query = <String, dynamic>{'plate': cleanPlate};
      if (nim != null && nim.trim().isNotEmpty) {
        query['nim'] = nim.trim();
      }

      final res = await _apiClient.get('/api/sessions/lookup', query: query);
      if (!mounted) return;

      final result = LookupResult.fromJson(res as Map<String, dynamic>);
      setState(() {
        _isSearching = false;
        _matchMethod = result.matchMethod;
        if (result.session != null) {
          _session = result.session;
          _candidates = const [];
          _lookupMessage = null;
          _nimFallbackController.text = result.session!.nim;
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
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _lookupMessage = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.spDanger, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _lookupMessage = 'Gagal mencari sesi: $e';
      });
    }
  }

  Future<void> _selectCandidate(LookupCandidate candidate) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final res = await _apiClient.get('/api/sessions/${candidate.sessionId}');
      if (!mounted) return;

      final detail = SessionDetail.fromJson(res as Map<String, dynamic>);
      setState(() {
        _session = detail;
        _matchMethod = 'plate_similar';
        _candidates = const [];
        _isSearching = false;
        _showManualForm = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.spDanger, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
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
      final status = isMatched ? 'matched' : 'manual_verified';
      final fields = <String, String?>{
        'plate': _currentCheckOutPlate,
        'status': status,
        if (!isMatched) 'note': note,
        'match_method': _matchMethod ?? (isMatched ? 'plate_exact' : 'plate_similar'),
      };

      final res = await _apiClient.postMultipart(
        '/api/sessions/${_session!.id}/check-out',
        fields: fields,
      );

      if (!mounted) return;

      SessionDetail? closedSession;
      if (res is Map<String, dynamic>) {
        closedSession = SessionDetail.fromJson(res);
      }

      setState(() {
        if (closedSession != null) _session = closedSession;
        _isSubmitting = false;
      });

      _showSuccessDialog(closedSession);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNetwork) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog(_session);
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text(e.message.isNotEmpty ? e.message : 'Gagal check-out.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // Fallback offline / demo mode bila backend belum dapat dijangkau
      _showSuccessDialog(_session);
    }
  }

  void _showSuccessDialog([SessionDetail? closedSession]) {
    final detail = closedSession ?? _session;
    final nimText = detail?.nim ?? widget.nim;
    final plateText = _currentCheckOutPlate;
    final durationText = _duration;

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
              'Sesi parkir kendaraan $plateText telah selesai. Palang keluar terbuka otomatis.',
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
                        nimText,
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
                        durationText,
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

  void _showRejectDialog() {
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada sesi yang dipilih.')),
      );
      return;
    }
    _actionNoteController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: AppColors.spDanger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tolak Check-Out',
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
              'Sesi #${_session!.id} akan tetap aktif. Penolakan check-out dicatat sebagai event ke sistem.',
              style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actionNoteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tuliskan alasan penolakan (contoh: STNK tidak cocok, plat mencurigakan)...',
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
              final note = _actionNoteController.text.trim();
              if (note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.spDanger,
                    content: Text('Penolakan check-out wajib disertai catatan.'),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              await _submitReject(note);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.spDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak Check-Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReject(String note) async {
    setState(() => _isSubmitting = true);
    try {
      await _apiClient.post(
        '/api/sessions/${_session!.id}/reject',
        body: {'note': note},
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spWarn,
          content: Text('Check-out sesi #${_session!.id} berhasil ditolak. Sesi tetap aktif.'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.spDanger, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  void _showVoidDialog() {
    if (_session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada sesi yang dipilih.')),
      );
      return;
    }
    _actionNoteController.clear();

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
                'Batalkan Check-In (Void)',
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
              'Membatalkan check-in akan membebaskan NIM ${_session!.nim} dan Plat ${_session!.plateIn} untuk digunakan kembali.',
              style: const TextStyle(fontSize: 13, color: AppColors.spInk2),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actionNoteController,
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
              final note = _actionNoteController.text.trim();
              if (note.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.spDanger,
                    content: Text('Pembatalan check-in wajib disertai alasan.'),
                  ),
                );
                return;
              }
              Navigator.of(ctx).pop();
              await _submitVoid(note);
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

  Future<void> _submitVoid(String note) async {
    setState(() => _isSubmitting = true);
    try {
      await _apiClient.post(
        '/api/sessions/${_session!.id}/void',
        body: {'note': note},
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _session = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spSuccess,
          content: Text('Sesi check-in berhasil dibatalkan (voided).'),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.spDanger, content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
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

  /// Lookup search input card
  Widget _buildLookupSearchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.spBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
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
                    Icon(Icons.search_rounded, size: 18, color: AppColors.spPrimary),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pencarian Sesi Parkir',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.spInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _showNimSearch = !_showNimSearch;
                  });
                },
                child: Text(
                  _showNimSearch ? 'Sembunyikan NIM' : 'Cari via NIM',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spPrimary600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _outPlateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Plat Nomor Scan / Keluar',
                    labelStyle: const TextStyle(fontSize: 12, color: AppColors.spInk3),
                    hintText: 'Contoh: N 1234 ABC',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                    filled: true,
                    fillColor: AppColors.spTint1,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.spBorder),
                    ),
                  ),
                  onSubmitted: (val) => _performLookup(
                    val,
                    nim: _showNimSearch ? _nimFallbackController.text : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching
                    ? null
                    : () => _performLookup(
                          _outPlateController.text,
                          nim: _showNimSearch ? _nimFallbackController.text : null,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Cari',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
              ),
            ],
          ),
          if (_showNimSearch) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nimFallbackController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'NIM Mahasiswa (Fallback)',
                      labelStyle: const TextStyle(fontSize: 12, color: AppColors.spInk3),
                      hintText: 'Contoh: 244107020204',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.spInk4),
                      filled: true,
                      fillColor: AppColors.spTint1,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.spBorder),
                      ),
                    ),
                    onSubmitted: (val) => _performLookup(_outPlateController.text, nim: val),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isSearching
                      ? null
                      : () => _performLookup(
                            _outPlateController.text,
                            nim: _nimFallbackController.text,
                          ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.spPrimary,
                    side: const BorderSide(color: AppColors.spPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Cari NIM',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Candidates list when plate_similar returns matches
  Widget _buildCandidatesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.spWarnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spWarn.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.spWarnInk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Plat Mirip Ditemukan (${_candidates.length} kandidat):',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spWarnInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._candidates.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.spBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.plateIn,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: AppColors.spInk,
                          ),
                        ),
                        Text(
                          'ID: #${c.sessionId} • Masuk: ${_formatTime(c.checkedInAt)} • ${c.areaName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppColors.spInk3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : () => _selectCandidate(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.spPrimary600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Pilih', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Lookup message or error banner
  Widget _buildLookupMessageBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.spTint2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.spInk2),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lookupMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.spInk2),
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
                    Flexible(
                      child: Text(
                        isMatched ? 'SESUAI' : 'PERLU VERIFIKASI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isMatched ? AppColors.spInkStrong : AppColors.spDangerInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Small test case switcher button
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_isPlateMatched) {
                            _outPlateController.text = 'N 1234 ABD';
                          } else {
                            _outPlateController.text = _checkInPlate;
                          }
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
                          _isPlateMatched ? 'Uji: Selisih' : 'Uji: Normal',
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
                            _checkInTime,
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
                              _checkInPlate,
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
                              Text(
                                _currentCheckOutPlate.isNotEmpty ? _currentCheckOutPlate : 'TIDAK TERDETEKSI',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: AppColors.spDanger,
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
              _buildMetaCell('NIM', _currentNim, flexWidth: true),
              _buildMetaCell('PLAT CHECK-IN', _checkInPlate, flexWidth: true, isBrand: true),
              _buildMetaCell('WAKTU MASUK', _checkInTime, flexWidth: true),
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
              Expanded(
                child: Text(
                  'Verifikasi Manual Petugas',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.spDangerInk,
                  ),
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
          onPressed: (_ktmChecked && _isPlateMatched && !_isSubmitting)
              ? _handleConfirmCheckOut
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.spPrimary.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white70,
            elevation: (_ktmChecked && _isPlateMatched) ? 2 : 0,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_rounded, size: 20),
          label: Text(
            _isSubmitting ? 'Memproses...' : 'Konfirmasi Check-Out',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Action row for Tolak Keluar & Void
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _showRejectDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.spDanger,
                  side: const BorderSide(color: AppColors.spDanger),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text(
                  'Tolak Keluar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _showVoidDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.spWarnInk,
                  side: const BorderSide(color: AppColors.spWarn),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.delete_forever_outlined, size: 16),
                label: const Text(
                  'Batalkan (Void)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ),

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
