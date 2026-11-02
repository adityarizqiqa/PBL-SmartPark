import '../../../../../core/entities/officer.dart';
import '../../../../../core/failures/failure.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/network/endpoints.dart';
import '../../domain/repositories/officer_repository.dart';

class OfficerRepositoryImpl implements OfficerRepository {
  const OfficerRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Officer>> fetchOfficers({bool includeInactive = false}) async {
    try {
      final raw = await _client.get(
        Endpoints.officers,
        query: {if (includeInactive) QueryKeys.includeInactive: true},
      );
      return (raw as List)
          .map((e) => Officer.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Officer> create({
    required String name,
    required String password,
    required String role,
    String? employeeNo,
    String? phone,
  }) async {
    try {
      final raw = await _client.post(
        Endpoints.officers,
        body: {
          'employee_no': employeeNo,
          'name': name,
          'phone': phone,
          'role': role,
          'password': password,
        },
      );
      return Officer.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Officer> update(
    int id, {
    String? password,
    bool? isActive,
    String? role,
  }) async {
    try {
      final raw = await _client.patch(
        Endpoints.officer(id),
        body: {
          'password': ?password,
          'is_active': ?isActive,
          'role': ?role,
        },
      );
      return Officer.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
