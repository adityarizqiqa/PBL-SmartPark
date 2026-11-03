import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/entities/area.dart';
import '../../../../../core/entities/assignment.dart';
import '../../../../../core/entities/shift.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/name_formats.dart';
import '../../../../../core/widgets/app_snack_bar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_banner.dart';
import '../../../../../core/widgets/spv_app_bar.dart';
import '../../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../auth/presentation/providers/auth_actions.dart';
import '../providers/shifts_controller.dart';

/// Kelola Shift Jaga — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/15-kelola-shift.html
///
/// Daftar shift, buka shift, dan tutup paksa shift ditulis ke backend lewat
/// `/api/shifts` memakai token pengawas. Daftar penugasan tiap shift ikut
/// ditampilkan dari respons backend.
class ShiftsPage extends ConsumerStatefulWidget {
  const ShiftsPage({super.key, this.onLogout});

  /// Disediakan shell agar konfirmasi + sign-out terpusat di satu tempat.
  /// Null saat halaman dipakai di luar shell (mis. pengujian widget).
  final VoidCallback? onLogout;

  @override
  ConsumerState<ShiftsPage> createState() => _ShiftsPageState();
}

class _ShiftsPageState extends ConsumerState<ShiftsPage> {
  ShiftsState get _state => ref.watch(shiftsControllerProvider);
  List<Area> get _areas => _state.areas;
  int? get _selectedAreaId => _state.selectedAreaId;
  bool get _loading => _state.isLoading;
  bool get _saving => _state.isSaving;
  String? get _error => _state.failure?.message;

  Future<void> _load() =>
      ref.read(shiftsControllerProvider.notifier).refresh();

  List<Shift> get _openShifts => _state.openShifts;

  List<Shift> get _history => _state.history;

  String _areaLabel(Shift shift) => _state.areaLabelOf(shift);

  DateTime _toLocal(DateTime value) => DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      ).toLocal();


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

  Future<void> _handleOpenShift() async {
    final areaId = _selectedAreaId;
    if (areaId == null) {
      AppSnackBar.error(context, 'Pilih lahan parkir terlebih dahulu.');
      return;
    }

    if (_state.hasOpenShift(areaId)) {
      AppSnackBar.error(
        context,
        'Satu lahan hanya boleh punya satu shift terbuka.',
      );
      return;
    }

    final area = _areas.firstWhere((a) => a.id == areaId);
    final error = await ref.read(shiftsControllerProvider.notifier).open();
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, '${area.name} mulai dijaga.');
  }

  Future<void> _handleCloseShift(Shift shift) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _CloseShiftDialog(shift: shift, areaLabel: _areaLabel(shift)),
    );

    if (!mounted || note == null) return;

    final error =
        await ref.read(shiftsControllerProvider.notifier).close(shift, note);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, '${shift.areaName} selesai dijaga.');
  }

  Future<void> _handleLogout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    // Di luar shell (mis. pengujian widget): konfirmasi + keluar lokal,
    // lalu kembali ke rute pertama.
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Keluar dari Konsol Pengawas?',
      message: 'Anda akan kembali ke halaman masuk.',
    );
    if (!confirmed || !mounted) return;
    await ref.read(signOutActionProvider)();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                  ref.read(shiftsControllerProvider.notifier).selectArea(value);
                }
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: (_saving || _areas.isEmpty) ? null : _handleOpenShift,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline_rounded, size: 20),
              label: const Text(
                'Buka Shift',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
          ErrorBanner(message: _error!, onRetry: _load)
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

  Widget _buildEmptyShiftCard() {
    return const EmptyState(
      icon: Icons.schedule_rounded,
      title: 'Tidak ada shift terbuka',
      message: 'Buka shift baru untuk mulai mencatat periode jaga.',
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
                  'Mulai ${Formatters.clock(_toLocal(shift.startedAt))} WIB',
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
    final initials = NameFormats.initials(assignment.officerName);
    final left = assignment.leftAt == null
        ? null
        : 'Keluar ${Formatters.clock(_toLocal(assignment.leftAt!))} WIB';

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
                      ? 'Bergabung ${Formatters.clock(_toLocal(assignment.joinedAt))} WIB'
                      : 'Bergabung ${Formatters.clock(_toLocal(assignment.joinedAt))} WIB • $left',
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
          const EmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada shift yang ditutup',
            message: 'Riwayat shift yang sudah ditutup akan tampil di sini.',
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
                  ? '${Formatters.clock(_toLocal(shift.startedAt))} WIB'
                  : '${Formatters.clock(_toLocal(shift.startedAt))} – ${Formatters.clock(_toLocal(endedAt))} WIB',
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
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.spDanger,
          ),
          child: const Text('Tutup Shift'),
        ),
      ],
    );
  }
}
