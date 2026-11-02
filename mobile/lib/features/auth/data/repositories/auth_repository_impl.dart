import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/entities/shift.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/network/api_exception.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';

/// Menerjemahkan `ApiException` menjadi `Failure` dan JSON menjadi entity.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<LoginOptions> loadOptions() async {
    try {
      final results = await Future.wait([
        _remote.fetchOfficers(),
        _remote.fetchAreas(),
      ]);
      return LoginOptions(
        officers: results[0] as List<Officer>,
        areas: results[1] as List<Area>,
      );
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<AuthSession> signInSupervisor({
    required Officer officer,
    required String password,
  }) async {
    try {
      final json = await _remote.signIn(
        officerId: officer.id,
        password: password,
      );
      final session = (json['session'] as Map).cast<String, dynamic>();
      return AuthSession(
        token: json['token'] as String,
        officer: Officer(
          id: session['officer_id'] as int,
          employeeNo: officer.employeeNo,
          name: session['officer_name'] as String,
          phone: officer.phone,
          role: session['role'] as String,
          isActive: true,
          hasPassword: true,
        ),
      );
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<ShiftLogin> joinShift({
    required Officer officer,
    required String password,
    required Area area,
  }) async {
    try {
      final json = await _remote.joinShift(
        officerId: officer.id,
        password: password,
        areaId: area.id,
      );
      return ShiftLogin.fromJson(json);
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remote.signOut();
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<void> leaveShift({required String note}) async {
    try {
      await _remote.leaveShift(note: note);
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
