import 'history_item.dart';
import 'page_meta.dart';

/// Satu halaman riwayat beserta metadata paginasinya.
///
/// Kedua endpoint (`/history` dan `/history/meta`) selalu diminta bersamaan,
/// sehingga digabung menjadi satu nilai yang tidak mungkin tidak sinkron.
class HistoryPage {
  const HistoryPage({required this.items, required this.meta});

  final List<HistoryItem> items;
  final PageMeta meta;

  int get total => meta.total;
  int get limit => meta.limit;
  int get offset => meta.offset;

  int get pageNumber => limit == 0 ? 1 : (offset ~/ limit) + 1;
  int get pageCount {
    if (limit <= 0 || total <= 0) return 1;
    return ((total + limit - 1) ~/ limit).clamp(1, 999999);
  }

  bool get hasPrevious => offset > 0;
  bool get hasNext => offset + limit < total;

  /// `1-20 dari 45`
  String get rangeLabel {
    if (total == 0) return '0 dari 0';
    final start = offset + 1;
    final end = (offset + limit).clamp(1, total);
    return '$start-$end dari $total';
  }
}
