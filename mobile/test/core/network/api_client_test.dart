import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/session/session_store.dart';

class _FakeTokens implements TokenProvider {
  @override
  String? shiftToken;

  @override
  String? officerToken;
}

void main() {
  test('token dari TokenProvider menjadi header otomatis', () async {
    final tokens = _FakeTokens()
      ..shiftToken = 'shift-abc'
      ..officerToken = 'officer-xyz';

    late Map<String, String> seen;
    final client = ApiClient(
      baseUrl: 'http://test.local',
      tokens: tokens,
      client: MockClient((request) async {
        seen = request.headers;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await client.get('/api/sessions/active');

    expect(seen['X-Shift-Token'], 'shift-abc');
    expect(seen['X-Officer-Token'], 'officer-xyz');
  });

  test('tanpa sesi, header token tidak dikirim', () async {
    late Map<String, String> seen;
    final client = ApiClient(
      baseUrl: 'http://test.local',
      tokens: _FakeTokens(),
      client: MockClient((request) async {
        seen = request.headers;
        return http.Response('{}', 200);
      }),
    );

    await client.get('/api/areas');

    expect(seen.containsKey('X-Shift-Token'), isFalse);
    expect(seen.containsKey('X-Officer-Token'), isFalse);
  });

  test('SessionStore memenuhi TokenProvider dan memberi tahu pendengar', () {
    final store = SessionStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    store.setOfficerSession(
      token: 't',
      id: 4,
      name: 'Dewi',
      userRole: 'spv',
    );

    expect(store.officerToken, 't');
    expect(store.isSupervisor, isTrue);
    expect(notifications, 1);

    store.clear();
    expect(store.officerToken, isNull);
    expect(store.role, isNull);
    expect(notifications, 2);
  });

  test('waktu tunggu habis ditandai kode timeout', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        throw http.ClientException('gagal');
      }),
    );

    expect(
      () => client.get('/api/areas'),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'network', true)),
    );
  });
}
