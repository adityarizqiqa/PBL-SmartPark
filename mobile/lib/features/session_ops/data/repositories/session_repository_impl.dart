import 'dart:typed_data';

import '../../../../core/entities/lookup_result.dart';
import '../../../../core/entities/parking_session.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  const SessionRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<SessionDetail> checkIn({
    required String nim,
    required String plate,
    String? photoPath,
    String? clientRequestId,
  }) async {
    try {
      final raw = await _client.postMultipart(
        Endpoints.checkIn,
        fields: {'nim': nim, 'plate': plate, 'client_request_id': clientRequestId},
        photoPath: photoPath,
      );
      return SessionDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<LookupResult> lookup({required String plate, String? nim}) async {
    try {
      final raw = await _client.get(
        Endpoints.lookup,
        query: {'plate': plate, if (nim != null && nim.isNotEmpty) 'nim': nim},
      );
      return LookupResult.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<SessionDetail> session(int id) async {
    try {
      final raw = await _client.get(Endpoints.session(id));
      return SessionDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Uint8List?> sessionPhoto(int id, String side) async {
    try {
      final bytes = await _client.getBytes(Endpoints.sessionPhoto(id, side));
      return Uint8List.fromList(bytes);
    } on ApiException catch (error) {
      // Foto memang belum tersedia: bukan kesalahan fatal bagi alur.
      if (error.statusCode == 404) return null;
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<SessionDetail> checkOut({
    required int id,
    required String plate,
    required String status,
    String? note,
    String? matchMethod,
    String? photoPath,
  }) async {
    try {
      final raw = await _client.postMultipart(
        Endpoints.checkOut(id),
        fields: {
          'plate': plate,
          'status': status,
          'note': note,
          'match_method': matchMethod,
        },
        photoPath: photoPath,
      );
      return SessionDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<SessionDetail> reject(int id, {required String note}) async {
    try {
      final raw = await _client.post(Endpoints.reject(id), body: {'note': note});
      return SessionDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<SessionDetail> voidSession(int id, {required String note}) async {
    try {
      final raw = await _client.post(
        Endpoints.voidSession(id),
        body: {'note': note},
      );
      return SessionDetail.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
