import '../../../../../core/entities/shift.dart';
import '../../../../../core/failures/failure.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/network/endpoints.dart';
import '../../domain/repositories/shift_repository.dart';

class ShiftRepositoryImpl implements ShiftRepository {
  const ShiftRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Shift>> fetchShifts({bool openOnly = false}) async {
    try {
      final raw = await _client.get(
        Endpoints.shifts,
        query: {if (openOnly) QueryKeys.openOnly: true},
      );
      return (raw as List)
          .map((e) => Shift.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Shift> open(int parkingAreaId) async {
    try {
      final raw = await _client.post(
        Endpoints.openShift,
        body: {'parking_area_id': parkingAreaId},
      );
      return Shift.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Shift> close(int id, {required String note}) async {
    try {
      final raw = await _client.post(
        Endpoints.closeShift(id),
        body: {'note': note},
      );
      return Shift.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
