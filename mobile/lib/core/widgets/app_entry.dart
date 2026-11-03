import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_actions.dart';
import '../../features/dashboard/presentation/pages/officer_home_page.dart';
import '../../features/history/presentation/pages/history_page_view.dart';
import '../../features/session_ops/presentation/pages/check_in_page.dart';
import '../../features/session_ops/presentation/pages/check_out_page.dart';
import '../../features/supervisor/areas/presentation/pages/areas_page.dart';
import '../../features/supervisor/home/presentation/pages/supervisor_home_page.dart';
import '../../features/supervisor/officers/presentation/pages/officers_page.dart';
import '../../features/supervisor/shifts/presentation/pages/shifts_page.dart';
import '../../features/vehicles/domain/entities/active_vehicle.dart';
import '../../features/vehicles/presentation/pages/vehicles_page.dart';
import '../session/officer_identity.dart';
import '../utils/formatters.dart';
import 'app_bottom_nav.dart';
import 'app_confirm_dialog.dart';
import 'app_snack_bar.dart';

/// Halaman pertama: masuk, lalu menuju beranda sesuai peran.
///
/// Semua alur keluar (petugas maupun pengawas) kembali ke sini agar login
/// berikutnya selalu membawa callback navigasi ke beranda.
class EntryPoint extends ConsumerWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoginPage(onSignedIn: (result) => _openHome(context, result));
  }

  void _openHome(BuildContext context, SignInResult result) {
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
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Keluar dari Konsol Pengawas?',
      message: 'Anda akan kembali ke halaman masuk.',
    );
    if (!confirmed || !mounted) return;

    await ref.read(signOutActionProvider)();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EntryPoint()),
      (route) => false,
    );
  }

  void _onTap(int index) {
    assert(index >= 0 && index <= 4, 'Indeks tab pengawas di luar 0..4: $index');
    if (index == 4) {
      _logout();
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_index) {
      0 => SupervisorHomePage(
          onOpenAreas: () => setState(() => _index = 1),
          onOpenShifts: () => setState(() => _index = 2),
          onOpenOfficers: () => setState(() => _index = 3),
          onLogout: _logout,
        ),
      1 => AreasPage(onLogout: _logout),
      2 => ShiftsPage(onLogout: _logout),
      3 => OfficersPage(onLogout: _logout),
      _ => throw StateError('Indeks tab pengawas tidak valid: $_index'),
    };

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _index == 0) return;
        setState(() => _index = 0);
      },
      child: Column(
        children: [
          Expanded(child: page),
          AppBottomNav(
            currentIndex: _index,
            destinations: AppBottomNav.supervisorDestinations,
            onTap: _onTap,
            logoutIndex: 4,
            logoutTooltip: 'Keluar dari konsol pengawas',
          ),
        ],
      ),
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
    final identity = _identity;
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Akhiri Sesi Pos?',
      message:
          'Anda akan keluar dari sesi ${identity?.name ?? ''} di ${identity?.areaName ?? ''}.',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref.read(leaveShiftActionProvider)('Petugas keluar');
    if (!mounted) return;
    if (failure != null) {
      // Shift belum tentu tertutup di server: tahan di sini agar petugas
      // tidak terkunci saat masuk lagi.
      AppSnackBar.error(context, 'Gagal mengakhiri shift: ${failure.message}');
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EntryPoint()),
      (route) => false,
    );
  }


  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  CheckOutPage _checkOutPage({ActiveVehicle? vehicle}) {
    final identity = _identity;
    return CheckOutPage(
      officerName: identity?.name ?? '',
      officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
      isSupervisor: identity?.isSupervisor ?? false,
      parkingLot: vehicle?.areaName.isNotEmpty == true
          ? vehicle!.areaName
          : (identity?.fullLabel ?? ''),
      nim: vehicle?.nim ?? '',
      checkInPlate: vehicle?.plateIn ?? '',
      checkInTime:
          vehicle == null ? '' : Formatters.time(vehicle.checkedInAt),
    );
  }

  void _openCheckOutFor(ActiveVehicle vehicle) =>
      _push(_checkOutPage(vehicle: vehicle));

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(officerIdentityProvider);

    final Widget page = switch (_index) {
      0 => _homePage(identity),
      1 => VehiclesPage(
          fallbackArea: identity?.fullLabel ?? '',
          onCheckOut: _openCheckOutFor,
          onScanCheckOut: () => _push(_checkOutPage()),
          onLogout: _logout,
        ),
      2 => HistoryPageView(
          areaLabel: identity?.fullLabel ?? '',
          onLogout: _logout,
        ),
      _ => throw StateError('Indeks tab petugas tidak valid: $_index'),
    };

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _index == 0) return;
        setState(() => _index = 0);
      },
      child: Column(
        children: [
          Expanded(child: page),
          AppBottomNav(
            currentIndex: _index,
            destinations: AppBottomNav.officerDestinations,
            onTap: (index) {
              assert(
                index >= 0 && index <= 2,
                'Indeks tab petugas di luar 0..2: $index',
              );
              setState(() => _index = index);
            },
          ),
        ],
      ),
    );
  }

  Widget _homePage(OfficerIdentity? identity) {
    return OfficerHomePage(
      onOpenCheckIn: () => _push(
        CheckInPage(
          officerName: identity?.name ?? '',
          officerRole: identity?.roleLabel ?? 'Petugas Gerbang',
          isSupervisor: identity?.isSupervisor ?? false,
          parkingLot: identity?.fullLabel ?? '',
        ),
      ),
      onOpenCheckOut: () => _push(_checkOutPage()),
      onOpenVehicles: () => setState(() => _index = 1),
      onOpenHistory: () => setState(() => _index = 2),
      onLogout: _logout,
    );
  }
}
