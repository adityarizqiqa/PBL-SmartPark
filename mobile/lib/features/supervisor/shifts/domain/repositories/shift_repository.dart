import '../../../../../core/entities/shift.dart';

/// Kontrak pengelolaan shift jaga.
abstract class ShiftRepository {
  /// `GET /api/shifts` — hanya shift terbuka bila [openOnly].
  Future<List<Shift>> fetchShifts({bool openOnly = false});

  /// `POST /api/shifts/open`.
  Future<Shift> open(int parkingAreaId);

  /// `POST /api/shifts/{id}/close`.
  Future<Shift> close(int id, {required String note});
}
