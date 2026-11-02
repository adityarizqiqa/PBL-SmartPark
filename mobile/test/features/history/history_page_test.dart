import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/history/domain/entities/history_filter.dart';
import 'package:mobile/features/history/presentation/pages/history_page_view.dart';
import 'package:mobile/features/history/presentation/widgets/history_header.dart';
import 'package:mobile/features/history/presentation/widgets/session_card.dart';

import '../../helpers/fixtures.dart';

void main() {
  Map<String, dynamic> historyJson({
    required int id,
    String nim = '244107020204',
    String plateIn = 'N1234ABC',
    String? plateOut,
    String status = 'matched',
    String? note,
  }) {
    return {
      'id': id,
      'nim': nim,
      'plate_in': plateIn,
      'plate_out': plateOut,
      'checked_in_at': '2026-10-12T07:30:00',
      'checked_out_at': '2026-10-12T10:54:00',
      'status': status,
      'verification_note': note,
    };
  }

  Future<ProviderContainer> pumpHistory(
    WidgetTester tester,
    MockClient client,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(client: client, baseUrl: 'http://test.local'),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: HistoryPageView(areaLabel: 'POS-UTAMA • Pos Parkir Utama'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('memuat halaman riwayat beserta metadata paginasi',
      (tester) async {
    late Uri listUrl;
    late Uri metaUrl;
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          listUrl = request.url;
          return jsonResponse([
            historyJson(id: 1),
            historyJson(
              id: 2,
              plateOut: 'N9999ZZ',
              status: 'manual_verified',
              note: 'Plat tidak terbaca jelas',
            ),
          ]);
        }
        if (request.url.path == '/api/sessions/history/meta') {
          metaUrl = request.url;
          return jsonResponse({'total': 45, 'limit': 20, 'offset': 0});
        }
        return notFound();
      }),
    );

    expect(listUrl.queryParameters['limit'], '20');
    expect(listUrl.queryParameters['offset'], '0');
    expect(metaUrl.queryParameters['limit'], '20');

    expect(find.text('Riwayat Sesi Parkir'), findsOneWidget);
    expect(find.text('1-20 dari 45'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('N1234ABC'), findsWidgets);
    expect(find.text('N9999ZZ'), findsOneWidget);
    expect(find.text('Catatan: Plat tidak terbaca jelas'), findsOneWidget);
  });

  testWidgets('tab status menyaring daftar tanpa memanggil backend lagi',
      (tester) async {
    var calls = 0;
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          calls++;
          return jsonResponse([
            historyJson(id: 1, plateIn: 'AAA111'),
            historyJson(id: 2, plateIn: 'BBB222', status: 'manual_verified'),
          ]);
        }
        if (request.url.path == '/api/sessions/history/meta') {
          return jsonResponse({'total': 2, 'limit': 20, 'offset': 0});
        }
        return notFound();
      }),
    );

    expect(calls, 1);

    await tester.tap(
      find.descendant(
        of: find.byType(HistoryFilters),
        matching: find.text(HistoryStatusFilter.manualVerified.label),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BBB222'), findsOneWidget);
    expect(find.text('AAA111'), findsNothing);
    expect(calls, 1);
  });

  testWidgets('pencarian dikirim sebagai parameter q setelah jeda',
      (tester) async {
    final queries = <String?>[];
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          queries.add(request.url.queryParameters['q']);
          return jsonResponse([historyJson(id: 1)]);
        }
        if (request.url.path == '/api/sessions/history/meta') {
          return jsonResponse({'total': 1, 'limit': 20, 'offset': 0});
        }
        return notFound();
      }),
    );

    await tester.enterText(find.byType(TextField), '244107');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(queries.last, '244107');
  });

  testWidgets('tombol halaman berikutnya meminta offset 20', (tester) async {
    final offsets = <String?>[];
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          offsets.add(request.url.queryParameters['offset']);
          return jsonResponse([historyJson(id: 21)]);
        }
        if (request.url.path == '/api/sessions/history/meta') {
          return jsonResponse({
            'total': 45,
            'limit': 20,
            'offset': int.parse(request.url.queryParameters['offset'] ?? '0'),
          });
        }
        return notFound();
      }),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(PaginationBar),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
    );
    await tester.pumpAndSettle();

    expect(offsets.last, '20');
    expect(find.text('21-40 dari 45'), findsOneWidget);
  });

  testWidgets('empty state membedakan pencarian dan data kosong',
      (tester) async {
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          return jsonResponse(<Map<String, dynamic>>[]);
        }
        return jsonResponse({'total': 0, 'limit': 20, 'offset': 0});
      }),
    );

    expect(find.text('Tidak ada sesi ditemukan'), findsOneWidget);
    expect(
      find.text('Belum ada data riwayat sesi parkir yang tersimpan.'),
      findsOneWidget,
    );
  });

  testWidgets('galat backend tampil dengan tombol coba lagi', (tester) async {
    var calls = 0;
    await pumpHistory(
      tester,
      MockClient((request) async {
        if (request.url.path == '/api/sessions/history') {
          calls++;
          if (calls == 1) {
            return jsonResponse(
              {
                'code': 'unauthorized',
                'message': 'Sesi jaga tidak valid.',
                'details': <String, dynamic>{},
              },
              status: 401,
            );
          }
          return jsonResponse([historyJson(id: 1)]);
        }
        return jsonResponse({'total': 1, 'limit': 20, 'offset': 0});
      }),
    );

    expect(find.text('Sesi jaga tidak valid.'), findsOneWidget);

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Sesi jaga tidak valid.'), findsNothing);
    expect(find.text('N1234ABC'), findsWidgets);
  });
}
