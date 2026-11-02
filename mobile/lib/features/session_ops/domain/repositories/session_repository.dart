import 'dart:typed_data';

import '../../../../core/entities/lookup_result.dart';
import '../../../../core/entities/parking_session.dart';

/// Kontrak operasi sesi parkir: check-in, pencarian, check-out, tolak, void.
abstract class SessionRepository {
  /// `POST /api/sessions/check-in` (multipart).
  Future<SessionDetail> checkIn({
    required String nim,
    required String plate,
    String? photoPath,
    String? clientRequestId,
  });

  /// `GET /api/sessions/lookup` — plat persis, plat mirip, lalu NIM.
  Future<LookupResult> lookup({required String plate, String? nim});

  /// `GET /api/sessions/{id}/photo/{side}` — snapshot plat tersimpan.
  ///
  /// Mengembalikan `null` bila foto tidak tersedia (belum diambil).
  Future<Uint8List?> sessionPhoto(int id, String side);

  /// `GET /api/sessions/{id}`.
  Future<SessionDetail> session(int id);

  /// `POST /api/sessions/{id}/check-out` (multipart).
  Future<SessionDetail> checkOut({
    required int id,
    required String plate,
    required String status,
    String? note,
    String? matchMethod,
    String? photoPath,
  });

  /// `POST /api/sessions/{id}/reject` — sesi tetap aktif.
  Future<SessionDetail> reject(int id, {required String note});

  /// `POST /api/sessions/{id}/void` — membatalkan sesi yang salah dibuat.
  Future<SessionDetail> voidSession(int id, {required String note});
}
