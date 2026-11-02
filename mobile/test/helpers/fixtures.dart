import 'dart:convert';

import 'package:http/http.dart' as http;

/// Balasan JSON dengan status 200.
http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

http.Response notFound() => http.Response('Not Found', 404);

/// Membaca isi permintaan: JSON biasa atau field `multipart/form-data`.
///
/// `MockClient` menyerahkan multipart sebagai `http.Request` yang sudah
/// difinalisasi, jadi field-nya diambil dari body mentah.
Map<String, dynamic> decodeBody(http.BaseRequest request) {
  if (request is http.MultipartRequest) {
    return Map<String, dynamic>.from(request.fields);
  }
  if (request is! http.Request) return const {};

  final contentType = request.headers['content-type'] ?? '';
  if (contentType.startsWith('multipart/form-data')) {
    final fields = <String, dynamic>{};
    final pattern = RegExp(
      r'name="([^"]+)"\r\n\r\n([\s\S]*?)\r\n--',
      multiLine: true,
    );
    for (final match in pattern.allMatches(request.body)) {
      final name = match.group(1);
      if (name == null || name == 'photo') continue;
      fields[name] = match.group(2);
    }
    return fields;
  }

  if (request.body.isEmpty) return const {};
  return (jsonDecode(request.body) as Map).cast<String, dynamic>();
}

Map<String, dynamic> officerJson({
  int id = 1,
  String name = 'Budi Santoso',
  String role = 'officer',
  bool isActive = true,
  bool hasPassword = true,
}) {
  return {
    'id': id,
    'employee_no': 'PK00$id',
    'name': name,
    'phone': '0812',
    'role': role,
    'is_active': isActive,
    'has_password': hasPassword,
  };
}

Map<String, dynamic> areaJson({
  int id = 1,
  String code = 'POS-UTAMA',
  String name = 'Pos Parkir Utama',
  bool isActive = true,
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'is_active': isActive,
  };
}

Map<String, dynamic> shiftLoginJson() {
  return {
    'token': 'shift-tok-123',
    'assignment': {
      'id': 10,
      'shift_id': 5,
      'officer_id': 1,
      'officer_name': 'Budi Santoso',
      'joined_at': '2026-10-12T07:00:00',
      'left_at': null,
      'left_note': null,
    },
    'shift': {
      'id': 5,
      'parking_area_id': 1,
      'area_name': 'Pos Parkir Utama',
      'started_at': '2026-10-12T07:00:00',
      'ended_at': null,
      'end_note': null,
      'is_open': true,
      'assignments': <Map<String, dynamic>>[],
    },
  };
}

Map<String, dynamic> sessionDetailJson({
  int id = 89,
  String nim = '244107020204',
  String plateIn = 'N1234ABC',
  String? plateOut,
  String status = 'active',
}) {
  return {
    'id': id,
    'nim': nim,
    'plate_in': plateIn,
    'plate_out': plateOut,
    'checked_in_at': '2026-10-12T07:32:00',
    'checked_out_at': null,
    'status': status,
    'match_method': 'plate_exact',
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
    'events': <Map<String, dynamic>>[],
  };
}
