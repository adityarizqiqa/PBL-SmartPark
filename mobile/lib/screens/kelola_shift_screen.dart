import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/spv_app_bar.dart';
import '../widgets/spv_bottom_nav.dart';
import 'login_screen.dart';

/// Data model for an officer assigned to a shift
class ShiftOfficer {
  final String name;
  final String joinedAt;

  const ShiftOfficer({required this.name, required this.joinedAt});

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Data model for the currently open shift
class OpenShift {
  final String lotCode;
  final String lotName;
  final String startTime;
  final List<ShiftOfficer> officers;

  const OpenShift({
    required this.lotCode,
    required this.lotName,
    required this.startTime,
    required this.officers,
  });
}

/// Data model for a closed shift in the history list
class ShiftHistoryItem {
  final String lotCode;
  final String timeRange;
  final String date;
  final String note;
  final bool isWarning;

  const ShiftHistoryItem({
    required this.lotCode,
    required this.timeRange,
    required this.date,
    required this.note,
    this.isWarning = false,
  });
}

/// Kelola Shift Jaga — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/15-kelola-shift.html
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
  final TextEditingController _noteController = TextEditingController();

  static const List<String> _lotOptions = [
    'POS-UTAMA • Pos Parkir Utama',
    'POS-CLIMBING • Pos Parkir Climbing',
  ];

  String _selectedLot = _lotOptions.first;

  OpenShift? _openShift = const OpenShift(
    lotCode: 'POS-UTAMA',
    lotName: 'Pos Parkir Utama',
    startTime: '06:00',
    officers: [
      ShiftOfficer(name: 'Budi Santoso', joinedAt: '06:00 WIB'),
      ShiftOfficer(name: 'Sari Wulandari', joinedAt: '06:12 WIB'),
    ],
  );

  final List<ShiftHistoryItem> _history = [
    ShiftHistoryItem(
      lotCode: 'POS-UTAMA',
      timeRange: '06:00 – 14:00 WIB',
      date: 'Sen, 5 Okt 2026',
      note: 'Ditutup normal setelah serah terima kunci',
    ),
    ShiftHistoryItem(
      lotCode: 'POS-CLIMBING',
      timeRange: '06:00 – 14:00 WIB',
      date: 'Sen, 5 Okt 2026',
      note: 'Ditutup paksa — shift lupa ditutup',
      isWarning: true,
    ),
    ShiftHistoryItem(
      lotCode: 'POS-CLIMBING',
      timeRange: '06:00 – 14:00 WIB',
      date: 'Min, 4 Okt 2026',
      note: 'Ditutup lebih awal karena hujan deras',
    ),
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _clockLabel() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatDate(DateTime date) {
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
    return '${days[date.weekday - 1]}, ${date.day} '
        '${months[date.month - 1]} ${date.year}';
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

  void _handleOpenShift() {
    if (_openShift != null) {
      _showFeedback(
        'Shift sudah terbuka',
        'Satu lahan hanya boleh punya satu shift terbuka.',
        isError: true,
      );
      return;
    }

    final parts = _selectedLot.split(' • ');
    final code = parts.first.trim();
    final name = parts.length > 1 ? parts.last.trim() : code;

    setState(() {
      _openShift = OpenShift(
        lotCode: code,
        lotName: name,
        startTime: _clockLabel(),
        officers: [
          ShiftOfficer(name: widget.officerName, joinedAt: '${_clockLabel()} WIB'),
        ],
      );
    });
    _showFeedback('Shift dibuka', '$name mulai dijaga pada ${_clockLabel()} WIB.');
  }

  void _handleCloseShift() {
    final shift = _openShift;
    if (shift == null) return;

    final note = _noteController.text.trim();
    if (note.isEmpty) {
      _showFeedback(
        'Catatan wajib diisi',
        'Isi catatan penutupan sebelum menutup shift.',
        isError: true,
      );
      return;
    }

    setState(() {
      _history.insert(
        0,
        ShiftHistoryItem(
          lotCode: shift.lotCode,
          timeRange: '${shift.startTime} – ${_clockLabel()} WIB',
          date: _formatDate(DateTime.now()),
          note: note,
        ),
      );
      _openShift = null;
      _noteController.clear();
    });
    FocusScope.of(context).unfocus();
    _showFeedback('Shift ditutup', '${shift.lotName} selesai dijaga.');
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
                SpvAppBar(pageTitle: 'Kelola Shift', onLogout: _handleLogout),
                Expanded(
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
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedLot,
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
            items: _lotOptions.map((String lot) {
              return DropdownMenuItem<String>(
                value: lot,
                child: Text(
                  lot,
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
                setState(() {
                  _selectedLot = value;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _handleOpenShift,
              icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
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
    final shift = _openShift;

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
              shift == null ? '0 shift berjalan' : '1 shift berjalan',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shift == null) _buildEmptyShiftCard() else _buildOpenShiftCard(shift),
      ],
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

  Widget _buildOpenShiftCard(OpenShift shift) {
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
                  '${shift.lotCode} • ${shift.lotName}',
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
                  'Mulai ${shift.startTime} WIB',
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
          ...shift.officers.map(_buildOfficerRow),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.spBorder),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Catatan Penutupan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: AppColors.spInk,
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spDanger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.spInk,
            ),
            decoration: InputDecoration(
              hintText: 'cth: pos tutup lebih awal',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.spInk4,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.spInk2),
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
                borderSide:
                    const BorderSide(color: AppColors.spPrimary600, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleCloseShift,
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

  Widget _buildOfficerRow(ShiftOfficer officer) {
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
              officer.initials,
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
                  officer.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.spInk,
                  ),
                ),
                Text(
                  'Bergabung ${officer.joinedAt}',
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

  Widget _buildHistorySection() {
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
              '${_history.length} shift terakhir',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.spSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.spBorder),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _history.length; i++) ...[
                _buildHistoryRow(_history[i]),
                if (i != _history.length - 1)
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

  Widget _buildHistoryRow(ShiftHistoryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              item.lotCode,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spInk3,
              ),
            ),
            const Spacer(),
            Text(
              item.timeRange,
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
          item.date,
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
              item.isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              size: 14,
              color: item.isWarning ? AppColors.spWarn : AppColors.spInk2,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.note,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: item.isWarning ? AppColors.spWarn : AppColors.spInk2,
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
