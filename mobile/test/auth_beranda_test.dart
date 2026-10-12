import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/session_store.dart';
import 'package:mobile/screens/beranda_screen.dart';
import 'package:mobile/screens/beranda_spv_screen.dart';
import 'package:mobile/screens/login_screen.dart';

void main() {
  setUp(() {
    SessionStore.instance.clear();
  });

  tearDown(() {
    SessionStore.instance.clear();
  });

  testWidgets('LoginScreen memuat daftar petugas dan lahan dari API',
      (WidgetTester tester) async {
    final client = ApiClient(
      client: MockClient((request) async {
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
              {
                'id': 4,
                'employee_no': 'SPV001',
                'name': 'Dewi Kartika',
                'phone': '0812',
                'role': 'spv',
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
        }
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: client)));
    // Awalnya menampilkan loading indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    // Data petugas dan lahan tampil
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Dewi Kartika'), findsOneWidget);
    expect(find.text('SPV'), findsOneWidget);
    expect(find.text('POS-UTAMA • Pos Parkir Utama'), findsOneWidget);
  });

  testWidgets('Login petugas gerbang memanggil /api/shifts/join dan menyimpan ke SessionStore',
      (WidgetTester tester) async {
    final client = ApiClient(
      client: MockClient((request) async {
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
          final body = jsonDecode(request.body);
          expect(body['officer_id'], 1);
          expect(body['password'], 'budi1234');
          expect(body['parking_area_id'], 1);

          return http.Response(
            jsonEncode({
              'token': 'shift-tok-123',
              'assignment': {
                'id': 10,
                'shift_id': 5,
                'officer_id': 1,
                'officer_name': 'Budi Santoso',
                'joined_at': '2026-10-12T07:00:00',
                'left_at': null,
                'left_note': null,
              },
              'shift': {
                'id': 5,
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
        } else if (request.url.path == '/api/sessions/dashboard') {
          return http.Response(
            jsonEncode({
              'active_now': 12,
              'checked_in_today': 45,
              'checked_out_today': 33,
              'recent': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: client)));
    await tester.pumpAndSettle();

    // Masukkan password
    await tester.enterText(find.byType(TextFormField), 'budi1234');

    // Tap Mulai Bertugas
    await tester.ensureVisible(find.text('Mulai Bertugas'));
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    // Verifikasi SessionStore
    expect(SessionStore.instance.shiftToken, 'shift-tok-123');
    expect(SessionStore.instance.officerName, 'Budi Santoso');
    expect(SessionStore.instance.hasShift, isTrue);

    // Navigasi ke BerandaScreen
    expect(find.byType(BerandaScreen), findsOneWidget);
  });

  testWidgets('Login SPV memanggil /api/auth/sign-in dan menuju BerandaSpvScreen',
      (WidgetTester tester) async {
    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/officers') {
          return http.Response(
            jsonEncode([
              {
                'id': 4,
                'employee_no': 'SPV001',
                'name': 'Dewi Kartika',
                'phone': '0812',
                'role': 'spv',
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
        } else if (request.url.path == '/api/auth/sign-in') {
          final body = jsonDecode(request.body);
          expect(body['officer_id'], 4);
          expect(body['password'], 'dewi1234');

          return http.Response(
            jsonEncode({
              'token': 'spv-tok-999',
              'session': {
                'id': 1,
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
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: client)));
    await tester.pumpAndSettle();

    // Masukkan password
    await tester.enterText(find.byType(TextFormField), 'dewi1234');

    // Tap Mulai Bertugas
    await tester.ensureVisible(find.text('Mulai Bertugas'));
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    // Verifikasi SessionStore
    expect(SessionStore.instance.officerToken, 'spv-tok-999');
    expect(SessionStore.instance.officerName, 'Dewi Kartika');
    expect(SessionStore.instance.isSupervisor, isTrue);

    // Navigasi ke BerandaSpvScreen
    expect(find.byType(BerandaSpvScreen), findsOneWidget);
  });

  testWidgets('Login gagal menampilkan pesan galat dari ApiException',
      (WidgetTester tester) async {
    final client = ApiClient(
      client: MockClient((request) async {
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
              'code': 'invalid_credentials',
              'message': 'Password salah.',
              'details': {},
            }),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: client)));
    await tester.pumpAndSettle();

    // Masukkan password salah
    await tester.enterText(find.byType(TextFormField), 'salah123');

    await tester.ensureVisible(find.text('Mulai Bertugas'));
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    // Verifikasi pesan galat muncul di SnackBar
    expect(find.text('Password salah.'), findsOneWidget);
    // Tidak berpindah halaman
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('BerandaScreen menampilkan data nyata dari /api/sessions/dashboard',
      (WidgetTester tester) async {
    SessionStore.instance.shiftToken = 'dummy-token';
    SessionStore.instance.officerName = 'Budi Santoso';
    SessionStore.instance.areaName = 'POS-UTAMA • Pos Parkir Utama';

    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/sessions/dashboard') {
          expect(request.headers['x-shift-token'], 'dummy-token');
          return http.Response(
            jsonEncode({
              'active_now': 77,
              'checked_in_today': 120,
              'checked_out_today': 43,
              'recent': [
                {
                  'id': 101,
                  'nim': '244107020001',
                  'plate_in': 'N 9999 ZZ',
                  'plate_out': null,
                  'checked_in_at': '2026-10-12T07:15:00',
                  'checked_out_at': null,
                  'status': 'active',
                  'match_method': null,
                  'verification_note': null,
                  'plate_in_photo_path': null,
                  'plate_out_photo_path': null,
                  'area_id': 1,
                  'area_name': 'Pos Parkir Utama',
                  'checked_in_by': {
                    'assignment_id': 1,
                    'officer_id': 1,
                    'officer_name': 'Budi Santoso',
                  },
                  'checked_out_by': null,
                  'events': [],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: BerandaScreen(apiClient: client)));
    await tester.pumpAndSettle();

    // Verifikasi angka operasional dari API
    expect(find.text('77'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('43'), findsOneWidget);

    // Verifikasi elemen statis tetap ada
    expect(find.text('Perlu Verifikasi'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Shift 1 (Pagi)'), findsOneWidget);

    // Verifikasi aktivitas dari API
    expect(find.text('N 9999 ZZ'), findsOneWidget);
    expect(find.text('NIM 244107020001'), findsOneWidget);
  });

  testWidgets('Logout dari BerandaScreen memanggil /api/shifts/leave dan membersihkan sesi',
      (WidgetTester tester) async {
    SessionStore.instance.shiftToken = 'dummy-token';
    SessionStore.instance.officerName = 'Budi Santoso';
    SessionStore.instance.areaName = 'POS-UTAMA • Pos Parkir Utama';

    bool leaveCalled = false;

    final client = ApiClient(
      client: MockClient((request) async {
        if (request.url.path == '/api/sessions/dashboard') {
          return http.Response(
            jsonEncode({
              'active_now': 5,
              'checked_in_today': 10,
              'checked_out_today': 5,
              'recent': [],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/shifts/leave') {
          leaveCalled = true;
          return http.Response(
            jsonEncode({
              'id': 1,
              'shift_id': 1,
              'officer_id': 1,
              'officer_name': 'Budi Santoso',
              'joined_at': '2026-10-12T07:00:00',
              'left_at': '2026-10-12T08:00:00',
              'left_note': 'Petugas keluar',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path == '/api/officers' || request.url.path == '/api/areas') {
          return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      }),
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(MaterialApp(home: BerandaScreen(apiClient: client)));
    await tester.pumpAndSettle();

    // Tap icon logout
    await tester.tap(find.byIcon(Icons.logout_rounded));
    await tester.pumpAndSettle();

    // Dialog konfirmasi muncul
    expect(find.text('Akhiri Sesi Pos?'), findsOneWidget);

    // Tap konfirmasi 'Keluar'
    await tester.tap(find.widgetWithText(ElevatedButton, 'Keluar'));
    await tester.pumpAndSettle();

    expect(leaveCalled, isTrue);
    expect(SessionStore.instance.hasShift, isFalse);
    expect(SessionStore.instance.shiftToken, isNull);
  });
}
