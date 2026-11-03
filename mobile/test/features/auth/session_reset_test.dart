import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/failures/failure.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/session/officer_identity.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/auth/presentation/providers/auth_actions.dart';
import 'package:mobile/features/auth/presentation/providers/login_controller.dart';
import 'package:mobile/features/dashboard/domain/entities/dashboard.dart';
import 'package:mobile/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:mobile/features/dashboard/presentation/providers/dashboard_controller.dart';
import 'package:mobile/features/history/domain/entities/history_item.dart';
import 'package:mobile/features/history/domain/entities/history_page.dart';
import 'package:mobile/features/history/domain/entities/page_meta.dart';
import 'package:mobile/features/history/domain/repositories/history_repository.dart';
import 'package:mobile/features/history/presentation/providers/history_controller.dart';
import 'package:mobile/features/vehicles/domain/entities/active_vehicle.dart';
import 'package:mobile/features/vehicles/domain/repositories/vehicle_repository.dart';
import 'package:mobile/features/vehicles/presentation/providers/vehicles_controller.dart';

import '../../helpers/fixtures.dart';

/// Mengambil [Ref] aktif untuk memanggil aksi yang butuh `Ref`.
final _refProbeProvider = Provider<Ref>((ref) => ref);

class _FakeDashboardRepository implements DashboardRepository {
  Dashboard canned = const Dashboard(
    activeNow: 5,
    checkedInToday: 50,
    checkedOutToday: 45,
    recent: [],
  );

  @override
  Future<Dashboard> fetch() async => canned;
}

ActiveVehicle _vehicle(int id, String plate) => ActiveVehicle(
      id: id,
      nim: '2441070202$id',
      plateIn: plate,
      checkedInAt: DateTime.utc(2026, 10, 1, 8),
      durationMinutes: 60,
      areaId: 1,
      areaName: 'POS-UTAMA • Pos Parkir Utama',
      checkedInBy: 'Budi',
    );

class _FakeVehicleRepository implements VehicleRepository {
  List<ActiveVehicle> canned = [_vehicle(1, 'N 1111 AAA')];

  @override
  Future<List<ActiveVehicle>> fetchActive() async => canned;
}

HistoryItem _historyItem(int id) => HistoryItem(
      id: id,
      nim: '2441070202$id',
      plateIn: 'N $id AAA',
      plateOut: null,
      checkedInAt: DateTime.utc(2026, 10, 1, 8),
      checkedOutAt: null,
      status: 'active',
      verificationNote: null,
    );

class _FakeHistoryRepository implements HistoryRepository {
  List<HistoryItem> canned = [_historyItem(1)];

  @override
  Future<HistoryPage> fetchPage({
    required int limit,
    required int offset,
    String query = '',
  }) async =>
      HistoryPage(
        items: canned,
        meta: PageMeta(total: canned.length, limit: limit, offset: offset),
      );
}

SessionStore _seededStore() => SessionStore()
  ..shiftToken = 'shift-token'
  ..officerName = 'Budi Santoso'
  ..areaName = 'POS-UTAMA • Pos Parkir Utama'
  ..role = 'officer';

ProviderContainer _makeContainer({
  required MockClient client,
  required _FakeDashboardRepository dashboard,
  required _FakeVehicleRepository vehicles,
  required _FakeHistoryRepository history,
}) {
  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(_seededStore()),
      apiClientProvider.overrideWithValue(
        ApiClient(client: client, baseUrl: 'http://test.local'),
      ),
      dashboardRepositoryProvider.overrideWithValue(dashboard),
      vehicleRepositoryProvider.overrideWithValue(vehicles),
      historyRepositoryProvider.overrideWithValue(history),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('leave 200 menahan cache tanpa meracuninya dengan galat 401', () async {
    final dashboard = _FakeDashboardRepository();
    final vehicles = _FakeVehicleRepository();
    final history = _FakeHistoryRepository();
    final container = _makeContainer(
      client: MockClient((request) async => jsonResponse({'id': 7})),
      dashboard: dashboard,
      vehicles: vehicles,
      history: history,
    );

    // Simulasi sesi petugas pertama yang sudah memuat data.
    expect(container.read(officerIdentityProvider)?.name, 'Budi Santoso');
    container.read(dashboardControllerProvider);
    container.read(vehiclesControllerProvider);
    container.read(historyControllerProvider);
    await _settle();
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      5,
    );

    final failure = await container.read(leaveShiftActionProvider)('selesai');
    expect(failure, isNull);
    await _settle();

    // Identitas keluar, tapi cache tidak disentuh: tidak ada fetch
    // tanpa token yang bisa meracuni state untuk login berikutnya.
    expect(container.read(sessionStoreProvider).shiftToken, isNull);
    expect(container.read(officerIdentityProvider), isNull);
    expect(container.read(hasSessionProvider), isFalse);
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      5,
    );
    expect(
      container.read(vehiclesControllerProvider).all.single.plateIn,
      'N 1111 AAA',
    );
    expect(container.read(historyControllerProvider).items.single.id, 1);
  });

  test('login lagi memuat ulang data sesi baru, bukan data basi', () async {
    final dashboard = _FakeDashboardRepository();
    final vehicles = _FakeVehicleRepository();
    final history = _FakeHistoryRepository();
    final container = _makeContainer(
      client: MockClient((request) async => jsonResponse({'id': 7})),
      dashboard: dashboard,
      vehicles: vehicles,
      history: history,
    );

    container.read(dashboardControllerProvider);
    container.read(vehiclesControllerProvider);
    container.read(historyControllerProvider);
    await _settle();
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      5,
    );

    expect(
      await container.read(leaveShiftActionProvider)('selesai'),
      isNull,
    );

    // Simulasi login kedua: sesi baru tersimpan lalu state sesi di-reset
    // seperti yang dilakukan LoginController.submit.
    final store = container.read(sessionStoreProvider);
    store.shiftToken = 'shift-token-2';
    store.officerName = 'Citra Ayu';
    store.areaName = 'POS-UTAMA • Pos Parkir Utama';
    store.role = 'officer';
    dashboard.canned = const Dashboard(
      activeNow: 9,
      checkedInToday: 90,
      checkedOutToday: 81,
      recent: [],
    );
    vehicles.canned = [_vehicle(2, 'N 2222 BBB')];
    history.canned = [_historyItem(2)];
    resetSessionScopedState(container.read(_refProbeProvider));
    container.read(dashboardControllerProvider);
    container.read(vehiclesControllerProvider);
    container.read(historyControllerProvider);
    await _settle();

    expect(container.read(officerIdentityProvider)?.name, 'Citra Ayu');
    expect(container.read(hasSessionProvider), isTrue);
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      9,
    );
    expect(
      container.read(vehiclesControllerProvider).all.single.plateIn,
      'N 2222 BBB',
    );
    expect(container.read(historyControllerProvider).items.single.id, 2);
  });

  test('leave 500 menahan state sesi agar shift bisa ditutup ulang', () async {
    final dashboard = _FakeDashboardRepository();
    final vehicles = _FakeVehicleRepository();
    final history = _FakeHistoryRepository();
    final container = _makeContainer(
      client: MockClient(
        (request) async => jsonResponse(
          {'code': 'internal_error', 'message': 'Rusak'},
          status: 500,
        ),
      ),
      dashboard: dashboard,
      vehicles: vehicles,
      history: history,
    );

    container.read(dashboardControllerProvider);
    await _settle();
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      5,
    );

    final failure = await container.read(leaveShiftActionProvider)('selesai');

    expect(failure, isA<ServerFailure>());
    expect(container.read(sessionStoreProvider).shiftToken, 'shift-token');
    expect(container.read(officerIdentityProvider)?.name, 'Budi Santoso');
    await _settle();
    expect(
      container.read(dashboardControllerProvider).summary?.dashboard.activeNow,
      5,
    );
  });
}
