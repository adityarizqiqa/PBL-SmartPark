import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/di/providers.dart';
import '../../../../../core/entities/area.dart';
import '../../../../../core/entities/shift.dart';
import '../../../../../core/failures/failure.dart';
import '../../../areas/data/repositories/area_repository_impl.dart';
import '../../../areas/domain/repositories/area_repository.dart';
import '../../data/repositories/shift_repository_impl.dart';
import '../../domain/repositories/shift_repository.dart';

final supervisorShiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepositoryImpl(ref.watch(apiClientProvider));
});

final supervisorAreaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(ref.watch(apiClientProvider));
});

class ShiftsState {
  const ShiftsState({
    this.areas = const [],
    this.shifts = const [],
    this.selectedAreaId,
    this.isLoading = true,
    this.isSaving = false,
    this.failure,
  });

  final List<Area> areas;
  final List<Shift> shifts;
  final int? selectedAreaId;
  final bool isLoading;
  final bool isSaving;
  final Failure? failure;

  List<Shift> get openShifts => shifts.where((s) => s.isOpen).toList();
  List<Shift> get history => shifts.where((s) => !s.isOpen).toList();

  Area? get selectedArea {
    for (final area in areas) {
      if (area.id == selectedAreaId) return area;
    }
    return null;
  }

  /// `POS-UTAMA • Pos Parkir Utama`
  String areaLabelOf(Shift shift) {
    for (final area in areas) {
      if (area.id == shift.parkingAreaId) {
        return '${area.code} • ${shift.areaName}';
      }
    }
    return shift.areaName;
  }

  bool hasOpenShift(int areaId) =>
      openShifts.any((shift) => shift.parkingAreaId == areaId);

  ShiftsState copyWith({
    List<Area>? areas,
    List<Shift>? shifts,
    int? selectedAreaId,
    bool? isLoading,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ShiftsState(
      areas: areas ?? this.areas,
      shifts: shifts ?? this.shifts,
      selectedAreaId: selectedAreaId ?? this.selectedAreaId,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class ShiftsController extends Notifier<ShiftsState> {
  @override
  ShiftsState build() {
    Future.microtask(refresh);
    return const ShiftsState();
  }

  void selectArea(int areaId) {
    state = state.copyWith(selectedAreaId: areaId);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final areas = await ref.read(supervisorAreaRepositoryProvider).fetchAreas();
      final shifts =
          await ref.read(supervisorShiftRepositoryProvider).fetchShifts();

      final ids = areas.map((a) => a.id).toSet();
      final selected = state.selectedAreaId;
      state = state.copyWith(
        areas: areas,
        shifts: shifts,
        selectedAreaId: selected != null && ids.contains(selected)
            ? selected
            : (areas.isEmpty ? null : areas.first.id),
        isLoading: false,
      );
    } on Failure catch (failure) {
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  /// Satu lahan hanya boleh punya satu shift terbuka.
  Future<String?> open() async {
    final area = state.selectedArea;
    if (area == null) return 'Pilih lahan parkir terlebih dahulu.';
    if (state.hasOpenShift(area.id)) {
      return 'Satu lahan hanya boleh punya satu shift terbuka.';
    }

    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(supervisorShiftRepositoryProvider).open(area.id);
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<String?> close(Shift shift, String note) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(supervisorShiftRepositoryProvider).close(
            shift.id,
            note: note,
          );
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final shiftsControllerProvider =
    NotifierProvider<ShiftsController, ShiftsState>(ShiftsController.new);
