import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/di/providers.dart';
import '../../../../../core/entities/area.dart';
import '../../../../../core/failures/failure.dart';
import '../../data/repositories/area_repository_impl.dart';
import '../../domain/repositories/area_repository.dart';
import '../../../shifts/data/repositories/shift_repository_impl.dart';
import '../../../shifts/domain/repositories/shift_repository.dart';

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(ref.watch(apiClientProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepositoryImpl(ref.watch(apiClientProvider));
});

class AreasState {
  const AreasState({
    this.areas = const [],
    this.openShiftCounts = const {},
    this.isLoading = true,
    this.isSaving = false,
    this.failure,
  });

  final List<Area> areas;

  /// Jumlah shift terbuka per lahan; lahan dengan shift terbuka tidak boleh
  /// dinonaktifkan.
  final Map<int, int> openShiftCounts;
  final bool isLoading;
  final bool isSaving;
  final Failure? failure;

  int get activeCount => areas.where((a) => a.isActive).length;
  int get inactiveCount => areas.where((a) => !a.isActive).length;

  AreasState copyWith({
    List<Area>? areas,
    Map<int, int>? openShiftCounts,
    bool? isLoading,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AreasState(
      areas: areas ?? this.areas,
      openShiftCounts: openShiftCounts ?? this.openShiftCounts,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class AreasController extends Notifier<AreasState> {
  @override
  AreasState build() {
    Future.microtask(refresh);
    return const AreasState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final areas = await ref.read(areaRepositoryProvider).fetchAreas(
            includeInactive: true,
          );
      if (!ref.mounted) return;
      final shifts = await ref.read(shiftRepositoryProvider).fetchShifts(
            openOnly: true,
          );
      if (!ref.mounted) return;
      final counts = <int, int>{};
      for (final shift in shifts) {
        counts[shift.parkingAreaId] = (counts[shift.parkingAreaId] ?? 0) + 1;
      }
      state = state.copyWith(
        areas: areas,
        openShiftCounts: counts,
        isLoading: false,
      );
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  /// Menambah lahan baru; mengembalikan pesan galat atau `null` bila berhasil.
  Future<String?> create({required String code, required String name}) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(areaRepositoryProvider).create(code: code, name: name);
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  /// Mengubah nama lahan.
  Future<String?> rename(Area area, String name) async {
    if (name.trim().isEmpty || name.trim() == area.name) return null;
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(areaRepositoryProvider).update(area.id, name: name.trim());
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  /// Mengaktifkan/menonaktifkan lahan.
  ///
  /// Menolak penonaktifan bila masih ada shift terbuka: aturan ini juga
  /// dijaga backend, tetapi pesannya lebih jelas bila dicek lebih dulu.
  Future<String?> toggleActive(Area area) async {
    final openShifts = state.openShiftCounts[area.id] ?? 0;
    if (area.isActive && openShifts > 0) {
      return 'Tutup $openShifts shift terbuka di lahan ini terlebih dahulu.';
    }

    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref
          .read(areaRepositoryProvider)
          .update(area.id, isActive: !area.isActive);
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final areasControllerProvider =
    NotifierProvider<AreasController, AreasState>(AreasController.new);
