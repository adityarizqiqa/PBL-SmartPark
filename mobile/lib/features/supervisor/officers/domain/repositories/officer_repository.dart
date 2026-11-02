import '../../../../../core/entities/officer.dart';

/// Kontrak pengelolaan data petugas.
abstract class OfficerRepository {
  /// `GET /api/officers` — termasuk petugas nonaktif bila [includeInactive].
  Future<List<Officer>> fetchOfficers({bool includeInactive = false});

  /// `POST /api/officers`.
  Future<Officer> create({
    required String name,
    required String password,
    required String role,
    String? employeeNo,
    String? phone,
  });

  /// `PATCH /api/officers/{id}` — kata sandi, status aktif, atau peran.
  Future<Officer> update(
    int id, {
    String? password,
    bool? isActive,
    String? role,
  });
}
