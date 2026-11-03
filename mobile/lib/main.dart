import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'core/di/providers.dart';
import 'core/network/api_client.dart';
import 'core/session/officer_identity.dart';
import 'core/session/session_scope.dart';
import 'core/utils/formatters.dart';
import 'core/widgets/app_bottom_nav.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_actions.dart';
import 'features/dashboard/presentation/pages/officer_home_page.dart';
import 'features/history/presentation/pages/history_page_view.dart';
import 'features/vehicles/domain/entities/active_vehicle.dart';
import 'features/vehicles/presentation/pages/vehicles_page.dart';
import 'features/supervisor/areas/presentation/pages/areas_page.dart';
import 'features/supervisor/home/presentation/pages/supervisor_home_page.dart';
import 'features/supervisor/officers/presentation/pages/officers_page.dart';
import 'features/supervisor/shifts/presentation/pages/shifts_page.dart';
import 'features/session_ops/presentation/pages/check_in_page.dart';
import 'features/session_ops/presentation/pages/check_out_page.dart';

void main() {
  runApp(const SmartParkApp());
}

class SmartParkApp extends StatelessWidget {
  const SmartParkApp({super.key, this.httpClient});

  /// Klien HTTP pengganti untuk pengujian; `null` berarti klien sungguhan.
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (httpClient != null)
          apiClientProvider.overrideWithValue(ApiClient(client: httpClient)),
      ],
      child: MaterialApp(
        title: 'SmartPark Kampus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _EntryPoint(),
      ),
    );
  }
}

/// Halaman pertama: masuk, lalu menuju beranda sesuai peran.
///
/// Layar selain beranda masih memakai kode lama, jadi sesi juga dicerminkan ke
/// penyimpanan lama sampai seluruh layar pindah ke `features/`.
class _EntryPoint extends ConsumerWidget {
  const _EntryPoint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoginPage(onSignedIn: (result) => _openHome(context, ref, result));
  }

  void _openHome(BuildContext context, WidgetRef ref, SignInResult result) {
    final navigator = Navigator.of(context);
    switch (result) {
      case SupervisorSignedIn():
        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const SupervisorShell()),
        );
      case OfficerJoinedShift():
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => const OfficerShell(),
          ),
        );
    }
  }
}

/// Kerangka navigasi pengawas: beranda, lahan, shift, petugas.
class SupervisorShell extends ConsumerStatefulWidget {
  const SupervisorShell({super.key});

  @override
  ConsumerState<SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends ConsumerState<SupervisorShell> {
  int _index = 0;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Konsol Pengawas?'),
        content: const Text('Anda akan kembali ke halaman masuk.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(signOutActionProvider)();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _EntryPoint()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      1 => const AreasPage(),
      2 => const ShiftsPage(),
      3 => const OfficersPage(),
      _ => SupervisorHomePage(
          onOpenAreas: () => setState(() => _index = 1),
          onOpenShifts: () => setState(() => _index = 2),
          onOpenOfficers: () => setState(() => _index = 3),
          onLogout: _logout,
        ),
    };

    return Column(
      children: [
        Expanded(child: page),
        AppBottomNav(
          currentIndex: _index,
          destinations: AppBottomNav.supervisorDestinations,
          onTap: (index) {
            if (index == 4) {
              _logout();
              return;
            }
            setState(() => _index = index);
          },
        ),
      ],
    );
  }
}

/// Kerangka navigasi petugas gerbang: beranda, kendaraan, riwayat.
///
/// Ketiga tujuan berbagi satu route agar state beranda tidak dibuang saat
/// berpindah tab; check-in dan check-out dibuka sebagai halaman terpisah.
class OfficerShell extends ConsumerStatefulWidget {
  const OfficerShell({super.key});

  @override
  ConsumerState<OfficerShell> createState() => _OfficerShellState();
}

class _OfficerShellState extends ConsumerState<OfficerShell> {
  int _index = 0;

  OfficerIdentity? get _identity => ref.read(officerIdentityProvider);

  Future<void> _logout() async {
    final confirmed = await _confirmLogout();
    if (!confirmed || !mounted) return;
    final failure = await ref.read(leaveShiftActionProvider)('Petugas keluar');
    if (!mounted) return;
    if (failure != null) {
      // Shift belum tentu tertutup di server: tahan di sini agar petugas
      // tidak terkunci saat masuk lagi.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengakhiri shift: ${failure.message}')),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _EntryPoint()),
      (route) => false,
    );
  }

  Future<bool> _confirmLogout() async {
    final identity = _identity;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFBA1A1A), size: 24),
            SizedBox(width: 10),
            Expanded(child: Text('Akhiri Sesi Pos?')),
          ],
        ),
        content: Text(
          'Anda akan keluar dari sesi ${identity?.name ?? ''} '
          'di ${identity?.areaName ?? ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _push(Widget page) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page))
        .then((_) {
      if (mounted) {
        resetSessionScopedState(ref);
      }
    });
  }

  CheckOutPage _checkOutPage({ActiveVehicle? vehicle}) {
    final identity = _identity;
    return CheckOutPage(
      officerName: identity?.name ?? '',
      officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
      isSupervisor: identity?.isSupervisor ?? false,
      parkingLot: vehicle?.areaName.isNotEmpty == true
          ? vehicle!.areaName
          : (identity?.areaLabel ?? ''),
      nim: vehicle?.nim ?? '',
      checkInPlate: vehicle?.plateIn ?? '',
      checkInTime:
          vehicle == null ? '' : Formatters.time(vehicle.checkedInAt),
      onFinished: () {
        if (mounted) resetSessionScopedState(ref);
      },
    );
  }

  void _openCheckOutFor(ActiveVehicle vehicle) =>
      _push(_checkOutPage(vehicle: vehicle));

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(officerIdentityProvider);

    final Widget page = switch (_index) {
      1 => VehiclesPage(
          fallbackArea: identity?.areaLabel ?? '',
          onCheckOut: _openCheckOutFor,
          onScanCheckOut: () => _push(_checkOutPage()),
        ),
      2 => HistoryPageView(areaLabel: identity?.areaLabel ?? ''),
      _ => _homePage(identity),
    };

    return Column(
      children: [
        Expanded(child: page),
        AppBottomNav(
          currentIndex: _index,
          destinations: AppBottomNav.officerDestinations,
          onTap: (index) => setState(() => _index = index),
        ),
      ],
    );
  }

  Widget _homePage(OfficerIdentity? identity) {
    return OfficerHomePage(
      onOpenCheckIn: () => _push(
        CheckInPage(
          officerName: identity?.name ?? '',
          officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
          isSupervisor: identity?.isSupervisor ?? false,
          parkingLot: identity?.areaLabel ?? '',
          onFinished: () {
            if (mounted) resetSessionScopedState(ref);
          },
        ),
      ),
      onOpenCheckOut: () => _push(_checkOutPage()),
      onOpenVehicles: () => setState(() => _index = 1),
      onOpenHistory: () => setState(() => _index = 2),
      onLogout: _logout,
    );
  }
}
