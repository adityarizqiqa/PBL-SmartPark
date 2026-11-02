import '../repositories/dashboard_repository.dart';

/// Memuat ringkasan beranda beserta kapasitas lahan.
class GetHomeSummary {
  const GetHomeSummary(this._repository, {this.capacity = defaultCapacity});

  /// Kapasitas master-plan; dipakai sampai backend menyediakan angkanya.
  static const int defaultCapacity = 500;

  final DashboardRepository _repository;
  final int capacity;

  Future<HomeSummary> call() async {
    final dashboard = await _repository.fetch();
    return HomeSummary(dashboard: dashboard, capacity: capacity);
  }
}
