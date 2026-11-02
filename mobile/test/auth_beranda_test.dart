import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/session_store.dart';
import 'package:mobile/screens/beranda_screen.dart';

void main() {
  setUp(() {
    SessionStore.instance.clear();
  });

  tearDown(() {
    SessionStore.instance.clear();
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

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: BerandaScreen(apiClient: client)),
      ),
    );
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

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: BerandaScreen(apiClient: client)),
      ),
    );
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
