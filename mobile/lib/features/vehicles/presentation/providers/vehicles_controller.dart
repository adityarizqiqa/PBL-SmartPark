import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/failures/failure.dart';
import '../../data/repositories/vehicle_repository_impl.dart';
import '../../domain/entities/active_vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import '../../domain/usecases/get_active_vehicles.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepositoryImpl(ref.watch(apiClientProvider));
});

final getActiveVehiclesProvider = Provider<GetActiveVehicles>((ref) {
  return GetActiveVehicles(ref.watch(vehicleRepositoryProvider));
});

class VehiclesState {
  const VehiclesState({
    this.all = const [],
    this.query = '',
    this.isLoading = true,
    this.failure,
  });

  final List<ActiveVehicle> all;
  final String query;
  final bool isLoading;
  final Failure? failure;

  /// Hasil saring di sisi klien: daftar aktif biasanya muat di satu layar.
  List<ActiveVehicle> get visible {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return all;
    return all.where((vehicle) {
      return vehicle.nim.toLowerCase().contains(needle) ||
          vehicle.plateIn.toLowerCase().contains(needle) ||
          vehicle.areaName.toLowerCase().contains(needle) ||
          vehicle.checkedInBy.toLowerCase().contains(needle);
    }).toList();
  }

  VehiclesState copyWith({
    List<ActiveVehicle>? all,
    String? query,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return VehiclesState(
      all: all ?? this.all,
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class VehiclesController extends Notifier<VehiclesState> {
  @override
  VehiclesState build() {
    Future.microtask(refresh);
    return const VehiclesState();
  }

  void search(String query) {
    state = state.copyWith(query: query);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final vehicles = await ref.read(getActiveVehiclesProvider)();
      if (!ref.mounted) return;
      state = state.copyWith(all: vehicles, isLoading: false);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }
}

final vehiclesControllerProvider =
    NotifierProvider<VehiclesController, VehiclesState>(VehiclesController.new);
