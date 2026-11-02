import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/entities/shift.dart';
import '../entities/auth_session.dart';
import '../repositories/auth_repository.dart';

/// Memuat pilihan petugas dan lahan, hanya yang aktif.
class LoadLoginOptions {
  const LoadLoginOptions(this._repository);

  final AuthRepository _repository;

  Future<LoginOptions> call() async {
    final options = await _repository.loadOptions();
    return LoginOptions(
      officers: options.officers.where((o) => o.isActive).toList(),
      areas: options.areas.where((a) => a.isActive).toList(),
    );
  }
}

/// Hasil masuk yang sudah siap dipakai lapisan sesi.
sealed class SignInResult {
  const SignInResult();
}

final class SupervisorSignedIn extends SignInResult {
  const SupervisorSignedIn(this.session);

  final AuthSession session;
}

final class OfficerJoinedShift extends SignInResult {
  const OfficerJoinedShift(this.login, this.officer, this.area);

  final ShiftLogin login;
  final Officer officer;
  final Area area;
}

/// Memilih endpoint masuk berdasarkan peran petugas.
class SignIn {
  const SignIn(this._repository);

  final AuthRepository _repository;

  Future<SignInResult> call({
    required Officer officer,
    required String password,
    Area? area,
  }) async {
    if (officer.isSupervisor) {
      final session = await _repository.signInSupervisor(
        officer: officer,
        password: password,
      );
      return SupervisorSignedIn(session);
    }

    final target = area;
    if (target == null) {
      throw StateError('Lahan parkir wajib dipilih untuk petugas gerbang.');
    }

    final login = await _repository.joinShift(
      officer: officer,
      password: password,
      area: target,
    );
    return OfficerJoinedShift(login, officer, target);
  }
}
