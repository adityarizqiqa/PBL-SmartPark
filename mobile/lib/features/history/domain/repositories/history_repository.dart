import '../entities/history_page.dart';

/// Kontrak riwayat sesi parkir.
abstract class HistoryRepository {
  /// Mengambil satu halaman riwayat dan totalnya.
  ///
  /// `query` dicocokkan backend ke NIM maupun plat.
  Future<HistoryPage> fetchPage({
    required int limit,
    required int offset,
    String query = '',
  });
}
