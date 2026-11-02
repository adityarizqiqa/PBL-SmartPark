import '../../../../../core/entities/area.dart';
import '../../../../../core/failures/failure.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/network/endpoints.dart';
import '../../domain/repositories/area_repository.dart';

class AreaRepositoryImpl implements AreaRepository {
  const AreaRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<Area>> fetchAreas({bool includeInactive = false}) async {
    try {
      final raw = await _client.get(
        Endpoints.areas,
        query: {if (includeInactive) QueryKeys.includeInactive: true},
      );
      return (raw as List)
          .map((e) => Area.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Area> create({required String code, required String name}) async {
    try {
      final raw = await _client.post(
        Endpoints.areas,
        body: {'code': code, 'name': name},
      );
      return Area.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }

  @override
  Future<Area> update(int id, {String? name, bool? isActive}) async {
    try {
      final raw = await _client.patch(
        Endpoints.area(id),
        body: {
          'name': ?name,
          'is_active': ?isActive,
        },
      );
      return Area.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
