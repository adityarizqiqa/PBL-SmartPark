import '../../../../core/failures/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/entities/active_vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  const VehicleRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<ActiveVehicle>> fetchActive() async {
    try {
      final raw = await _client.get(Endpoints.activeSessions);
      return (raw as List)
          .map((e) => ActiveVehicle.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
