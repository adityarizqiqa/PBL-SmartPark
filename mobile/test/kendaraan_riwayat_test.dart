import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/screens/kendaraan_screen.dart';
import 'package:mobile/screens/riwayat_screen.dart';

void main() {
  group('KendaraanScreen Integration Tests', () {
    testWidgets('Menampilkan daftar kendaraan aktif dari GET /api/sessions/active',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/sessions/active');
        return http.Response(
          jsonEncode([
            {
              'id': 101,
              'nim': '244107020204',
              'plate_in': 'N 1234 ABC',
              'checked_in_at': '2026-10-12T07:30:00',
              'duration_minutes': 204,
              'area_id': 1,
              'area_name': 'Pos Parkir Utama',
              'checked_in_by': 'Budi Santoso',
            },
            {
              'id': 102,
              'nim': '223105010042',
              'plate_in': 'B 3821 SDE',
              'checked_in_at': '2026-10-12T08:15:00',
              'duration_minutes': 161,
              'area_id': 1,
              'area_name': 'Pos Parkir Utama',
              'checked_in_by': 'Budi Santoso',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: KendaraanScreen(apiClient: apiClient),
        ),
      );

      // Tunggu hingga request selesai
      await tester.pumpAndSettle();

      // Cek elemen
      expect(find.text('Kendaraan Sedang\nParkir'), findsOneWidget);
      expect(find.text('Semua (2)'), findsOneWidget);
      expect(find.text('N 1234 ABC'), findsOneWidget);
      expect(find.text('244107020204'), findsOneWidget);
      expect(find.text('3j 24m'), findsOneWidget); // 204 minutes
      expect(find.text('B 3821 SDE'), findsOneWidget);
      expect(find.text('223105010042'), findsOneWidget);
      expect(find.text('2j 41m'), findsOneWidget); // 161 minutes
    });

    testWidgets('Menampilkan empty state saat tidak ada kendaraan parkir',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: KendaraanScreen(apiClient: apiClient),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tidak ada kendaraan yang sedang parkir'), findsOneWidget);
      expect(find.text('Semua (0)'), findsOneWidget);
    });

    testWidgets('Menampilkan pesan galat saat backend gagal',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'auth_required',
            'message': 'Header X-Shift-Token wajib dikirim.',
            'details': {},
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: KendaraanScreen(apiClient: apiClient),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Header X-Shift-Token wajib dikirim.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });
  });

  group('RiwayatScreen Integration Tests', () {
    testWidgets('Menampilkan daftar riwayat dan metadata paginasi dari backend',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/history/meta') {
          return http.Response(
            jsonEncode({
              'total': 45,
              'limit': 20,
              'offset': 0,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/sessions/history') {
          return http.Response(
            jsonEncode([
              {
                'id': 89,
                'nim': '244107020204',
                'plate_in': 'N 1234 ABC',
                'plate_out': 'N 1234 ABC',
                'checked_in_at': '2026-10-12T07:32:00',
                'checked_out_at': '2026-10-12T10:56:00',
                'status': 'matched',
                'verification_note': null,
              },
              {
                'id': 77,
                'nim': '214172019901',
                'plate_in': 'B 3821 SDE',
                'plate_out': 'B 3821 SDE',
                'checked_in_at': '2026-10-12T08:15:00',
                'checked_out_at': '2026-10-12T11:20:00',
                'status': 'manual_verified',
                'verification_note': 'KTM fisik diperiksa petugas pos',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: RiwayatScreen(apiClient: apiClient),
        ),
      );

      await tester.pumpAndSettle();

      // Cek session #89 (matched / Sesuai)
      expect(find.text('#89'), findsOneWidget);
      expect(find.text('N 1234 ABC'), findsOneWidget);
      expect(find.text('244107020204'), findsOneWidget);
      expect(find.text('Sesuai'), findsWidgets);

      // Cek session #77 (manual_verified / Verifikasi Manual)
      expect(find.text('#77'), findsOneWidget);
      expect(find.text('B 3821 SDE'), findsOneWidget);
      expect(find.text('214172019901'), findsOneWidget);
      expect(find.text('Verifikasi Manual'), findsWidgets);
      expect(find.text('Catatan: KTM fisik diperiksa petugas pos'), findsOneWidget);

      // Cek toolbar paginasi
      expect(find.text('1-20 dari 45'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('Pencarian riwayat mengirimkan parameter q ke backend',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? capturedQueryParam;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/history/meta') {
          return http.Response(
            jsonEncode({'total': 1, 'limit': 20, 'offset': 0}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/api/sessions/history') {
          capturedQueryParam = request.url.queryParameters['q'];
          return http.Response(
            jsonEncode([
              {
                'id': 89,
                'nim': '244107020204',
                'plate_in': 'N 1234 ABC',
                'plate_out': 'N 1234 ABC',
                'checked_in_at': '2026-10-12T07:32:00',
                'checked_out_at': '2026-10-12T10:56:00',
                'status': 'matched',
                'verification_note': null,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test.local');

      await tester.pumpWidget(
        MaterialApp(
          home: RiwayatScreen(apiClient: apiClient),
        ),
      );

      await tester.pumpAndSettle();
      expect(capturedQueryParam, isNull);

      // Masukkan query pencarian
      await tester.enterText(find.byType(TextField), 'N 1234');
      // Tunggu debounce 400ms
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(capturedQueryParam, 'N 1234');
    });
  });
}
