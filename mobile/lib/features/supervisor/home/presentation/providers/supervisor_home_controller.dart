import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/di/providers.dart';
import '../../../../../core/entities/area.dart';
import '../../../../../core/entities/shift.dart';
import '../../../../../core/failures/failure.dart';

class SupervisorHomeState {
  const SupervisorHomeState({
    this.areas = const [],
    this.openShifts = const [],
    this.isLoading = true,
    this.failure,
  });

  final List<Area> areas;
  final List<Shift> openShifts;
  final bool isLoading;
  final Failure? failure;

  int get totalAreas => areas.length;
  int get activeAreas => areas.where((a) => a.isActive).length;
  int get runningShifts => openShifts.length;

  SupervisorHomeState copyWith({
    List<Area>? areas,
    List<Shift>? openShifts,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return SupervisorHomeState(
      areas: areas ?? this.areas,
      openShifts: openShifts ?? this.openShifts,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

/// Ringkasan konsol pengawas: jumlah lahan dan shift berjalan.
class SupervisorHomeController extends Notifier<SupervisorHomeState> {
  @override
  SupervisorHomeState build() {
    Future.microtask(refresh);
    return const SupervisorHomeState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final areas = await ref
          .read(areaRepositoryProvider)
          .fetchAreas(includeInactive: true);
      if (!ref.mounted) return;
      final shifts =
          await ref.read(shiftRepositoryProvider).fetchShifts(openOnly: true);
      if (!ref.mounted) return;
      state = state.copyWith(
        areas: areas,
        openShifts: shifts,
        isLoading: false,
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }
}

final supervisorHomeControllerProvider =
    NotifierProvider<SupervisorHomeController, SupervisorHomeState>(
  SupervisorHomeController.new,
);
