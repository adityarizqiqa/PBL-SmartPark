import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/di/providers.dart';
import '../../../../../core/entities/officer.dart';
import '../../../../../core/failures/failure.dart';
import '../../data/repositories/officer_repository_impl.dart';
import '../../domain/repositories/officer_repository.dart';

final officerRepositoryProvider = Provider<OfficerRepository>((ref) {
  return OfficerRepositoryImpl(ref.watch(apiClientProvider));
});

class OfficersState {
  const OfficersState({
    this.officers = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.failure,
  });

  final List<Officer> officers;
  final bool isLoading;
  final bool isSaving;
  final Failure? failure;

  int get activeCount => officers.where((o) => o.isActive).length;
  int get missingPasswordCount =>
      officers.where((o) => !o.hasPassword).length;

  OfficersState copyWith({
    List<Officer>? officers,
    bool? isLoading,
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return OfficersState(
      officers: officers ?? this.officers,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }
}

class OfficersController extends Notifier<OfficersState> {
  @override
  OfficersState build() {
    Future.microtask(refresh);
    return const OfficersState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final officers = await ref.read(officerRepositoryProvider).fetchOfficers(
            includeInactive: true,
          );
      if (!ref.mounted) return;
      state = state.copyWith(officers: officers, isLoading: false);
    } on Failure catch (failure) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<String?> create({
    required String name,
    required String password,
    required String role,
    String? employeeNo,
    String? phone,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(officerRepositoryProvider).create(
            name: name,
            password: password,
            role: role,
            employeeNo: employeeNo,
            phone: phone,
          );
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<String?> setPassword(Officer officer, String password) async {
    if (password.length < 6) return 'Password minimal 6 karakter.';
    return _update(officer.id, password: password);
  }

  Future<String?> toggleActive(Officer officer) =>
      _update(officer.id, isActive: !officer.isActive);

  /// Petugas gerbang ↔ pengawas.
  Future<String?> changeRole(Officer officer) =>
      _update(officer.id, role: officer.isSupervisor ? 'officer' : 'spv');

  Future<String?> _update(
    int id, {
    String? password,
    bool? isActive,
    String? role,
  }) async {
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      await ref.read(officerRepositoryProvider).update(
            id,
            password: password,
            isActive: isActive,
            role: role,
          );
      await refresh();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } finally {
      if (ref.mounted) state = state.copyWith(isSaving: false);
    }
  }
}

final officersControllerProvider =
    NotifierProvider<OfficersController, OfficersState>(OfficersController.new);
