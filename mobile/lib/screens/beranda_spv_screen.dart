import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/session_store.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';
import '../widgets/spv_app_bar.dart';
import '../widgets/spv_bottom_nav.dart';
import 'kelola_lahan_screen.dart';
import 'kelola_petugas_screen.dart';
import 'kelola_shift_screen.dart';
import 'login_screen.dart';

/// Beranda Pengawas (SPV)
/// Hub for the supervisor console: Kelola Lahan & Kelola Shift.
/// Styled after the SPV screens in tmp/uiux/14-16.
///
/// Ringkasan operasional diambil dari backend (`/api/areas` dan
/// `/api/shifts?open_only=true`) memakai token pengawas. Elemen yang tidak
/// punya padanan backend tetap statis.
class BerandaSpvScreen extends StatefulWidget {
  final String officerName;
  final String officerRole;

  const BerandaSpvScreen({
    super.key,
    this.officerName = 'Dewi Kartika',
    this.officerRole = 'Pengawas (SPV)',
  });

  @override
  State<BerandaSpvScreen> createState() => _BerandaSpvScreenState();
}

class _BerandaSpvScreenState extends State<BerandaSpvScreen> {
  final ApiClient _api = ApiClient();

  List<Area> _areas = const [];
  List<Shift> _openShifts = const [];
  bool _loading = true;
  String? _error;

  /// Nama petugas diambil dari sesi yang sedang aktif.
  String get _name => SessionStore.instance.officerName ?? widget.officerName;

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
      final areasJson = await _api.get(
        '/api/areas',
        query: {'include_inactive': true},
      );
      final shiftsJson = await _api.get(
        '/api/shifts',
        query: {'open_only': true},
      );
      if (!mounted) return;
      setState(() {
        _areas = (areasJson as List)
            .map((e) => Area.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _openShifts = (shiftsJson as List)
            .map((e) => Shift.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
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

  Future<void> _doLogout() async {
    try {
      await _api.post('/api/auth/sign-out');
    } on ApiException {
      // Token mungkin sudah mati; tetap lanjut keluar dari aplikasi.
    }
    SessionStore.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _handleLogout(BuildContext context) {
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
                SpvAppBar(
                  pageTitle: 'Beranda Pengawas',
                  onLogout: () => _handleLogout(context),
                ),
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
                          _buildProfileCard(),
                          const SizedBox(height: 16),
                          _buildConsoleSection(context),
                          const SizedBox(height: 16),
                          _buildStatsSection(),
                          const SizedBox(height: 16),
                          _buildNote(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                SpvBottomNav(
                  currentIndex: 0,
                  officerName: _name,
                  officerRole: widget.officerRole,
                  onLogout: () => _handleLogout(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorder),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.spTint3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.assignment_ind_outlined,
                            size: 12,
                            color: AppColors.spPrimary700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'KONSOL PENGAWAS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: AppColors.spPrimary700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.spPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: AppColors.spInk3,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.officerRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.spInk3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.spPrimary, AppColors.spPrimary700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.spPrimary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.manage_accounts_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.spPrimary600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'KONSOL PENGAWAS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.spPrimary,
            ),
          ),
        ),
        _buildConsoleCard(
          context: context,
          title: 'Kelola Lahan',
          subtitle: 'Tambah, ubah & nonaktifkan lahan parkir',
          icon: Icons.map_rounded,
          colors: const [AppColors.spPrimary, AppColors.spPrimary700],
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => KelolaLahanScreen(
                  officerName: _name,
                  officerRole: widget.officerRole,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildConsoleCard(
          context: context,
          title: 'Kelola Shift',
          subtitle: 'Buka & tutup periode jaga per lahan',
          icon: Icons.schedule_rounded,
          colors: const [AppColors.spPrimary600, AppColors.spPrimary700],
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => KelolaShiftScreen(
                  officerName: _name,
                  officerRole: widget.officerRole,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildConsoleCard(
          context: context,
          title: 'Kelola Petugas',
          subtitle: 'Akun petugas gerbang & pengawas',
          icon: Icons.groups_rounded,
          colors: const [AppColors.spPrimary600, AppColors.spPrimary800],
          onTap: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => KelolaPetugasScreen(
                  officerName: _name,
                  officerRole: widget.officerRole,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildConsoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
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

  Widget _buildStatsSection() {
    final total = _areas.length;
    final active = _areas.where((area) => area.isActive).length;
    final running = _openShifts.length;

    String value(int count) => _loading ? '…' : '$count';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'RINGKASAN OPERASIONAL',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.spPrimary,
            ),
          ),
        ),
        if (_error != null) ...[
          _buildErrorBanner(_error!),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Lahan',
                value: value(total),
                valueColor: AppColors.spPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Aktif',
                value: value(active),
                valueColor: AppColors.spSuccessInk,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Shift Berjalan',
                value: value(running),
                valueColor: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.spDangerBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.spDanger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.spDanger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.spDangerInk,
              ),
            ),
          ),
          TextButton(
            onPressed: _loading ? null : _load,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Coba lagi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.spDangerInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.spInk3,
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
              'Kelola lahan untuk mengatur titik parkir kampus, lalu buka shift agar petugas dapat mulai mencatat periode jaga di setiap lahan.',
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
