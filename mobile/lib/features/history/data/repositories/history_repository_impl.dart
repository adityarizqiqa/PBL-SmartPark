import '../../../../core/failures/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/history_page.dart';
import '../../domain/entities/page_meta.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  const HistoryRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<HistoryPage> fetchPage({
    required int limit,
    required int offset,
    String query = '',
  }) async {
    final params = <String, dynamic>{'limit': limit, 'offset': offset};
    if (query.trim().isNotEmpty) params['q'] = query.trim();

    try {
      // Kedua permintaan selalu berpasangan: daftar tanpa total tidak bisa
      // memberi tahu pengguna masih ada halaman berikutnya.
      final results = await Future.wait([
        _client.get(Endpoints.history, query: params),
        _client.get(Endpoints.historyMeta, query: params),
      ]);

      final items = (results[0] as List)
          .map((e) => HistoryItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      final meta = PageMeta.fromJson(
        (results[1] as Map).cast<String, dynamic>(),
      );

      return HistoryPage(items: items, meta: meta);
    } on ApiException catch (error) {
      throw Failure.fromApiException(error);
    }
  }
}
