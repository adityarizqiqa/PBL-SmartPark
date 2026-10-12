import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../api/session_store.dart';
import '../constants/app_colors.dart';
import '../models/models.dart';
import 'beranda_screen.dart';
import 'beranda_spv_screen.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const LoginScreen({super.key, this.apiClient});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  late final ApiClient _apiClient = widget.apiClient ?? ApiClient();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _initialError;

  List<Officer> _officers = [];
  Officer? _selectedOfficer;

  List<Area> _areas = [];
  Area? _selectedArea;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isInitialLoading = true;
      _initialError = null;
    });

    try {
      final officersData = await _apiClient.get('/api/officers');
      final areasData = await _apiClient.get('/api/areas');

      final officers = (officersData as List)
          .map((e) => Officer.fromJson((e as Map).cast<String, dynamic>()))
          .where((o) => o.isActive)
          .toList();
      final areas = (areasData as List)
          .map((e) => Area.fromJson((e as Map).cast<String, dynamic>()))
          .where((a) => a.isActive)
          .toList();

      if (!mounted) return;
      setState(() {
        _officers = officers;
        _areas = areas;
        if (_officers.isNotEmpty) {
          _selectedOfficer = _officers.first;
        }
        if (_areas.isNotEmpty) {
          _selectedArea = _areas.first;
        }
        _isInitialLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _initialError = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _initialError = 'Gagal memuat data: $e';
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final officer = _selectedOfficer;
    if (officer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text('Pilih nama petugas terlebih dahulu.'),
        ),
      );
      return;
    }

    if (!officer.isSupervisor && _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.spDanger,
          content: Text('Pilih lahan parkir terlebih dahulu.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (officer.isSupervisor) {
        final res = await _apiClient.post(
          '/api/auth/sign-in',
          body: {
            'officer_id': officer.id,
            'password': _passwordController.text.trim(),
          },
        );

        final token = res['token'] as String;
        final session = (res['session'] as Map).cast<String, dynamic>();

        SessionStore.instance.setOfficerSession(
          token: token,
          id: session['officer_id'] as int,
          name: session['officer_name'] as String,
          userRole: session['role'] as String,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.spPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sesi aktif: ${officer.name} (SPV)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BerandaSpvScreen(
              officerName: officer.name,
              officerRole: 'Pengawas (SPV)',
            ),
          ),
        );
      } else {
        final area = _selectedArea!;
        final res = await _apiClient.post(
          '/api/shifts/join',
          body: {
            'officer_id': officer.id,
            'password': _passwordController.text.trim(),
            'parking_area_id': area.id,
          },
        );

        final shiftLogin = ShiftLogin.fromJson(
          (res as Map).cast<String, dynamic>(),
        );

        SessionStore.instance.setShiftSession(
          shiftLogin,
          userRole: officer.role,
        );

        if (!mounted) return;
        final parkingLotStr = '${area.code} • ${area.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.spPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sesi aktif: ${officer.name} (${area.code})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BerandaScreen(
              officerName: officer.name,
              officerRole: 'Petugas Gerbang',
              isSupervisor: false,
              parkingLot: parkingLotStr,
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.spDanger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gagal masuk: $e',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildBrandingHeader(),
                    const SizedBox(height: 24),
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    _buildTwoEntryPathsCard(),
                    const SizedBox(height: 28),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// App Logo & Branding Header
  Widget _buildBrandingHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.spPrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.directions_car,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'SmartPark',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColors.spPrimary,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'KAMPUS',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Sistem Keamanan & Manajemen Parkir\nKampus Terpadu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.spInk2,
            ),
          ),
        ),
      ],
    );
  }

  /// Main Login Container Card
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorder),
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
          // Header: Icon + Title
          Row(
            children: const [
              Icon(
                Icons.assignment_outlined,
                size: 20,
                color: AppColors.spPrimary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aktivasi Sesi Pos Lahan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.spInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isInitialLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: const [
                    CircularProgressIndicator(
                      color: AppColors.spPrimary,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data petugas & lahan...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.spInk3,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_initialError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 36,
                      color: AppColors.spDanger,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _initialError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.spDanger,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchInitialData,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.spPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Input 1: Nama Petugas
            _buildOfficerPickerField(),
            const SizedBox(height: 16),

            // Input 2: Password
            _buildPasswordField(),
            const SizedBox(height: 16),

            // Input 3: Pilih Lahan Parkir
            _buildParkingLotField(),
            const SizedBox(height: 20),

            // Submit Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.spPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.login_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Mulai Bertugas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Field 1: Role picker (List of officers)
  Widget _buildOfficerPickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Nama Petugas',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            Text(
              'Wajib Diisi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.spBorderMid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: List.generate(_officers.length, (index) {
                final officer = _officers[index];
                final isSelected = officer.id == _selectedOfficer?.id;
                final isLast = index == _officers.length - 1;

                return Column(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedOfficer = officer;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        color: isSelected ? AppColors.spTint2 : Colors.transparent,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                              color: AppColors.spInk2,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    officer.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.spInk,
                                    ),
                                  ),
                                  if (officer.isSupervisor) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.spTint3,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'SPV',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.spPrimary600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AppColors.spPrimary,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.spBorder,
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pilih nama Anda. Peran menentukan menu yang muncul setelah masuk.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.spInk3,
          ),
        ),
      ],
    );
  }

  /// Field 2: Password
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Password',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            Text(
              'Wajib Diisi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.spPrimary600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.spInk,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.spTint1,
            hintText: 'Masukkan password petugas',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.spDanger,
                width: 1.2,
              ),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password wajib diisi';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Field 3: Pilih Lahan Parkir
  Widget _buildParkingLotField() {
    final isSupervisor = _selectedOfficer?.isSupervisor ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pilih Lahan Parkir',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.spInk,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                isSupervisor
                    ? 'Opsional untuk SPV'
                    : 'Diperlukan untuk petugas gerbang.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: isSupervisor ? AppColors.spSuccess : AppColors.spInk3,
                  fontWeight:
                      isSupervisor ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Area>(
          isExpanded: true,
          initialValue: _selectedArea,
          decoration: InputDecoration(
            filled: true,
            fillColor: isSupervisor
                ? AppColors.spTint1.withValues(alpha: 0.5)
                : AppColors.spTint1,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              size: 20,
              color: AppColors.spInk2,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.spInk2,
          ),
          items: _areas.map((Area area) {
            return DropdownMenuItem<Area>(
              value: area,
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
          onChanged: (Area? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedArea = newValue;
              });
            }
          },
          validator: (value) {
            if (!isSupervisor && value == null) {
              return 'Pilih lahan parkir terlebih dahulu';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Two entry paths card ("Dua Jalur Masuk")
  Widget _buildTwoEntryPathsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.spSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.spBorderSoft),
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
            'Dua Jalur Masuk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.spInk,
            ),
          ),
          const SizedBox(height: 12),
          _buildPathRow(
            icon: Icons.person_outline_rounded,
            title: 'Petugas Gerbang',
            description:
                'Memproses check-in dan check-out. Wajib memilih lahan jaga.',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(
              height: 1,
              color: AppColors.spBorderSoft,
            ),
          ),
          _buildPathRow(
            icon: Icons.assignment_outlined,
            title: 'Pengawas (SPV)',
            description:
                'Menambah lahan dan mengatur shift jaga. Tidak perlu memilih lahan.',
          ),
        ],
      ),
    );
  }

  Widget _buildPathRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.spTint2,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.spPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.spInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.spInk3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Security & Institutional Stamp Footer
  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: AppColors.spPrimary,
            ),
            SizedBox(width: 6),
            Text(
              'Keamanan Data Kampus Terenkripsi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.25,
                color: AppColors.spInk2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'SmartPark Official • Divisi K3L & Keamanan Kampus',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.spInk3,
          ),
        ),
      ],
    );
  }
}
