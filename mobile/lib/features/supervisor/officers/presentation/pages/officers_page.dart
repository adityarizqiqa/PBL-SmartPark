import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/entities/officer.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/widgets/app_snack_bar.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_banner.dart';
import '../../../../../core/widgets/spv_app_bar.dart';
import '../../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../auth/presentation/providers/auth_actions.dart';
import '../providers/officers_controller.dart';

/// Kelola Petugas — Konsol Pengawas (SPV)
/// Mapped from tmp/uiux/16-kelola-petugas.html
///
/// Daftar, tambah, ubah peran, atur password, dan aktif/nonaktif akun ditulis
/// ke backend lewat `/api/officers` memakai token pengawas.
class OfficersPage extends ConsumerStatefulWidget {
  const OfficersPage({super.key, this.onLogout});

  /// Disediakan shell agar konfirmasi + sign-out terpusat di satu tempat.
  /// Null saat halaman dipakai di luar shell (mis. pengujian widget).
  final VoidCallback? onLogout;

  @override
  ConsumerState<OfficersPage> createState() => _OfficersPageState();
}

class _OfficersPageState extends ConsumerState<OfficersPage> {
  static const List<String> _roleLabels = [
    'Petugas Gerbang',
    'Pengawas (SPV)',
  ];

  final TextEditingController _nipController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  String _selectedRole = _roleLabels.first;
  bool _obscurePassword = true;

  OfficersState get _state => ref.watch(officersControllerProvider);
  List<Officer> get _officers => _state.officers;
  bool get _loading => _state.isLoading;
  bool get _saving => _state.isSaving;
  String? get _error => _state.failure?.message;

  @override
  void dispose() {
    _nipController.dispose();
    _namaController.dispose();
    _hpController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      ref.read(officersControllerProvider.notifier).refresh();

  int get _activeCount => _state.activeCount;

  int get _missingPasswordCount => _state.missingPasswordCount;

  bool get _isSupervisorRole => _selectedRole == _roleLabels[1];

  String get _selectedRoleValue => _isSupervisorRole ? 'spv' : 'officer';

  Future<void> _handleAdd() async {
    final name = _namaController.text.trim();
    final nipInput = Validators.normalizeCode(_nipController.text);
    final phone = _hpController.text.trim();
    final password = _passController.text;

    if (name.isEmpty) {
      AppSnackBar.error(context, 'Nama petugas wajib diisi.');
      return;
    }

    if (password.length < 6) {
      AppSnackBar.error(context, 'Password minimal 6 karakter.');
      return;
    }

    final error = await ref.read(officersControllerProvider.notifier).create(
          name: name,
          password: password,
          role: _selectedRoleValue,
          employeeNo: nipInput.isEmpty ? null : nipInput,
          phone: phone.isEmpty ? null : phone,
        );
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    _nipController.clear();
    _namaController.clear();
    _hpController.clear();
    _passController.clear();
    setState(() => _selectedRole = _roleLabels.first);
    FocusScope.of(context).unfocus();
    AppSnackBar.success(context, '$name berhasil ditambahkan.');
  }

  Future<void> _setPassword(Officer officer) async {
    final newPassword = await showDialog<String>(
      context: context,
      builder: (_) => _SetPasswordDialog(officer: officer),
    );

    if (!mounted) return;
    if (newPassword == null || newPassword.length < 6) return;

    final error = await ref
        .read(officersControllerProvider.notifier)
        .setPassword(officer, newPassword);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, 'Password ${officer.name} tersimpan.');
  }

  Future<void> _toggleActive(Officer officer) async {
    final error = await ref
        .read(officersControllerProvider.notifier)
        .toggleActive(officer);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, officer.isActive? '${officer.name} tidak boleh masuk sampai diaktifkan kembali.': '${officer.name} boleh masuk kembali.',);
  }

  Future<void> _changeRole(Officer officer) async {
    final nextLabel = officer.isSupervisor ? 'Petugas Gerbang' : 'Pengawas (SPV)';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.spSurface,
        shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
        title: const Text(
          'Ubah Peran Petugas?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.spInk,
          ),
        ),
        content: Text(
          '${officer.name} akan menjadi $nextLabel.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.spInk2,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: AppColors.spInk3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ubah'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    final error =
        await ref.read(officersControllerProvider.notifier).changeRole(officer);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    AppSnackBar.success(context, '${officer.name} kini $nextLabel.');
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
                SpvAppBar(pageTitle: 'Kelola Petugas', onLogout: _handleLogout),
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
                          _buildOfficerList(),
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
          'Kelola\nPetugas',
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
          'Akun petugas gerbang dan pengawas',
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
            value: _loading ? '…' : '${_officers.length}',
            label: 'Petugas',
            valueColor: AppColors.spPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: _loading ? '…' : '$_activeCount',
            label: 'Aktif',
            valueColor: AppColors.spSuccessInk,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            value: _loading ? '…' : '$_missingPasswordCount',
            label: 'Belum Berpassword',
            valueColor: AppColors.spWarn,
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
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.45,
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
                'Tambah Petugas',
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
          _buildFieldLabel('NIP / ID Petugas'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _nipController,
            hint: 'cth: PK004',
            icon: Icons.badge_outlined,
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Nama Lengkap'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _namaController,
            hint: 'cth: Rina Kartika',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Nomor HP'),
          const SizedBox(height: 8),
          _buildInput(
            controller: _hpController,
            hint: 'cth: 081200000004',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Peran'),
          const SizedBox(height: 8),
          _buildRoleField(),
          const SizedBox(height: 12),
          _buildFieldLabel('Password'),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 16),
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
                'Tambah Petugas',
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
                  'NIP harus unik bila diisi. Password minimal 6 karakter.',
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
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
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
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.spPrimary600, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRoleField() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _selectedRole,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: AppColors.spInk2,
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.spInk,
      ),
      decoration: InputDecoration(
        prefixIcon: const Icon(
          Icons.badge_outlined,
          size: 20,
          color: AppColors.spInk2,
        ),
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
          borderSide: const BorderSide(color: AppColors.spPrimary600, width: 1.5),
        ),
      ),
      items: _roleLabels
          .map(
            (role) => DropdownMenuItem<String>(value: role, child: Text(role)),
          )
          .toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedRole = newValue;
          });
        }
      },
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passController,
      obscureText: _obscurePassword,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.spInk,
      ),
      decoration: InputDecoration(
        hintText: 'Minimal 6 karakter',
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.spInk4,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: AppColors.spInk2,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 20,
            color: AppColors.spInk2,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
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
          borderSide: const BorderSide(color: AppColors.spPrimary600, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildOfficerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daftar Petugas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.spInk,
              ),
            ),
            Flexible(
              child: Text(
                _loading ? 'Memuat…' : '${_officers.length} akun terdaftar',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.spInk3,
                ),
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
        else if (_officers.isEmpty)
          const EmptyState(
            icon: Icons.groups_outlined,
            title: 'Belum ada petugas',
            message: 'Tambahkan akun petugas pertama lewat formulir di atas.',
          )
        else
          ..._officers.map(_buildOfficerCard),
      ],
    );
  }

  Widget _buildOfficerCard(Officer officer) {
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
                      officer.employeeNo ?? 'Tanpa NIP',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.spInk3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      officer.name,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saving ? null : () => _changeRole(officer),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: officer.isSupervisor
                          ? AppColors.spPrimary
                          : AppColors.spTint3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      officer.isSupervisor ? 'SPV' : 'PETUGAS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: officer.isSupervisor
                            ? Colors.white
                            : AppColors.spInk2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCredentialBar(officer),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _setPassword(officer),
                  icon: const Icon(Icons.lock_outline_rounded, size: 16),
                  label: const Text('Atur Password'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: officer.hasPassword
                        ? AppColors.spTint2
                        : AppColors.spPrimary,
                    foregroundColor: officer.hasPassword
                        ? AppColors.spInk
                        : Colors.white,
                    side: officer.hasPassword
                        ? const BorderSide(color: AppColors.spBorderMid)
                        : BorderSide.none,
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
                  onPressed: _saving ? null : () => _toggleActive(officer),
                  icon: Icon(
                    officer.isActive
                        ? Icons.power_settings_new_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(officer.isActive ? 'Nonaktifkan' : 'Aktifkan'),
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

  Widget _buildCredentialBar(Officer officer) {
    final Color background;
    final Color ink;
    final Color dot;
    final String label;

    if (!officer.isActive) {
      background = AppColors.spDangerBg;
      ink = AppColors.spDangerInk;
      dot = AppColors.spDanger;
      label = 'Nonaktif • tidak boleh masuk';
    } else if (!officer.hasPassword) {
      background = AppColors.spWarnBg;
      ink = AppColors.spWarnInk;
      dot = AppColors.spWarn;
      label = 'Aktif • password belum diatur';
    } else {
      background = AppColors.spTint1;
      ink = AppColors.spInk2;
      dot = AppColors.spSuccess;
      label = 'Aktif • password terpasang';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: ink,
              ),
            ),
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
              'Petugas tidak pernah dihapus — cukup dinonaktifkan. Password hanya bisa dibuat atau diganti dari layar ini; tidak ada reset mandiri. Petugas tanpa password tidak boleh masuk.',
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

/// Dialog "Atur Password" for one officer account.
/// Owns its controller so disposal happens with the dialog route, not with
/// [_KelolaPetugasScreenState] while the route is still animating out.
class _SetPasswordDialog extends StatefulWidget {
  final Officer officer;

  const _SetPasswordDialog({required this.officer});

  @override
  State<_SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends State<_SetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officer = widget.officer;

    return AlertDialog(
      backgroundColor: AppColors.spSurface,
      shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
      title: Row(
        children: const [
          Icon(
            Icons.lock_outline_rounded,
            color: AppColors.spPrimary,
            size: 22,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Atur Password',
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
              '${officer.name} • ${officer.employeeNo ?? 'Tanpa NIP'}',
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
              obscureText: true,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.spInk,
              ),
              decoration: InputDecoration(
                labelText: 'Password Baru',
                hintText: 'Minimal 6 karakter',
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
                if (value == null || value.isEmpty) {
                  return 'Password wajib diisi';
                }
                if (value.length < 6) {
                  return 'Password minimal 6 karakter';
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
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text(
            'Simpan',
          ),
        ),
      ],
    );
  }
}
