import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';

/// Akses HTTP mentah untuk autentikasi. Tidak memetakan galat; itu tugas
/// repositori.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Officer>> fetchOfficers() async {
    final raw = await _client.get(Endpoints.officers);
    return (raw as List)
        .map((e) => Officer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Area>> fetchAreas() async {
    final raw = await _client.get(Endpoints.areas);
    return (raw as List)
        .map((e) => Area.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> signIn({
    required int officerId,
    required String password,
  }) async {
    final raw = await _client.post(
      Endpoints.signIn,
      body: {'officer_id': officerId, 'password': password},
    );
    return (raw as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> joinShift({
    required int officerId,
    required String password,
    required int areaId,
  }) async {
    final raw = await _client.post(
      Endpoints.joinShift,
      body: {
        'officer_id': officerId,
        'password': password,
        'parking_area_id': areaId,
      },
    );
    return (raw as Map).cast<String, dynamic>();
  }

  Future<void> signOut() => _client.post(Endpoints.signOut);
}
