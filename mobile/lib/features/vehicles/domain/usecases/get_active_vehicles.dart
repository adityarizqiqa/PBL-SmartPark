import '../entities/active_vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Memuat kendaraan aktif, lalu menyaring berdasarkan kata kunci.
class GetActiveVehicles {
  const GetActiveVehicles(this._repository);

  final VehicleRepository _repository;

  Future<List<ActiveVehicle>> call({String query = ''}) async {
    final vehicles = await _repository.fetchActive();
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return vehicles;

    return vehicles.where((vehicle) {
      return vehicle.nim.toLowerCase().contains(needle) ||
          vehicle.plateIn.toLowerCase().contains(needle) ||
          vehicle.areaName.toLowerCase().contains(needle) ||
          vehicle.checkedInBy.toLowerCase().contains(needle);
    }).toList();
  }
}
