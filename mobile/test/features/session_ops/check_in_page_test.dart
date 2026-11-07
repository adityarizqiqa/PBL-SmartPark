import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/session_ops/presentation/pages/check_in_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  Future<void> pumpCheckIn(WidgetTester tester, MockClient client) async {
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
        child: const MaterialApp(home: CheckInPage()),
      ),
    );
    // Animasi laser berulang membuat pumpAndSettle tidak pernah selesai.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> reachConfirmStep(WidgetTester tester) async {
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

  testWidgets('check-in mengirim nim dan plat lalu memakai data backend',
      (tester) async {
    Map<String, dynamic>? fields;
    await pumpCheckIn(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/check-in') {
          expect(request.method, 'POST');
          fields = decodeBody(request);
          return jsonResponse(sessionDetailJson(id: 101, plateIn: 'N5678XYZ'));
        }
        return notFound();
      }),
    );

    await reachConfirmStep(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(fields?['nim'], isNotNull);
    expect(fields?['plate'], isNotNull);
    expect(find.text('Check-In Berhasil!'), findsOneWidget);
    expect(find.text('#101'), findsOneWidget);
  });

  testWidgets('galat jaringan tidak lagi menampilkan sesi palsu',
      (tester) async {
    await pumpCheckIn(
      tester,
      MockClient((request) async {
        throw http.ClientException('server mati');
      }),
    );

    await reachConfirmStep(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Check-In Berhasil!'), findsNothing);
    expect(find.textContaining('Tidak bisa menghubungi server'), findsWidgets);
  });

  testWidgets('plat yang sudah aktif (409) memakai pesan backend',
      (tester) async {
    await pumpCheckIn(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/check-in') {
          return jsonResponse(
            {
              'code': 'duplicate_active_session',
              'message': 'Plat ini sudah punya sesi aktif.',
              'details': <String, dynamic>{},
            },
            status: 409,
          );
        }
        return notFound();
      }),
    );

    await reachConfirmStep(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Check-In'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Check-In Berhasil!'), findsNothing);
    expect(find.text('Plat ini sudah punya sesi aktif.'), findsWidgets);
  });

  testWidgets(
      'transisi antar step 1 -> step 2 -> step 1 berjalan mulus dan me-reset scanner',
      (tester) async {
    await pumpCheckIn(
      tester,
      MockClient((request) async => notFound()),
    );

    // Di Step 1
    expect(find.text('LANGKAH 1 DARI 3'), findsOneWidget);
    expect(find.text('Scan KTM'), findsOneWidget);

    // Pindah ke Step 2 lewat jalur NIM manual (validasi alur baru).
    await tester.ensureVisible(find.text('Ketik NIM Manual'));
    await tester.tap(find.text('Ketik NIM Manual'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Input NIM Manual'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '244107020204');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('LANJUT SCAN PLAT KENDARAAN'));
    await tester.tap(find.text('LANJUT SCAN PLAT KENDARAAN'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Langkah 2 dari 3'), findsOneWidget);

    // Kembali: plat -> NIM manual.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Input NIM Manual'), findsOneWidget);

    // Kembali lagi: NIM manual -> Step 1.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump(const Duration(milliseconds: 400));

    // Kembali di Step 1
    expect(find.text('LANGKAH 1 DARI 3'), findsOneWidget);
    expect(find.text('Scan KTM'), findsOneWidget);
  });

  testWidgets('tombol Pindai Ulang dapat ditekan tanpa crash',
      (tester) async {
    await pumpCheckIn(
      tester,
      MockClient((request) async => notFound()),
    );

    await tester.ensureVisible(find.text('Pindai Ulang'));
    await tester.tap(find.text('Pindai Ulang'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Scan KTM'), findsOneWidget);
  });
}
