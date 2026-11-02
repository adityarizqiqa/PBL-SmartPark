import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:mobile/core/di/providers.dart';
import 'package:mobile/core/failures/failure.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/session/session_store.dart';
import 'package:mobile/features/auth/presentation/providers/auth_actions.dart';

import '../../helpers/fixtures.dart';

void main() {
  ProviderContainer makeContainer(MockClient client) {
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(
          SessionStore()..shiftToken = 'shift-token',
        ),
        apiClientProvider.overrideWithValue(
          ApiClient(client: client, baseUrl: 'http://test.local'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('leave 200 menutup sesi lokal dan mengembalikan null', () async {
    final container = makeContainer(
      MockClient((request) async => jsonResponse({'id': 7})),
    );

    final failure = await container.read(leaveShiftActionProvider)('selesai');

    expect(failure, isNull);
    expect(container.read(sessionStoreProvider).shiftToken, isNull);
  });

  test('leave 500 menahan sesi lokal dan mengembalikan galat', () async {
    final container = makeContainer(
      MockClient(
        (request) async => jsonResponse(
          {'code': 'internal_error', 'message': 'Rusak'},
          status: 500,
        ),
      ),
    );

    final failure = await container.read(leaveShiftActionProvider)('selesai');

    expect(failure, isA<ServerFailure>());
    // Sesi lokal dipertahankan agar shift bisa ditutup ulang, bukan terkunci.
    expect(
      container.read(sessionStoreProvider).shiftToken,
      'shift-token',
    );
  });

  test('leave 401 sesi sudah mati: tetap keluar lokal', () async {
    final container = makeContainer(
      MockClient(
        (request) async => jsonResponse(
          {'code': 'unauthorized', 'message': 'Token mati.'},
          status: 401,
        ),
      ),
    );

    final failure = await container.read(leaveShiftActionProvider)('selesai');

    expect(failure, isNull);
    expect(container.read(sessionStoreProvider).shiftToken, isNull);
  });
}
