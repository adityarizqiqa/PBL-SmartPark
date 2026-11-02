import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/supervisor/areas/presentation/pages/areas_page.dart';
import 'package:mobile/features/supervisor/home/presentation/pages/supervisor_home_page.dart';
import 'package:mobile/features/supervisor/officers/presentation/pages/officers_page.dart';
import 'package:mobile/features/supervisor/shifts/presentation/pages/shifts_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  ProviderContainer container(http.Client client) {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(client: client, baseUrl: 'http://test.local'),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> pumpPage(
    WidgetTester tester,
    ProviderContainer c,
    Widget page,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(home: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> shiftJson({
    int id = 1,
    int areaId = 1,
    bool isOpen = true,
    String areaName = 'Pos Parkir Utama',
  }) {
    return {
      'id': id,
      'parking_area_id': areaId,
      'area_name': areaName,
      'started_at': '2026-10-12T07:00:00',
      'ended_at': isOpen ? null : '2026-10-12T15:00:00',
      'end_note': isOpen ? null : 'Selesai',
      'is_open': isOpen,
      'assignments': <Map<String, dynamic>>[],
    };
  }

  group('SupervisorHomePage', () {
    testWidgets('menampilkan jumlah lahan dan shift dari backend',
        (tester) async {
      final c = container(
        MockClient((request) async => switch (request.url.path) {
              '/api/areas' => jsonResponse([
                  areaJson(),
                  areaJson(id: 2, code: 'POS-BARAT', name: 'Pos Barat'),
                  areaJson(id: 3, code: 'POS-TIMUR', isActive: false),
                ]),
              '/api/shifts' => jsonResponse([shiftJson()]),
              _ => notFound(),
            }),
      );

      await pumpPage(
        tester,
        c,
        SupervisorHomePage(
          onOpenAreas: () {},
          onOpenShifts: () {},
          onOpenOfficers: () {},
          onLogout: () {},
        ),
      );

      expect(find.text('KONSOL PENGAWAS'), findsWidgets);
      expect(find.text('Kelola Lahan'), findsOneWidget);
      expect(find.text('Kelola Shift'), findsOneWidget);
      expect(find.text('Kelola Petugas'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('kartu konsol meneruskan ke callback navigasi', (tester) async {
      var areas = 0;
      var shifts = 0;
      var officers = 0;
      final c = container(
        MockClient((request) async => switch (request.url.path) {
              '/api/areas' => jsonResponse([areaJson()]),
              '/api/shifts' => jsonResponse(<Map<String, dynamic>>[]),
              _ => notFound(),
            }),
      );

      await pumpPage(
        tester,
        c,
        SupervisorHomePage(
          onOpenAreas: () => areas++,
          onOpenShifts: () => shifts++,
          onOpenOfficers: () => officers++,
          onLogout: () {},
        ),
      );

      await tester.tap(find.text('Kelola Lahan'));
      await tester.tap(find.text('Kelola Shift'));
      await tester.tap(find.text('Kelola Petugas'));
      await tester.pumpAndSettle();

      expect(areas, 1);
      expect(shifts, 1);
      expect(officers, 1);
    });
  });

  group('AreasPage', () {
    testWidgets('menambah lahan mengirim POST /api/areas', (tester) async {
      Map<String, dynamic>? body;
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/areas' && request.method == 'GET') {
            return jsonResponse([areaJson()]);
          }
          if (request.url.path == '/api/areas' && request.method == 'POST') {
            body = decodeBody(request);
            return jsonResponse(
              areaJson(id: 9, code: 'POS-NEW', name: 'Pos Baru'),
              status: 201,
            );
          }
          if (request.url.path == '/api/shifts') {
            return jsonResponse(<Map<String, dynamic>>[]);
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const AreasPage());

      await tester.enterText(find.byType(TextField).at(0), 'POS-NEW');
      await tester.enterText(find.byType(TextField).at(1), 'Pos Baru');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Lahan'));
      await tester.pumpAndSettle();

      expect(body, {'code': 'POS-NEW', 'name': 'Pos Baru'});
      expect(find.textContaining('berhasil ditambahkan'), findsOneWidget);
    });

    testWidgets('lahan dengan shift terbuka tidak bisa dinonaktifkan',
        (tester) async {
      var patchCalls = 0;
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/areas') {
            return jsonResponse([areaJson()]);
          }
          if (request.url.path == '/api/shifts') {
            return jsonResponse([shiftJson()]);
          }
          if (request.method == 'PATCH') {
            patchCalls++;
            return jsonResponse(areaJson());
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const AreasPage());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Nonaktifkan').first);
      await tester.pumpAndSettle();

      expect(patchCalls, 0);
      expect(find.textContaining('Tutup 1 shift terbuka'), findsOneWidget);
    });
  });

  group('ShiftsPage', () {
    testWidgets('membuka shift mengirim parking_area_id', (tester) async {
      Map<String, dynamic>? body;
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/areas') {
            return jsonResponse([areaJson()]);
          }
          if (request.url.path == '/api/shifts' && request.method == 'GET') {
            return jsonResponse(<Map<String, dynamic>>[]);
          }
          if (request.url.path == '/api/shifts/open') {
            body = decodeBody(request);
            return jsonResponse(shiftJson());
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const ShiftsPage());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Buka Shift'));
      await tester.pumpAndSettle();

      expect(body, {'parking_area_id': 1});
      expect(find.textContaining('mulai dijaga'), findsOneWidget);
    });

    testWidgets('satu lahan hanya boleh punya satu shift terbuka',
        (tester) async {
      var openCalls = 0;
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/areas') {
            return jsonResponse([areaJson()]);
          }
          if (request.url.path == '/api/shifts' && request.method == 'GET') {
            return jsonResponse([shiftJson()]);
          }
          if (request.url.path == '/api/shifts/open') {
            openCalls++;
            return jsonResponse(shiftJson());
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const ShiftsPage());

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Buka Shift'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Buka Shift'));
      await tester.pumpAndSettle();

      expect(openCalls, 0);
      expect(
        find.textContaining('Satu lahan hanya boleh punya satu shift terbuka'),
        findsWidgets,
      );
    });
  });

  group('OfficersPage', () {
    testWidgets('menambah petugas mengirim data akun', (tester) async {
      Map<String, dynamic>? body;
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/officers' && request.method == 'GET') {
            return jsonResponse([officerJson()]);
          }
          if (request.url.path == '/api/officers' && request.method == 'POST') {
            body = decodeBody(request);
            return jsonResponse(officerJson(id: 7, name: 'Sari'), status: 201);
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const OfficersPage());

      await tester.enterText(find.byType(TextField).at(1), 'Sari');
      await tester.enterText(find.byType(TextField).at(3), 'rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Petugas'));
      await tester.pumpAndSettle();

      expect(body?['name'], 'Sari');
      expect(body?['role'], 'officer');
      expect(body?['password'], 'rahasia123');
    });

    testWidgets('galat backend tampil sebagai snack bar', (tester) async {
      final c = container(
        MockClient((request) async {
          if (request.url.path == '/api/officers' && request.method == 'GET') {
            return jsonResponse([officerJson()]);
          }
          if (request.url.path == '/api/officers' && request.method == 'POST') {
            return jsonResponse(
              {
                'code': 'conflict',
                'message': 'Nomor pegawai sudah dipakai.',
                'details': <String, dynamic>{},
              },
              status: 409,
            );
          }
          return notFound();
        }),
      );

      await pumpPage(tester, c, const OfficersPage());

      await tester.enterText(find.byType(TextField).at(1), 'Sari');
      await tester.enterText(find.byType(TextField).at(3), 'rahasia123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tambah Petugas'));
      await tester.pumpAndSettle();

      expect(find.text('Nomor pegawai sudah dipakai.'), findsOneWidget);
    });
  });
}
