import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/session_store.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';
import '../widgets/spv_app_bar.dart';
import '../widgets/spv_bottom_nav.dart';
import 'login_screen.dart';

/// Kelola Shift Jaga — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/15-kelola-shift.html
///
/// Daftar shift, buka shift, dan tutup paksa shift ditulis ke backend lewat
/// `/api/shifts` memakai token pengawas. Daftar penugasan tiap shift ikut
/// ditampilkan dari respons backend.
class KelolaShiftScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;

  const KelolaShiftScreen({
    super.key,
    this.officerName = 'Dewi Kartika',
    this.officerRole = 'Pengawas (SPV)',
  });

  @override
  State<KelolaShiftScreen> createState() => _KelolaShiftScreenState();
}

class _KelolaShiftScreenState extends State<KelolaShiftScreen> {
  final ApiClient _api = ApiClient();

  List<Area> _areas = const [];
  List<Shift> _shifts = const [];
  int? _selectedAreaId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final areasJson = await _api.get('/api/areas');
      final shiftsJson = await _api.get('/api/shifts');
      if (!mounted) return;

      final areas = (areasJson as List)
          .map((e) => Area.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final shifts = (shiftsJson as List)
          .map((e) => Shift.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        _areas = areas;
        _shifts = shifts;
        final ids = areas.map((a) => a.id).toSet();
        if (_selectedAreaId == null || !ids.contains(_selectedAreaId)) {
          _selectedAreaId = areas.isEmpty ? null : areas.first.id;
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<Shift> get _openShifts =>
      _shifts.where((shift) => shift.isOpen).toList();

  List<Shift> get _history =>
      _shifts.where((shift) => !shift.isOpen).toList();

  Area? _areaOf(Shift shift) {
    for (final area in _areas) {
      if (area.id == shift.parkingAreaId) return area;
    }
    return null;
  }

  String _areaLabel(Shift shift) {
    final area = _areaOf(shift);
    return area == null ? shift.areaName : '${area.code} • ${shift.areaName}';
  }

  DateTime _toLocal(DateTime value) => DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      ).toLocal();

  String _clock(DateTime value) {
    final local = _toLocal(value);
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime value) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = _toLocal(value);
    return '${days[local.weekday - 1]}, ${local.day} '
        '${months[local.month - 1]} ${local.year}';
  }

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

  Future<void> _handleOpenShift() async {
    final areaId = _selectedAreaId;
    if (areaId == null) {
      _showFeedback(
        'Lahan belum dipilih',
        'Pilih lahan parkir terlebih dahulu.',
        isError: true,
      );
      return;
    }

    if (_openShifts.any((shift) => shift.parkingAreaId == areaId)) {
      _showFeedback(
        'Shift sudah terbuka',
        'Satu lahan hanya boleh punya satu shift terbuka.',
        isError: true,
      );
      return;
    }

    final area = _areas.firstWhere((a) => a.id == areaId);
    setState(() => _saving = true);
    try {
      await _api.post('/api/shifts/open', body: {'parking_area_id': areaId});
      if (!mounted) return;
      _showFeedback('Shift dibuka', '${area.name} mulai dijaga.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFeedback('Gagal membuka shift', e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleCloseShift(Shift shift) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _CloseShiftDialog(shift: shift, areaLabel: _areaLabel(shift)),
    );

    if (!mounted || note == null) return;

    setState(() => _saving = true);
    try {
      await _api.post('/api/shifts/${shift.id}/close', body: {'note': note});
      if (!mounted) return;
      _showFeedback('Shift ditutup', '${shift.areaName} selesai dijaga.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showFeedback('Gagal menutup shift', e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _doLogout() async {
    try {
      await _api.post('/api/auth/sign-out');
    } on ApiException {
      // Abaikan; tetap keluar dari aplikasi.
    }
    SessionStore.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
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
              _doLogout();
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
                SpvAppBar(pageTitle: 'Kelola Shift', onLogout: _handleLogout),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.spPrimary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeading(),
                          const SizedBox(height: 16),
                          _buildOpenForm(),
                          const SizedBox(height: 16),
                          _buildOpenShiftSection(),
                          const SizedBox(height: 16),
                          _buildHistorySection(),
                          const SizedBox(height: 16),
                          _buildNote(),
                          const SizedBox(height: 16),
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

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Kelola Shift\nJaga',
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
          'Buka dan tutup periode jaga per lahan parkir',
          style: TextStyle(fontSize: 13, color: AppColors.spInk2),
        ),
      ],
    );
  }

  Widget _buildOpenForm() {
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
          const Text(
            'Buka Shift',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.spInk,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lahan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: AppColors.spInk,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.spPrimary),
              ),
            )
          else if (_areas.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.spTint1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Belum ada lahan aktif. Tambahkan lahan terlebih dahulu di menu Kelola Lahan.',
                style: TextStyle(fontSize: 12, color: AppColors.spInk2),
              ),
            )
          else
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _selectedAreaId,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.spTint1,
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.spInk2,
                ),
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
                  borderSide:
                      const BorderSide(color: AppColors.spPrimary600, width: 1.5),
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.spInk2,
              ),
              items: _areas.map((area) {
                return DropdownMenuItem<int>(
                  value: area.id,
                  child: Text(
                    '${area.code} • ${area.name}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.spInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAreaId = value);
                }
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_saving || _areas.isEmpty) ? null : _handleOpenShift,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline_rounded, size: 20),
              label: const Text(
                'Buka Shift',
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
                  'Satu lahan hanya boleh punya satu shift terbuka. Petugas yang datang berikutnya bergabung ke shift ini.',
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

  Widget _buildOpenShiftSection() {
    final open = _openShifts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Shift Terbuka',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
            Text(
              '${open.length} shift berjalan',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.spPrimary),
            ),
          )
        else if (_error != null)
          _buildErrorBanner(_error!)
        else if (open.isEmpty)
          _buildEmptyShiftCard()
        else
          ...open.map(
            (shift) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildOpenShiftCard(shift),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.spDangerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline_rounded,
                  size: 18, color: AppColors.spDanger),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gagal memuat shift',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spDangerInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.spDangerInk,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba lagi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.spDangerInk,
              side: const BorderSide(color: AppColors.spDanger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyShiftCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.spBorder),
      ),
      child: Column(
        children: const [
          Icon(Icons.schedule_rounded, size: 40, color: AppColors.spInk4),
          SizedBox(height: 10),
          Text(
            'Tidak ada shift terbuka',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.spInk,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Buka shift baru untuk mulai mencatat periode jaga.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.spInk3),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftCard(Shift shift) {
    return Container(
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
                child: Text(
                  _areaLabel(shift),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.spInk3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.spSuccessBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BERJALAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.spSuccessInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.spTint1,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 14, color: AppColors.spInk2),
                const SizedBox(width: 6),
                Text(
                  'Mulai ${_clock(shift.startedAt)} WIB',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.spInk2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Petugas Bertugas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.spInk3,
            ),
          ),
          const SizedBox(height: 8),
          if (shift.assignments.isEmpty)
            const Text(
              'Belum ada petugas yang bergabung.',
              style: TextStyle(fontSize: 12, color: AppColors.spInk3),
            )
          else
            ...shift.assignments.map(_buildOfficerRow),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.spBorder),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _handleCloseShift(shift),
              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
              label: const Text(
                'Tutup Shift',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.spDanger,
                side: const BorderSide(color: AppColors.spDanger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficerRow(Assignment assignment) {
    final initials = _initials(assignment.officerName);
    final left = assignment.leftAt == null
        ? null
        : 'Keluar ${_clock(assignment.leftAt!)} WIB';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.spTint1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.spPrimary,
              shape: BoxShape.circle,
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.officerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.spInk,
                  ),
                ),
                Text(
                  left == null
                      ? 'Bergabung ${_clock(assignment.joinedAt)} WIB'
                      : 'Bergabung ${_clock(assignment.joinedAt)} WIB • $left',
                  style: const TextStyle(
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
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Widget _buildHistorySection() {
    final history = _history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Shift',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
            Text(
              '${history.length} shift terakhir',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_loading && _error == null && history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.spBorder),
            ),
            child: const Text(
              'Belum ada shift yang ditutup.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.spInk3),
            ),
          )
        else if (!_loading && _error == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.spSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.spBorder),
            ),
            child: Column(
              children: [
                for (int i = 0; i < history.length; i++) ...[
                  _buildHistoryRow(history[i]),
                  if (i != history.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: AppColors.spBorder),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryRow(Shift shift) {
    final endedAt = shift.endedAt;
    final note = shift.endNote ?? 'Ditutup tanpa catatan.';
    final isWarning = note.toLowerCase().contains('paksa');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _areaLabel(shift),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spInk3,
              ),
            ),
            const Spacer(),
            Text(
              endedAt == null
                  ? '${_clock(shift.startedAt)} WIB'
                  : '${_clock(shift.startedAt)} – ${_clock(endedAt)} WIB',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.spPrimary700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(shift.startedAt),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.spInk3,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              size: 14,
              color: isWarning ? AppColors.spWarn : AppColors.spInk2,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isWarning ? AppColors.spWarn : AppColors.spInk2,
                ),
              ),
            ),
          ],
        ),
      ],
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
              'Shift tidak pernah dihapus dan waktunya tidak pernah diedit. Koreksi dilakukan dengan menutup shift memakai catatan, lalu membuka shift baru.',
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
      currentIndex: 2,
      officerName: widget.officerName,
      officerRole: widget.officerRole,
      onLogout: _handleLogout,
    );
  }
}

/// Dialog "Tutup Shift" — meminta catatan penutupan wajib.
class _CloseShiftDialog extends StatefulWidget {
  final Shift shift;
  final String areaLabel;

  const _CloseShiftDialog({required this.shift, required this.areaLabel});

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.spSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(
            Icons.power_settings_new_rounded,
            color: AppColors.spDanger,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tutup Shift',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.areaLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk,
              ),
              decoration: InputDecoration(
                labelText: 'Catatan Penutupan',
                hintText: 'cth: pos tutup lebih awal',
                filled: true,
                fillColor: AppColors.spTint1,
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
                  borderSide: const BorderSide(
                    color: AppColors.spPrimary600,
                    width: 1.5,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Catatan wajib diisi';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
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
            'Tutup Shift',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
