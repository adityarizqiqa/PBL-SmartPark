import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'api/session_store.dart' as legacy;
import 'core/di/providers.dart';
import 'core/network/api_client.dart';
import 'core/session/officer_identity.dart';
import 'core/utils/formatters.dart';
import 'core/widgets/app_bottom_nav.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/usecases/sign_in.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_actions.dart';
import 'features/dashboard/presentation/pages/officer_home_page.dart';
import 'features/vehicles/domain/entities/active_vehicle.dart';
import 'features/vehicles/presentation/pages/vehicles_page.dart';
import 'screens/beranda_spv_screen.dart';
import 'screens/checkin_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/riwayat_screen.dart';

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
      case SupervisorSignedIn(:final session):
        legacy.SessionStore.instance.setOfficerSession(
          token: session.token,
          id: session.officer.id,
          name: session.officer.name,
          userRole: session.officer.role,
        );
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => BerandaSpvScreen(
              officerName: session.officer.name,
              officerRole: 'Pengawas (SPV)',
            ),
          ),
        );
      case OfficerJoinedShift(:final login, :final officer):
        legacy.SessionStore.instance
          ..shiftToken = login.token
          ..assignmentId = login.assignment.id
          ..shiftId = login.shift.id
          ..officerId = login.assignment.officerId
          ..officerName = login.assignment.officerName
          ..areaId = login.shift.parkingAreaId
          ..areaName = login.shift.areaName
          ..role = officer.role;
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => const OfficerShell(),
          ),
        );
    }
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
    await ref.read(leaveShiftActionProvider)('Petugas keluar');
    if (!mounted) return;
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
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  CheckOutScreen _checkOutScreen({ActiveVehicle? vehicle}) {
    final identity = _identity;
    return CheckOutScreen(
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
    );
  }

  void _openCheckOutFor(ActiveVehicle vehicle) =>
      _push(_checkOutScreen(vehicle: vehicle));

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(officerIdentityProvider);

    final Widget page = switch (_index) {
      1 => VehiclesPage(
          fallbackArea: identity?.areaLabel ?? '',
          onCheckOut: _openCheckOutFor,
          onScanCheckOut: () => _push(_checkOutScreen()),
        ),
      2 => RiwayatScreen(
          officerName: identity?.name ?? '',
          officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
          isSupervisor: identity?.isSupervisor ?? false,
          parkingLot: identity?.areaLabel ?? '',
        ),
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
        CheckInScreen(
          officerName: identity?.name ?? '',
          officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
          isSupervisor: identity?.isSupervisor ?? false,
          parkingLot: identity?.areaLabel ?? '',
        ),
      ),
      onOpenCheckOut: () => _push(_checkOutScreen()),
      onOpenVehicles: () => setState(() => _index = 1),
      onOpenHistory: () => setState(() => _index = 2),
      onLogout: _logout,
    );
  }
}
