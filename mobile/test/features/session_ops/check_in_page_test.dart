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
    await tester.ensureVisible(find.text('Lanjut Scan Plat'));
    await tester.tap(find.text('Lanjut Scan Plat'));
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
}
