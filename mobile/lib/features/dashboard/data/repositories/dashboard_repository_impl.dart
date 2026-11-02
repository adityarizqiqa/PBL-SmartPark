import '../../../../core/failures/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/entities/dashboard.dart';
import '../../domain/repositories/dashboard_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Dashboard> fetch() async {
    try {
      final raw = await _client.get(Endpoints.dashboard);
      return Dashboard.fromJson((raw as Map).cast<String, dynamic>());
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
