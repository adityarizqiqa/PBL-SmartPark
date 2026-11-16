import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/failures/failure.dart';
import '../../domain/entities/history_filter.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/history_page.dart';
import '../../domain/usecases/get_history_page.dart';

final getHistoryPageProvider = Provider<GetHistoryPage>((ref) {
  return GetHistoryPage(ref.watch(historyRepositoryProvider));
});

class HistoryState {
  const HistoryState({
    this.page,
    this.query = '',
    this.statusFilter = HistoryStatusFilter.all,
    this.period = HistoryPeriod.all,
    this.selectedDate,
    this.isLoading = true,
    this.failure,
  });

  final HistoryPage? page;
  final String query;
  final HistoryStatusFilter statusFilter;
  final HistoryPeriod period;
  final DateTime? selectedDate;
  final bool isLoading;
  final Failure? failure;

  List<HistoryItem> get items => page?.items ?? const [];

  /// Saringan status dan periode dilakukan di klien karena endpoint riwayat
  /// hanya menerima `q` untuk pencarian teks.
  List<HistoryItem> get visibleItems {
    final status = statusFilter.status;
    final withStatus =
        status == null ? items : items.where((i) => i.status == status).toList();
    return _filterByPeriod(withStatus);
  }

  List<HistoryItem> _filterByPeriod(List<HistoryItem> list) {
    final DateTime? reference = switch (period) {
      HistoryPeriod.all => null,
      HistoryPeriod.today => DateTime.now(),
      HistoryPeriod.yesterday =>
        DateTime.now().subtract(const Duration(days: 1)),
      HistoryPeriod.custom => selectedDate ?? DateTime.now(),
    };
    if (reference == null) return list;
    return list
        .where((item) => _sameLocalDay(item.checkedInAt, reference))
        .toList();
  }

  int get total => page?.total ?? 0;
  int get matchedCount => items.where((i) => i.status == 'matched').length;
  int get manualCount =>
      items.where((i) => i.status == 'manual_verified').length;
  int get activeCount => items.where((i) => i.status == 'active').length;

  HistoryState copyWith({
    HistoryPage? page,
    String? query,
    HistoryStatusFilter? statusFilter,
    HistoryPeriod? period,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return HistoryState(
      page: page ?? this.page,
      query: query ?? this.query,
      statusFilter: statusFilter ?? this.statusFilter,
      period: period ?? this.period,
      selectedDate:
          clearSelectedDate ? null : selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

/// Sama hari pada zona lokal (bukan UTC), karena riwayat ditampilkan per hari.
bool _sameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Mengatur pencarian, saringan status, dan perpindahan halaman riwayat.
class HistoryController extends Notifier<HistoryState> {
  Timer? _debounce;

  @override
  HistoryState build() {
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(refresh);
    return const HistoryState();
  }

  void setStatusFilter(HistoryStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void setPeriod(HistoryPeriod period, DateTime? date) {
    state = state.copyWith(
      period: period,
      selectedDate: date,
      clearSelectedDate: period != HistoryPeriod.custom,
    );
  }

  /// Menunda permintaan 400 ms agar setiap ketikan tidak memanggil backend.
  void search(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _load(offset: 0);
    });
  }

  void nextPage() {
    final page = state.page;
    if (page == null || !page.hasNext) return;
    _load(offset: page.offset + page.limit);
  }

  void previousPage() {
    final page = state.page;
    if (page == null || !page.hasPrevious) return;
    final offset = (page.offset - page.limit).clamp(0, page.total);
    _load(offset: offset);
  }

  Future<void> refresh() => _load(offset: state.page?.offset ?? 0);

  Future<void> _load({required int offset}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final page = await ref.read(getHistoryPageProvider)(
        offset: offset,
        query: state.query,
      );
      if (!ref.mounted) return;
      state = state.copyWith(page: page, isLoading: false);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
