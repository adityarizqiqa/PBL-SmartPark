import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/vehicles/domain/entities/active_vehicle.dart';
import 'package:mobile/features/vehicles/presentation/pages/vehicles_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  Future<void> pumpVehicles(
    WidgetTester tester,
    http.Client client, {
    void Function(ActiveVehicle)? onCheckOut,
    VoidCallback? onScan,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(client: client, baseUrl: 'http://test.local'),
          ),
        ],
        child: MaterialApp(
          home: VehiclesPage(
            fallbackArea: 'POS-UTAMA • Pos Parkir Utama',
            onCheckOut: onCheckOut ?? (_) {},
            onScanCheckOut: onScan ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> vehicleJson({
    required int id,
    required String nim,
    required String plate,
    required int minutes,
  }) {
    return {
      'id': id,
      'nim': nim,
      'plate_in': plate,
      'checked_in_at': '2026-10-12T07:30:00',
      'duration_minutes': minutes,
      'area_id': 1,
      'area_name': 'Pos Parkir Utama',
      'checked_in_by': 'Budi Santoso',
    };
  }

  testWidgets('menampilkan daftar kendaraan aktif dari /api/sessions/active',
      (tester) async {
    await pumpVehicles(
      tester,
      MockClient((request) async {
        expect(request.url.path, '/api/sessions/active');
        return jsonResponse([
          vehicleJson(
            id: 101,
            nim: '244107020204',
            plate: 'N1234ABC',
            minutes: 204,
          ),
          vehicleJson(
            id: 102,
            nim: '223105010042',
            plate: 'B3821SDE',
            minutes: 161,
          ),
        ]);
      }),
    );

    expect(find.text('Kendaraan Sedang\nParkir'), findsOneWidget);
    expect(find.text('Semua (2)'), findsOneWidget);
    expect(find.text('N1234ABC'), findsOneWidget);
    expect(find.text('244107020204'), findsOneWidget);
    expect(find.text('3j 24m'), findsOneWidget);
    expect(find.text('B3821SDE'), findsOneWidget);
    expect(find.text('2j 41m'), findsOneWidget);
  });

  testWidgets('pencarian menyaring berdasarkan NIM dan plat', (tester) async {
    await pumpVehicles(
      tester,
      MockClient((request) async => jsonResponse([
            vehicleJson(id: 1, nim: '111', plate: 'N1234ABC', minutes: 10),
            vehicleJson(id: 2, nim: '222', plate: 'B3821SDE', minutes: 20),
          ])),
    );

    await tester.enterText(find.byType(TextField), 'b3821');
    await tester.pumpAndSettle();

    expect(find.text('B3821SDE'), findsOneWidget);
    expect(find.text('N1234ABC'), findsNothing);
    expect(find.text('Total '), findsNothing);
  });

  testWidgets('empty state muncul saat tidak ada kendaraan', (tester) async {
    await pumpVehicles(
      tester,
      MockClient((request) async => jsonResponse(<Map<String, dynamic>>[])),
    );

    expect(
      find.text('Tidak ada kendaraan yang sedang parkir'),
      findsOneWidget,
    );
    expect(find.text('Semua (0)'), findsOneWidget);
  });

  testWidgets('galat backend tampil dengan tombol coba lagi', (tester) async {
    var calls = 0;
    await pumpVehicles(
      tester,
      MockClient((request) async {
        calls++;
        if (calls == 1) {
          return jsonResponse(
            {
              'code': 'unauthorized',
              'message': 'Header X-Shift-Token wajib dikirim.',
              'details': <String, dynamic>{},
            },
            status: 401,
          );
        }
        return jsonResponse([
          vehicleJson(id: 1, nim: '111', plate: 'N1234ABC', minutes: 10),
        ]);
      }),
    );

    expect(find.text('Header X-Shift-Token wajib dikirim.'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('N1234ABC'), findsOneWidget);
  });

  testWidgets('tombol check-out meneruskan kendaraan yang dipilih',
      (tester) async {
    ActiveVehicle? selected;
    await pumpVehicles(
      tester,
      MockClient((request) async => jsonResponse([
            vehicleJson(id: 7, nim: '999', plate: 'D1234EF', minutes: 30),
          ])),
      onCheckOut: (vehicle) => selected = vehicle,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Check-Out'));
    await tester.pumpAndSettle();

    expect(selected?.id, 7);
    expect(selected?.plateIn, 'D1234EF');
  });

  testWidgets('sheet detail menampilkan metadata sesi', (tester) async {
    await pumpVehicles(
      tester,
      MockClient((request) async => jsonResponse([
            vehicleJson(id: 7, nim: '999', plate: 'D1234EF', minutes: 30),
          ])),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Detail Sesi'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Sesi #7'), findsOneWidget);
    expect(find.text('NIM Mahasiswa'), findsOneWidget);
    expect(find.text('12/10/2026 07:30 WIB'), findsOneWidget);
  });
}
