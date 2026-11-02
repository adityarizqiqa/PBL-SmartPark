import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/dashboard/presentation/pages/officer_home_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  ProviderContainer makeContainer(http.Client client) {
    final store = SessionStore();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(
          ApiClient(
            client: client,
            baseUrl: 'http://test.local',
            tokens: store,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpHome(
    WidgetTester tester,
    ProviderContainer container, {
    VoidCallback? onCheckIn,
    VoidCallback? onCheckOut,
    VoidCallback? onVehicles,
    VoidCallback? onHistory,
    VoidCallback? onLogout,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: OfficerHomePage(
            onOpenCheckIn: onCheckIn ?? () {},
            onOpenCheckOut: onCheckOut ?? () {},
            onOpenVehicles: onVehicles ?? () {},
            onOpenHistory: onHistory ?? () {},
            onLogout: onLogout ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan statistik dari /api/sessions/dashboard',
      (tester) async {
    final container = makeContainer(
      MockClient((request) async {
        if (request.url.path == '/api/sessions/dashboard') {
          expect(request.headers['x-shift-token'], 'dummy-token');
          return jsonResponse({
            'active_now': 428,
            'checked_in_today': 852,
            'checked_out_today': 424,
            'recent': [
              sessionDetailJson(
                id: 10,
                plateIn: 'N1234ABC',
                status: 'matched',
                plateOut: 'N1234ABC',
              ),
            ],
          });
        }
        return notFound();
      }),
    );
    container.read(sessionStoreProvider)
      ..shiftToken = 'dummy-token'
      ..officerName = 'Budi Santoso'
      ..areaName = 'POS-UTAMA • Pos Parkir Utama'
      ..role = 'officer';

    await pumpHome(tester, container);

    expect(find.text('Beranda Petugas'), findsOneWidget);
    expect(find.text('428'), findsOneWidget);
    expect(find.text('852'), findsOneWidget);
    expect(find.text('424'), findsOneWidget);
    expect(find.text('428 / 500 Slot'), findsOneWidget);
    expect(find.text('N1234ABC'), findsOneWidget);
    expect(find.text('NIM 244107020204'), findsOneWidget);
  });

  testWidgets('galat dashboard tampil sebagai banner dengan tombol coba lagi',
      (tester) async {
    var calls = 0;
    final container = makeContainer(
      MockClient((request) async {
        if (request.url.path == '/api/sessions/dashboard') {
          calls++;
          if (calls == 1) {
            return jsonResponse(
              {
                'code': 'not_found',
                'message': 'Sesi tidak ditemukan.',
                'details': <String, dynamic>{},
              },
              status: 404,
            );
          }
          return jsonResponse({
            'active_now': 1,
            'checked_in_today': 2,
            'checked_out_today': 3,
            'recent': <Map<String, dynamic>>[],
          });
        }
        return notFound();
      }),
    );
    container.read(sessionStoreProvider)
      ..shiftToken = 't'
      ..officerName = 'Budi Santoso'
      ..role = 'officer';

    await pumpHome(tester, container);
    expect(find.text('Sesi tidak ditemukan.'), findsOneWidget);

    await tester.tap(find.byTooltip('Coba lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Sesi tidak ditemukan.'), findsNothing);
    expect(find.text('1 / 500 Slot'), findsOneWidget);
  });

  testWidgets('aksi cepat meneruskan ke callback navigasi', (tester) async {
    final container = makeContainer(
      MockClient((request) async => switch (request.url.path) {
            '/api/sessions/dashboard' => jsonResponse({
                'active_now': 0,
                'checked_in_today': 0,
                'checked_out_today': 0,
                'recent': <Map<String, dynamic>>[],
              }),
            _ => notFound(),
          }),
    );
    container.read(sessionStoreProvider)
      ..shiftToken = 't'
      ..officerName = 'Budi Santoso'
      ..role = 'officer';

    var checkIn = 0;
    var checkOut = 0;
    await pumpHome(
      tester,
      container,
      onCheckIn: () => checkIn++,
      onCheckOut: () => checkOut++,
    );

    await tester.tap(find.text('CHECK-IN'));
    await tester.tap(find.text('CHECK-OUT'));
    await tester.pumpAndSettle();

    expect(checkIn, 1);
    expect(checkOut, 1);
  });

  testWidgets('tanpa sesi, halaman menolak menampilkan data',
      (tester) async {
    final container = makeContainer(
      MockClient((request) async => notFound()),
    );

    await pumpHome(tester, container);

    expect(find.text('Sesi tidak ditemukan'), findsOneWidget);
    expect(find.text('Beranda Petugas'), findsNothing);
  });
}
