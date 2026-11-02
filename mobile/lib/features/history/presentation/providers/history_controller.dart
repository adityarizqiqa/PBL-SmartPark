import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/failures/failure.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../domain/entities/history_filter.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/entities/history_page.dart';
import '../../domain/repositories/history_repository.dart';
import '../../domain/usecases/get_history_page.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl(ref.watch(apiClientProvider));
});

final getHistoryPageProvider = Provider<GetHistoryPage>((ref) {
  return GetHistoryPage(ref.watch(historyRepositoryProvider));
});

class HistoryState {
  const HistoryState({
    this.page,
    this.query = '',
    this.statusFilter = HistoryStatusFilter.all,
    this.period = HistoryPeriod.today,
    this.isLoading = true,
    this.failure,
  });

  final HistoryPage? page;
  final String query;
  final HistoryStatusFilter statusFilter;
  final HistoryPeriod period;
  final bool isLoading;
  final Failure? failure;

  List<HistoryItem> get items => page?.items ?? const [];

  /// Saringan status dilakukan di klien karena endpoint hanya menerima `q`.
  List<HistoryItem> get visibleItems {
    final status = statusFilter.status;
    if (status == null) return items;
    return items.where((item) => item.status == status).toList();
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
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return HistoryState(
      page: page ?? this.page,
      query: query ?? this.query,
      statusFilter: statusFilter ?? this.statusFilter,
      period: period ?? this.period,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
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

  void setPeriod(HistoryPeriod period) {
    state = state.copyWith(period: period);
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
      state = state.copyWith(page: page, isLoading: false);
    } on Failure catch (failure) {
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, HistoryState>(HistoryController.new);
