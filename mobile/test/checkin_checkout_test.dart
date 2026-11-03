import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart' as core;
import 'package:mobile/core/entities/parking_session.dart';
import 'package:mobile/features/session_ops/data/repositories/session_repository_impl.dart';
import 'package:mobile/features/session_ops/presentation/pages/check_in_page.dart';
import 'package:mobile/features/session_ops/presentation/pages/check_out_page.dart';
import 'package:mobile/features/session_ops/presentation/providers/session_providers.dart';

import 'helpers/fixtures.dart';

Widget _wrap(http.Client client, Widget child) {
  final api = core.ApiClient(client: client, baseUrl: 'http://test.local');
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      sessionRepositoryProvider.overrideWithValue(SessionRepositoryImpl(api)),
    ],
    child: MaterialApp(home: child),
  );
}

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(() => tester.view.resetPhysicalSize());
}

/// Alur validasi baru: NIM manual → centang verifikasi fisik → plat manual.
Future<void> _reachConfirmStep(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Ketik NIM Manual'));
  await tester.tap(find.text('Ketik NIM Manual'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byType(TextField).first, '244107020204');
  await tester.tap(find.byType(Checkbox).first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.ensureVisible(find.text('LANJUT SCAN PLAT KENDARAAN'));
  await tester.tap(find.text('LANJUT SCAN PLAT KENDARAAN'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text('Koreksi Manual'));
  await tester.tap(find.text('Koreksi Manual'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.byType(TextField).last, 'N1234ABC');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.ensureVisible(find.text('Gunakan Plat Ini'));
  await tester.tap(find.text('Gunakan Plat Ini'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  Map<String, dynamic> sampleSessionJson({
    int id = 89,
    String nim = '244107020204',
    String plateIn = 'N 1234 ABC',
    String? plateOut,
    String status = 'active',
    String? matchMethod = 'plate_exact',
    String? verificationNote,
  }) {
    return {
      'id': id,
      'nim': nim,
      'plate_in': plateIn,
      'plate_out': plateOut,
      'checked_in_at': '2026-10-12T07:32:00.000Z',
      'checked_out_at': plateOut != null ? '2026-10-12T11:00:00.000Z' : null,
      'status': status,
      'match_method': matchMethod,
      'verification_note': verificationNote,
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
    };
  }

  group('CheckInScreen API Integration Tests', () {
    testWidgets('Check-In berhasil mengirim multipart dan menampilkan data backend asli',
        (WidgetTester tester) async {
      _bigScreen(tester);

      Map<String, dynamic>? fields;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/check-in') {
          expect(request.method, 'POST');
          fields = decodeBody(request);
          return http.Response(
            jsonEncode(sampleSessionJson(
                id: 101, plateIn: 'N 5678 XYZ', nim: '244107020204')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(mockClient, const CheckInPage()));
      await _reachConfirmStep(tester);

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(fields?['nim'], '244107020204');
      expect(fields?['plate'], 'N1234ABC');
      expect(find.text('Check-In Berhasil!'), findsOneWidget);
      expect(find.text('#101'), findsOneWidget);
    });

    testWidgets('Check-In 409 duplicate active session menampilkan pesan galat tanpa dialog sukses',
        (WidgetTester tester) async {
      _bigScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/check-in') {
          return http.Response(
            jsonEncode({
              'code': 'duplicate_active_session',
              'message': 'Plat ini sudah punya sesi aktif.',
              'details': {},
            }),
            409,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(mockClient, const CheckInPage()));
      await _reachConfirmStep(tester);

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Check-In Berhasil!'), findsNothing);
      expect(find.text('Plat ini sudah punya sesi aktif.'), findsWidgets);
    });

    testWidgets('Check-In void action mengirim POST /api/sessions/{id}/void',
        (WidgetTester tester) async {
      _bigScreen(tester);

      bool voidCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/check-in') {
          return http.Response(
            jsonEncode(sampleSessionJson(id: 77)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/sessions/77/void') {
          voidCalled = true;
          final body = jsonDecode(request.body);
          expect(body['note'], 'Salah plat nomor');
          return http.Response(
            jsonEncode(sampleSessionJson(id: 77, status: 'voided')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(mockClient, const CheckInPage()));
      await _reachConfirmStep(tester);

      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
      await tester.pump(const Duration(milliseconds: 600));

      // Tap Batalkan Check-In di dialog sukses.
      expect(find.text('Check-In Berhasil!'), findsOneWidget);
      await tester.ensureVisible(
          find.widgetWithText(TextButton, 'Batalkan Check-In'));
      await tester.tap(find.widgetWithText(TextButton, 'Batalkan Check-In'));
      await tester.pump(const Duration(milliseconds: 300));

      // Isi alasan void.
      expect(find.textContaining('Sesi #77 akan dibatalkan'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Salah plat nomor');
      await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, 'Batalkan Check-In'));
      await tester.tap(
          find.widgetWithText(ElevatedButton, 'Batalkan Check-In'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(voidCalled, isTrue);
    });
  });

  group('CheckOutScreen API Integration Tests', () {
    testWidgets('Check-Out pencarian plat persis (exact) dan konfirmasi berhasil',
        (WidgetTester tester) async {
      _bigScreen(tester);

      bool checkOutCalled = false;
      SessionDetail? finished;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/lookup') {
          return http.Response(
            jsonEncode({
              'match_method': 'plate_exact',
              'session':
                  sampleSessionJson(id: 89, plateIn: 'N 1234 ABC'),
              'candidates': [],
              'message': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/sessions/89/check-out') {
          checkOutCalled = true;
          return http.Response(
            jsonEncode(sampleSessionJson(
                id: 89,
                plateIn: 'N 1234 ABC',
                plateOut: 'N 1234 ABC',
                status: 'completed')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(
        mockClient,
        CheckOutPage(onFinished: (s) => finished = s),
      ));

      // Tanpa sesi awal: cari dulu lewat tombol Cari.
      expect(find.text('Belum ada sesi'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'N 1234 ABC');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Cari'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cari'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('SESUAI'), findsOneWidget);

      // Centang KTM.
      await tester.ensureVisible(find.text('KTM telah diperiksa secara visual'));
      await tester.tap(find.text('KTM telah diperiksa secara visual'));
      await tester.pump(const Duration(milliseconds: 200));

      // Konfirmasi Check-Out.
      await tester.ensureVisible(find.text('Konfirmasi Check-Out'));
      await tester.tap(find.text('Konfirmasi Check-Out'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(checkOutCalled, isTrue);
      expect(find.text('Check-Out Berhasil!'), findsOneWidget);

      // Sukses selesai lewat satu callback, tanpa popUntil beranda.
      await tester.tap(find.text('Selesai & Ke Beranda'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(finished?.id, 89);
    });

    testWidgets('Check-Out pencarian kandidat mirip (plate_similar) menampilkan daftar kandidat',
        (WidgetTester tester) async {
      _bigScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/lookup') {
          return http.Response(
            jsonEncode({
              'match_method': 'plate_similar',
              'session': null,
              'candidates': [
                {
                  'session_id': 92,
                  'plate_in': 'N 1234 ABD',
                  'checked_in_at': '2026-10-12T08:00:00.000Z',
                  'area_name': 'POS-UTAMA',
                },
                {
                  'session_id': 95,
                  'plate_in': 'N 1234 ABE',
                  'checked_in_at': '2026-10-12T08:15:00.000Z',
                  'area_name': 'POS-UTAMA',
                },
              ],
              'message': null,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/sessions/92') {
          return http.Response(
            jsonEncode(sampleSessionJson(id: 92, plateIn: 'N 1234 ABD')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(mockClient, const CheckOutPage()));

      // Lakukan pencarian.
      await tester.enterText(find.byType(TextField).first, 'N 1234 ABZ');
      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Cari'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Cari'));
      await tester.pump(const Duration(milliseconds: 600));

      // Kandidat harus tampil.
      expect(find.textContaining('Plat Mirip Ditemukan'), findsOneWidget);
      expect(find.text('N 1234 ABD'), findsOneWidget);
      expect(find.text('N 1234 ABE'), findsOneWidget);

      // Pilih kandidat pertama.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Pilih').first);
      await tester.pump(const Duration(milliseconds: 600));

      // Form verifikasi manual terbuka otomatis.
      expect(find.text('Verifikasi Manual Petugas'), findsOneWidget);
    });

    testWidgets('Check-Out aksi tolak (POST /api/sessions/{id}/reject)',
        (WidgetTester tester) async {
      _bigScreen(tester);

      bool rejectCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/89/reject') {
          rejectCalled = true;
          final body = jsonDecode(request.body);
          expect(body['note'], 'STNK tidak cocok');
          return http.Response(
            jsonEncode(sampleSessionJson(id: 89)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(
        mockClient,
        CheckOutPage(
            initialSession: SessionDetail.fromJson(
                sampleSessionJson(id: 89))),
      ));

      // Tekan tombol Tolak Keluar.
      await tester.ensureVisible(find.text('Tolak Keluar'));
      await tester.tap(find.text('Tolak Keluar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Tolak Check-Out'), findsWidgets);
      await tester.enterText(find.byType(TextField).last, 'STNK tidak cocok');
      await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Tolak Check-Out'));
      await tester.tap(find.widgetWithText(FilledButton, 'Tolak Check-Out'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(rejectCalled, isTrue);
    });

    testWidgets('Check-Out aksi void (POST /api/sessions/{id}/void)',
        (WidgetTester tester) async {
      _bigScreen(tester);

      bool voidCalled = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/sessions/89/void') {
          voidCalled = true;
          final body = jsonDecode(request.body);
          expect(body['note'], 'Salah plat check-in');
          return http.Response(
            jsonEncode(sampleSessionJson(id: 89, status: 'voided')),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(_wrap(
        mockClient,
        CheckOutPage(
            initialSession: SessionDetail.fromJson(
                sampleSessionJson(id: 89))),
      ));

      // Tekan tombol Batalkan (Void).
      await tester.ensureVisible(find.text('Batalkan (Void)'));
      await tester.tap(find.text('Batalkan (Void)'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Batalkan Check-In (Void)'), findsOneWidget);
      await tester.enterText(
          find.byType(TextField).last, 'Salah plat check-in');
      await tester.ensureVisible(
          find.widgetWithText(FilledButton, 'Batalkan Check-In'));
      await tester.tap(find.widgetWithText(FilledButton, 'Batalkan Check-In'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(voidCalled, isTrue);
    });
  });
}
