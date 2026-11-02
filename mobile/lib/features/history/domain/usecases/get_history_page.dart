import '../entities/history_page.dart';
import '../repositories/history_repository.dart';

/// Memuat satu halaman riwayat dengan batas ukuran yang aman.
class GetHistoryPage {
  const GetHistoryPage(this._repository);

  static const int defaultLimit = 20;

  /// Batas `limit` yang diterima backend (`ge=1, le=200`).
  static const int maxLimit = 200;

  final HistoryRepository _repository;

  Future<HistoryPage> call({
    int limit = defaultLimit,
    int offset = 0,
    String query = '',
  }) {
    return _repository.fetchPage(
      limit: limit.clamp(1, maxLimit),
      offset: offset < 0 ? 0 : offset,
      query: query,
    );
  }
}
