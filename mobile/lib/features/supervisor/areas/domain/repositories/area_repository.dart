import '../../../../../core/entities/area.dart';

/// Kontrak pengelolaan lahan parkir.
abstract class AreaRepository {
  /// `GET /api/areas` — termasuk lahan nonaktif bila [includeInactive].
  Future<List<Area>> fetchAreas({bool includeInactive = false});

  /// `POST /api/areas`.
  Future<Area> create({required String code, required String name});

  /// `PATCH /api/areas/{id}` — nama dan/atau status aktif.
  Future<Area> update(int id, {String? name, bool? isActive});
}
