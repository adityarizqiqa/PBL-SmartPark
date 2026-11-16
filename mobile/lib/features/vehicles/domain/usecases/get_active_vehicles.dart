import '../entities/active_vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Memuat seluruh kendaraan aktif.
///
/// Penyaringan kata kunci dilakukan di sisi klien oleh `VehiclesState.visible`
/// karena daftar aktif kecil dan backend tidak punya parameter pencarian.
class GetActiveVehicles {
  const GetActiveVehicles(this._repository);

  final VehicleRepository _repository;

  Future<List<ActiveVehicle>> call() => _repository.fetchActive();
}
