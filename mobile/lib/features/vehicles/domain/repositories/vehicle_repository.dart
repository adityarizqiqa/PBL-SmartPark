import '../entities/active_vehicle.dart';

/// Kontrak daftar kendaraan yang masih parkir.
abstract class VehicleRepository {
  /// `GET /api/sessions/active` — terlama lebih dulu.
  Future<List<ActiveVehicle>> fetchActive();
}
