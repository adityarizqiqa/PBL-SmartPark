import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/entities/area.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_snack_bar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_banner.dart';
import '../../../../../core/widgets/spv_app_bar.dart';
import '../../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../auth/presentation/providers/auth_actions.dart';
import '../providers/areas_controller.dart';

/// Kelola Lahan Parkir — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/14-kelola-lahan.html
///
/// Daftar, tambah, ubah nama, dan aktif/nonaktif lahan ditulis ke backend
/// lewat `/api/areas` memakai token pengawas.
class AreasPage extends ConsumerStatefulWidget {
  const AreasPage({super.key, this.onLogout});

  /// Disediakan shell agar konfirmasi + sign-out terpusat di satu tempat.
  /// Null saat halaman dipakai di luar shell (mis. pengujian widget).
  final VoidCallback? onLogout;

  @override
  ConsumerState<AreasPage> createState() => _AreasPageState();
}

class _AreasPageState extends ConsumerState<AreasPage> {
  final TextEditingController _kodeController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();

  AreasState get _state => ref.watch(areasControllerProvider);
  List<Area> get _areas => _state.areas;
  Map<int, int> get _openShiftCounts => _state.openShiftCounts;
  bool get _loading => _state.isLoading;
  bool get _saving => _state.isSaving;
  String? get _error => _state.failure?.message;

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      ref.read(areasControllerProvider.notifier).refresh();

  int get _activeCount => _state.activeCount;
  int get _inactiveCount => _state.inactiveCount;

  Future<void> _handleAdd() async {
    final code = Validators.normalizeCode(_kodeController.text);
    final name = _namaController.text.trim();

    if (code.isEmpty || name.isEmpty) {
      AppSnackBar.error(context, 'Kode dan nama lahan wajib diisi.');
      return;
    }

    final error = await ref
        .read(areasControllerProvider.notifier)
        .create(code: code, name: name);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    _kodeController.clear();
    _namaController.clear();
    FocusScope.of(context).unfocus();
    AppSnackBar.success(context, '$name ($code) berhasil ditambahkan.');
  }

  Future<void> _toggleActive(Area area) async {
    final openShifts = _openShiftCounts[area.id] ?? 0;
    if (area.isActive && openShifts > 0) {
      AppSnackBar.error(
        context,
        'Tutup $openShifts shift terbuka di lahan ini terlebih dahulu.',
      );
      return;
    }

    final error =
        await ref.read(areasControllerProvider.notifier).toggleActive(area);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(
      context,
      area.isActive
          ? '${area.name} disembunyikan dari daftar pilih saat mulai bertugas.'
          : '${area.name} kembali muncul saat mulai bertugas.',
    );
  }

  Future<void> _editLot(Area area) async {
    final controller = TextEditingController(text: area.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
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
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted) return;
    final trimmed = newName?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == area.name) return;

    final error =
        await ref.read(areasControllerProvider.notifier).rename(area, trimmed);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, 'Nama lahan menjadi "$trimmed".');
  }

  Future<void> _handleLogout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
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
                SpvAppBar(pageTitle: 'Kelola Lahan', onLogout: _handleLogout),
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
            value: _loading ? '…' : '${_areas.length}',
            label: 'LAHAN',
            valueColor: AppColors.spPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: _loading ? '…' : '$_activeCount',
            label: 'AKTIF',
            valueColor: AppColors.spSuccessInk,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: _loading ? '…' : '$_inactiveCount',
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
            child: FilledButton.icon(
              onPressed: _saving ? null : _handleAdd,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_rounded, size: 20),
              label: const Text(
                'Tambah Lahan',
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
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
              _loading ? 'Memuat…' : '${_areas.length} lahan terdaftar',
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
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.spPrimary),
            ),
          )
        else if (_error != null)
          ErrorBanner(message: _error!, onRetry: _load)
        else if (_areas.isEmpty)
          const EmptyState(
            icon: Icons.map_outlined,
            title: 'Belum ada lahan',
            message: 'Tambahkan lahan parkir pertama lewat formulir di atas.',
          )
        else
          ..._areas.map(_buildLotCard),
      ],
    );
  }

  Widget _buildLotCard(Area area) {
    final openShifts = _openShiftCounts[area.id] ?? 0;
    final hasOpenShift = openShifts > 0;

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
                      area.code,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.spInk3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      area.name,
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
                  color: area.isActive ? AppColors.spTint3 : AppColors.spDangerBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  area.isActive ? 'AKTIF' : 'NONAKTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: area.isActive
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      ? 'Shift terbuka: $openShifts'
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
                  onPressed: _saving ? null : () => _editLot(area),
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
                  onPressed: _saving ? null : () => _toggleActive(area),
                  icon: Icon(
                    area.isActive
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(area.isActive ? 'Nonaktifkan' : 'Aktifkan'),
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
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

}
