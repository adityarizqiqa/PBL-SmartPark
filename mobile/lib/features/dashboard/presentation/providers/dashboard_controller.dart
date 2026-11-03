import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/failures/failure.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/usecases/get_home_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(apiClientProvider));
});

final getHomeSummaryProvider = Provider<GetHomeSummary>((ref) {
  return GetHomeSummary(ref.watch(dashboardRepositoryProvider));
});

/// Keadaan beranda: ringkasan operasional atau galat yang bisa dicoba ulang.
class DashboardState {
  const DashboardState({
    this.summary,
    this.isLoading = false,
    this.failure,
  });

  final HomeSummary? summary;
  final bool isLoading;
  final Failure? failure;

  bool get hasData => summary != null;

  DashboardState copyWith({
    HomeSummary? summary,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    Future.microtask(refresh);
    return const DashboardState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final summary = await ref.read(getHomeSummaryProvider)();
      if (!ref.mounted) return;
      state = DashboardState(summary: summary);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
