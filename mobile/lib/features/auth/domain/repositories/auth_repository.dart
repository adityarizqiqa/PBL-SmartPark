import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/entities/shift.dart';
import '../entities/auth_session.dart';

/// Kontrak akses autentikasi. Implementasinya ada di lapisan `data`.
abstract class AuthRepository {
  /// Petugas aktif dan lahan aktif untuk mengisi formulir masuk.
  Future<LoginOptions> loadOptions();

  /// `POST /api/auth/sign-in` — hanya untuk pengawas.
  Future<AuthSession> signInSupervisor({
    required Officer officer,
    required String password,
  });

  /// `POST /api/shifts/join` — petugas gerbang masuk dengan menempel ke shift.
  Future<ShiftLogin> joinShift({
    required Officer officer,
    required String password,
    required Area area,
  });

  /// `POST /api/auth/sign-out`.
  Future<void> signOut();

  /// `POST /api/shifts/leave` — mengakhiri penugasan jaga petugas.
  Future<void> leaveShift({required String note});
}
