import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/api/api_client.dart';
import 'package:mobile/api/api_exception.dart';
import 'package:mobile/models/models.dart';

void main() {
  test('GET /api/officers dipetakan menjadi List<Officer>', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        expect(request.url.path, '/api/officers');
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
              'phone': null,
              'role': 'spv',
              'is_active': true,
              'has_password': true,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final data = await client.get('/api/officers') as List;
    final officers = data
        .map((e) => Officer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    expect(officers, hasLength(2));
    expect(officers.first.name, 'Budi Santoso');
    expect(officers.last.isSupervisor, isTrue);
  });

  test('galat backend menjadi ApiException dengan pesan asli', () async {
    final client = ApiClient(
      baseUrl: 'http://test.local',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'duplicate_active_session',
            'message': 'Plat ini sudah punya sesi aktif.',
            'details': <String, dynamic>{},
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => client.get('/api/sessions/active'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.code, 'code', 'duplicate_active_session')
            .having((e) => e.message, 'message',
                'Plat ini sudah punya sesi aktif.'),
      ),
    );
  });

  test('SessionDetail memetakan respons detail sesi', () {
    final json = {
      'id': 3,
      'nim': '244107020008',
      'plate_in': 'B1234XYZ',
      'plate_out': null,
      'checked_in_at': '2026-10-08T00:32:00',
      'checked_out_at': null,
      'status': 'active',
      'match_method': null,
      'verification_note': null,
      'plate_in_photo_path': 'plates/in.jpg',
      'plate_out_photo_path': null,
      'area_id': 1,
      'area_name': 'Pos Parkir Utama',
      'checked_in_by': {
        'assignment_id': 1,
        'officer_id': 1,
        'officer_name': 'Budi Santoso',
      },
      'checked_out_by': null,
      'events': [
        {
          'id': 1,
          'event_type': 'check_in',
          'note': null,
          'actor_name': 'Budi Santoso',
          'created_at': '2026-10-08T00:32:00',
        },
      ],
    };

    final session = SessionDetail.fromJson(json);

    expect(session.id, 3);
    expect(session.plateOut, isNull);
    expect(session.checkedInBy.officerName, 'Budi Santoso');
    expect(session.events, hasLength(1));
    expect(session.events.first.eventType, 'check_in');
  });
}
