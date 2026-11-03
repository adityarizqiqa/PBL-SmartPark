import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/main.dart';
import 'package:mobile/features/dashboard/presentation/pages/officer_home_page.dart';
import 'package:mobile/features/vehicles/presentation/pages/vehicles_page.dart';
import 'package:mobile/features/history/presentation/pages/history_page_view.dart';

http.Client _createTestHttpClient() {
  return MockClient((request) async {
    if (request.url.path == '/api/officers') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'employee_no': 'PK001',
            'name': 'Budi Santoso',
            'phone': '0812',
            'role': 'officer',
            'is_active': true,
            'has_password': true,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/api/areas') {
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'code': 'POS-UTAMA',
            'name': 'Pos Parkir Utama',
            'is_active': true,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/api/shifts/join') {
      return http.Response(
        jsonEncode({
          'token': 'shift-tok-test',
          'assignment': {
            'id': 1,
            'shift_id': 1,
            'officer_id': 1,
            'officer_name': 'Budi Santoso',
            'joined_at': '2026-10-12T07:00:00',
            'left_at': null,
            'left_note': null,
          },
          'shift': {
            'id': 1,
            'parking_area_id': 1,
            'area_name': 'Pos Parkir Utama',
            'started_at': '2026-10-12T07:00:00',
            'ended_at': null,
            'end_note': null,
            'is_open': true,
            'assignments': [],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/api/sessions/history') {
      return http.Response(
        jsonEncode([
          {
            'id': 31,
            'nim': '244107020204',
            'plate_in': 'N 1234 ABC',
            'plate_out': 'N 1234 ABC',
            'checked_in_at': '2026-10-12T07:30:00',
            'checked_out_at': '2026-10-12T10:54:00',
            'status': 'matched',
            'verification_note': null,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/api/sessions/history/meta') {
      return http.Response(
        jsonEncode({'total': 45, 'limit': 20, 'offset': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    } else if (request.url.path == '/api/sessions/dashboard') {
      return http.Response(
        jsonEncode({
          'active_now': 428,
          'checked_in_today': 852,
          'checked_out_today': 424,
          'recent': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    final path = request.url.path;
    if (path == '/api/sessions/check-in') {
      return http.Response(
        jsonEncode({
          'id': 89,
          'nim': '244107020204',
          'plate_in': 'N 1234 ABC',
          'plate_out': null,
          'checked_in_at': '2026-10-12T07:32:00.000Z',
          'checked_out_at': null,
          'status': 'active',
          'match_method': 'plate_exact',
          'verification_note': null,
          'plate_in_photo_path': null,
          'plate_out_photo_path': null,
          'area_id': 1,
          'area_name': 'POS-UTAMA • Pos Parkir Utama',
          'checked_in_by': {
            'assignment_id': 1,
            'officer_id': 1,
            'officer_name': 'Budi Santoso',
          },
          'checked_out_by': null,
          'events': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path.startsWith('/api/sessions/') && path.endsWith('/check-out')) {
      return http.Response(
        jsonEncode({
          'id': 89,
          'nim': '244107020204',
          'plate_in': 'N 1234 ABC',
          'plate_out': 'N 1234 ABC',
          'checked_in_at': '2026-10-12T07:32:00.000Z',
          'checked_out_at': '2026-10-12T11:00:00.000Z',
          'status': 'matched',
          'match_method': 'plate_exact',
          'verification_note': null,
          'plate_in_photo_path': null,
          'plate_out_photo_path': null,
          'area_id': 1,
          'area_name': 'POS-UTAMA • Pos Parkir Utama',
          'checked_in_by': {
            'assignment_id': 1,
            'officer_id': 1,
            'officer_name': 'Budi Santoso',
          },
          'checked_out_by': {
            'assignment_id': 1,
            'officer_id': 1,
            'officer_name': 'Budi Santoso',
          },
          'events': [],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/sessions/lookup') {
      return http.Response(
        jsonEncode({
          'match_method': 'plate_exact',
          'session': {
            'id': 89,
            'nim': '244107020204',
            'plate_in': 'N 1234 ABC',
            'plate_out': null,
            'checked_in_at': '2026-10-12T07:32:00.000Z',
            'checked_out_at': null,
            'status': 'active',
            'match_method': 'plate_exact',
            'verification_note': null,
            'plate_in_photo_path': null,
            'plate_out_photo_path': null,
            'area_id': 1,
            'area_name': 'POS-UTAMA • Pos Parkir Utama',
            'checked_in_by': {
              'assignment_id': 1,
              'officer_id': 1,
              'officer_name': 'Budi Santoso',
            },
            'checked_out_by': null,
            'events': [],
          },
          'candidates': [],
          'message': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/shifts/leave') {
      return http.Response(
        jsonEncode({'id': 7}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('Not Found', 404);
  });
}

http.Client _createSpvTestHttpClient() {
  Map<String, dynamic> area() => {
        'id': 1,
        'code': 'POS-UTAMA',
        'name': 'Pos Parkir Utama',
        'is_active': true,
      };
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/officers') {
      return http.Response(
        jsonEncode([
          {
            'id': 4,
            'employee_no': 'SPV001',
            'name': 'Dewi Kartika',
            'phone': '0813',
            'role': 'spv',
            'is_active': true,
            'has_password': true,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/areas') {
      return http.Response(
        jsonEncode([area()]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/auth/sign-in') {
      return http.Response(
        jsonEncode({
          'token': 'spv-tok-test',
          'session': {
            'id': 7,
            'officer_id': 4,
            'officer_name': 'Dewi Kartika',
            'role': 'spv',
            'signed_in_at': '2026-10-12T07:00:00',
            'revoked_at': null,
            'is_active': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/shifts') {
      return http.Response(
        jsonEncode([]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (path == '/api/auth/sign-out') {
      return http.Response(
        jsonEncode({'ok': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('Not Found', 404);
  });
}

void main() {
  testWidgets(
    'Full flow test: Login -> Beranda -> Kendaraan -> Riwayat Screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        SmartParkApp(httpClient: _createTestHttpClient()),
      );
      await tester.pumpAndSettle();

      // Verify key Login UI elements exist
      expect(find.text('SmartPark'), findsOneWidget);
      expect(find.text('KAMPUS'), findsOneWidget);
      expect(find.text('Aktivasi Sesi Pos Lahan'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Mulai Bertugas'), findsOneWidget);

      // Enter password
      await tester.enterText(find.byType(TextFormField), 'password123');

      // Ensure button is visible & tap 'Mulai Bertugas'
      await tester.ensureVisible(find.text('Mulai Bertugas'));
      await tester.tap(find.text('Mulai Bertugas'));
      await tester.pumpAndSettle();

      // Verify that BerandaScreen is displayed
      expect(find.byType(OfficerHomePage), findsOneWidget);
      expect(find.text('Beranda Petugas'), findsOneWidget);
      expect(find.text('CHECK-IN'), findsOneWidget);
      expect(find.text('CHECK-OUT'), findsOneWidget);
      expect(find.text('Sedang Parkir'), findsOneWidget);
      expect(find.text('AKSI CEPAT GERBANG'), findsOneWidget);
      expect(find.text('STATISTIK OPERASIONAL'), findsOneWidget);
      expect(find.text('AKTIVITAS TERAKHIR DI POS'), findsOneWidget);

      // Dismiss any active floating SnackBar from login
      ScaffoldMessenger.of(
        tester.element(find.byType(OfficerHomePage)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Tap on 'Kendaraan' in BottomNavigationBar
      await tester.tap(find.byIcon(Icons.directions_car_outlined));
      await tester.pumpAndSettle();

      // Verify that KendaraanScreen is displayed
      expect(find.byType(VehiclesPage), findsOneWidget);
      expect(find.text('Kendaraan Sedang\nParkir'), findsOneWidget);
      expect(find.text('Cari NIM atau Plat Nomor...'), findsOneWidget);
      expect(find.text('Scan Check-Out'), findsOneWidget);

      // Tap on 'Riwayat' in BottomNavigationBar from KendaraanScreen
      await tester.tap(find.byIcon(Icons.history_rounded));
      await tester.pumpAndSettle();

      // Verify that RiwayatScreen is displayed
      expect(find.byType(HistoryPageView), findsOneWidget);
      expect(find.text('Riwayat Sesi Parkir'), findsOneWidget);
      expect(find.text('RIWAYAT SESI'), findsOneWidget);
      // Ringkasan memakai data nyata dari /history/meta dan baris yang dimuat.
      expect(find.text('45'), findsOneWidget);
      expect(find.text('1-20 dari 45'), findsOneWidget);
    },
  );

  testWidgets('Check-In Flow test: Step 1 -> Step 2 -> Step 3 -> Finish', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(SmartParkApp(httpClient: _createTestHttpClient()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'password123');
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    // Tap CHECK-IN from Beranda
    await tester.ensureVisible(find.text('CHECK-IN'));
    await tester.tap(find.text('CHECK-IN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Step 1: Scan KTM (mulai kosong, tanpa dummy NIM).
    expect(find.text('LANGKAH 1 DARI 3'), findsOneWidget);
    expect(find.text('Scan KTM'), findsOneWidget);
    expect(find.text('244107020204'), findsNothing);

    // Isi NIM manual + verifikasi fisik KTM.
    await tester.ensureVisible(find.text('Ketik NIM Manual'));
    await tester.tap(find.text('Ketik NIM Manual'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, '244107020204');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 200));

    // Tap LANJUT SCAN PLAT KENDARAAN -> Step 2
    await tester.ensureVisible(find.text('LANJUT SCAN PLAT KENDARAAN'));
    await tester.tap(find.text('LANJUT SCAN PLAT KENDARAAN'));
    await tester.pump(const Duration(milliseconds: 400));

    // Step 2: Scan Plat
    expect(find.text('Langkah 2 dari 3'), findsOneWidget);
    expect(find.text('Scan Plat Kendaraan'), findsWidgets);

    // Koreksi plat manual lalu gunakan plat.
    await tester.ensureVisible(find.text('Koreksi Manual'));
    await tester.tap(find.text('Koreksi Manual'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, 'N1234ABC');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump(const Duration(milliseconds: 400));

    // Tap Gunakan Plat Ini -> Step 3
    await tester.ensureVisible(find.text('Gunakan Plat Ini'));
    await tester.tap(find.text('Gunakan Plat Ini'));
    await tester.pump(const Duration(milliseconds: 400));

    // Step 3: Konfirmasi
    expect(find.text('Konfirmasi Check-In'), findsWidgets);
    expect(find.text('Data Sesi Check-In'), findsOneWidget);
    expect(find.text('Siap Check-In'), findsOneWidget);

    // Tap Konfirmasi Check-In
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'),
    );
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Success dialog
    expect(find.text('Check-In Berhasil!'), findsOneWidget);
    await tester.tap(find.text('Ke Beranda'));
    await tester.pumpAndSettle();

    expect(find.byType(OfficerHomePage), findsOneWidget);
  });

  testWidgets('Check-Out Flow test: Verification -> Confirm Check-Out', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(SmartParkApp(httpClient: _createTestHttpClient()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'password123');
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    // Tap CHECK-OUT from Beranda
    await tester.ensureVisible(find.text('CHECK-OUT'));
    await tester.tap(find.text('CHECK-OUT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // CheckOut mulai kosong lalu lookup via tombol Cari.
    expect(find.text('Verifikasi Check-Out'), findsWidgets);
    expect(find.text('Belum ada sesi'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'N 1234 ABC');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Cari'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cari'));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('SESUAI'), findsOneWidget);
    expect(find.text('PERBANDINGAN PLAT'), findsOneWidget);

    // Toggle checkbox
    await tester.ensureVisible(find.text('KTM telah diperiksa secara visual'));
    await tester.tap(find.text('KTM telah diperiksa secara visual'));
    await tester.pump(const Duration(milliseconds: 200));

    // Confirm check-out
    await tester.ensureVisible(find.text('Konfirmasi Check-Out'));
    await tester.tap(find.text('Konfirmasi Check-Out'));
    await tester.pump(const Duration(milliseconds: 800));

    // Success dialog
    expect(find.text('Check-Out Berhasil!'), findsOneWidget);
    await tester.tap(find.text('Selesai & Ke Beranda'));
    await tester.pumpAndSettle();

    expect(find.byType(OfficerHomePage), findsOneWidget);
  });

  testWidgets('Logout lalu login lagi tetap membuka beranda petugas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(SmartParkApp(httpClient: _createTestHttpClient()));
    await tester.pumpAndSettle();

    Future<void> login() async {
      await tester.enterText(find.byType(TextFormField), 'password123');
      await tester.ensureVisible(find.text('Mulai Bertugas'));
      await tester.tap(find.text('Mulai Bertugas'));
      await tester.pumpAndSettle();
    }

    await login();
    expect(find.byType(OfficerHomePage), findsOneWidget);
    expect(find.text('Sesi tidak ditemukan'), findsNothing);

    // Keluar lewat tombol app bar lalu konfirmasi dialog.
    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Akhiri Sesi Pos?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    // Kembali ke halaman masuk.
    expect(find.text('Mulai Bertugas'), findsOneWidget);

    // Masuk lagi: harus ke beranda, bukan layar "Sesi tidak ditemukan".
    await login();
    expect(find.byType(OfficerHomePage), findsOneWidget);
    expect(find.text('Sesi tidak ditemukan'), findsNothing);
    expect(find.text('Beranda Petugas'), findsOneWidget);
  });

  testWidgets('SPV logout lalu login lagi tetap membuka konsol pengawas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(SmartParkApp(httpClient: _createSpvTestHttpClient()));
    await tester.pumpAndSettle();

    Future<void> login() async {
      await tester.enterText(find.byType(TextFormField), 'spvpass');
      await tester.ensureVisible(find.text('Mulai Bertugas'));
      await tester.tap(find.text('Mulai Bertugas'));
      await tester.pumpAndSettle();
    }

    await login();
    expect(find.text('Beranda Pengawas'), findsOneWidget);

    // Keluar lewat tombol app bar lalu konfirmasi dialog.
    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari Konsol Pengawas?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
    await tester.pumpAndSettle();

    // Kembali ke halaman masuk, lalu masuk lagi ke konsol pengawas.
    expect(find.text('Mulai Bertugas'), findsOneWidget);
    await login();
    expect(find.text('Beranda Pengawas'), findsOneWidget);
  });
}
