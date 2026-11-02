import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/domain/usecases/sign_in.dart';
import 'package:mobile/features/auth/presentation/pages/login_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  ProviderContainer makeContainer(http.Client client) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(client: client, baseUrl: 'http://test.local'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  testWidgets('menampilkan petugas aktif dan lahan aktif saja', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    final container = makeContainer(
      MockClient((request) async => switch (request.url.path) {
            '/api/officers' => jsonResponse([
                officerJson(id: 1, name: 'Budi Santoso'),
                officerJson(id: 4, name: 'Dewi Kartika', role: 'spv'),
                officerJson(id: 9, name: 'Nonaktif', isActive: false),
              ]),
            '/api/areas' => jsonResponse([
                areaJson(code: 'POS-UTAMA', name: 'Pos Parkir Utama'),
                areaJson(id: 2, code: 'POS-BARAT', name: 'Nonaktif', isActive: false),
              ]),
            _ => notFound(),
          }),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Dewi Kartika'), findsOneWidget);
    expect(find.text('SPV'), findsOneWidget);
    expect(find.text('Nonaktif'), findsNothing);
    expect(find.text('POS-UTAMA • Pos Parkir Utama'), findsOneWidget);
    expect(find.text('POS-BARAT • Nonaktif'), findsNothing);
  });

  testWidgets('petugas gerbang memakai /api/shifts/join dan mengisi sesi',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? joinBody;
    final container = makeContainer(
      MockClient((request) async {
        switch (request.url.path) {
          case '/api/officers':
            return jsonResponse([officerJson(id: 1, name: 'Budi Santoso')]);
          case '/api/areas':
            return jsonResponse([areaJson()]);
          case '/api/shifts/join':
            joinBody = decodeBody(request);
            return jsonResponse(shiftLoginJson());
        }
        return notFound();
      }),
    );

    SignInResult? signedIn;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: LoginPage(onSignedIn: (r) => signedIn = r)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'budi1234');
    await tester.ensureVisible(find.text('Mulai Bertugas'));
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    expect(joinBody, {
      'officer_id': 1,
      'password': 'budi1234',
      'parking_area_id': 1,
    });

    final store = container.read(sessionStoreProvider);
    expect(store.shiftToken, 'shift-tok-123');
    expect(store.officerName, 'Budi Santoso');
    expect(store.areaName, 'Pos Parkir Utama');
    expect(store.isSupervisor, isFalse);

    expect(signedIn, isA<OfficerJoinedShift>());
    expect((signedIn! as OfficerJoinedShift).area.code, 'POS-UTAMA');
  });

  testWidgets('pengawas memakai /api/auth/sign-in dan tidak butuh lahan',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? signInBody;
    final container = makeContainer(
      MockClient((request) async {
        switch (request.url.path) {
          case '/api/officers':
            return jsonResponse([
              officerJson(id: 4, name: 'Dewi Kartika', role: 'spv'),
            ]);
          case '/api/areas':
            return jsonResponse([areaJson()]);
          case '/api/auth/sign-in':
            signInBody = decodeBody(request);
            return jsonResponse({
              'token': 'spv-tok',
              'session': {
                'id': 7,
                'officer_id': 4,
                'officer_name': 'Dewi Kartika',
                'role': 'spv',
                'signed_in_at': '2026-10-12T07:00:00',
                'revoked_at': null,
                'is_active': true,
              },
            });
        }
        return notFound();
      }),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'spvpass');
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    expect(signInBody, {'officer_id': 4, 'password': 'spvpass'});
    final store = container.read(sessionStoreProvider);
    expect(store.officerToken, 'spv-tok');
    expect(store.isSupervisor, isTrue);
  });

  testWidgets('galat backend tampil sebagai snack bar dan sesi tetap kosong',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);

    final container = makeContainer(
      MockClient((request) async {
        switch (request.url.path) {
          case '/api/officers':
            return jsonResponse([officerJson(id: 1, name: 'Budi Santoso')]);
          case '/api/areas':
            return jsonResponse([areaJson()]);
          case '/api/shifts/join':
            return jsonResponse(
              {
                'code': 'invalid_credentials',
                'message': 'Kata sandi salah.',
                'details': <String, dynamic>{},
              },
              status: 401,
            );
        }
        return notFound();
      }),
    );

    SignInResult? signedIn;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: LoginPage(onSignedIn: (r) => signedIn = r)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'salahsekali');
    await tester.tap(find.text('Mulai Bertugas'));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi salah.'), findsOneWidget);
    expect(signedIn, isNull);
    expect(container.read(sessionStoreProvider).shiftToken, isNull);
  });

}
