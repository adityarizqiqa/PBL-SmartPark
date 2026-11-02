import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/failures/failure.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    AuthRemoteDataSource(ref.watch(apiClientProvider)),
  );
});

final loadLoginOptionsProvider = Provider<LoadLoginOptions>((ref) {
  return LoadLoginOptions(ref.watch(authRepositoryProvider));
});

final signInProvider = Provider<SignIn>((ref) {
  return SignIn(ref.watch(authRepositoryProvider));
});

/// Keadaan formulir masuk.
class LoginState {
  const LoginState({
    this.options,
    this.selectedOfficer,
    this.selectedArea,
    this.isLoadingOptions = true,
    this.isSubmitting = false,
    this.optionsError,
    this.submitError,
  });

  final LoginOptions? options;
  final Officer? selectedOfficer;
  final Area? selectedArea;
  final bool isLoadingOptions;
  final bool isSubmitting;
  final String? optionsError;
  final Failure? submitError;

  List<Officer> get officers => options?.officers ?? const [];
  List<Area> get areas => options?.areas ?? const [];

  bool get canSubmit => !isLoadingOptions && !isSubmitting;

  LoginState copyWith({
    LoginOptions? options,
    Officer? selectedOfficer,
    Area? selectedArea,
    bool? isLoadingOptions,
    bool? isSubmitting,
    String? optionsError,
    Failure? submitError,
    bool clearOptionsError = false,
    bool clearSubmitError = false,
  }) {
    return LoginState(
      options: options ?? this.options,
      selectedOfficer: selectedOfficer ?? this.selectedOfficer,
      selectedArea: selectedArea ?? this.selectedArea,
      isLoadingOptions: isLoadingOptions ?? this.isLoadingOptions,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      optionsError: clearOptionsError ? null : optionsError ?? this.optionsError,
      submitError: clearSubmitError ? null : submitError ?? this.submitError,
    );
  }
}

/// Mengatur pemuatan pilihan, pemilihan petugas/lahan, dan proses masuk.
///
/// [loadOptions] dipanggil layar sekali saat dibuka; `build` hanya menyiapkan
/// keadaan awal agar tidak ada efek samping di dalam provider.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<void> loadOptions() async {
    state = state.copyWith(isLoadingOptions: true, clearOptionsError: true);
    try {
      final options = await ref.read(loadLoginOptionsProvider)();
      // Pilihan lama bisa basi (mis. habis logout): cocokkan ulang lewat id
      // dan pakai instance baru, karena Area/Officer membandingkan identitas.
      // Tanpa ini DropdownButtonFormField menerima initialValue yang tidak
      // ada di items lalu meledak saat rebuild.
      Officer? officer;
      final oldOfficer = state.selectedOfficer;
      if (oldOfficer != null) {
        for (final candidate in options.officers) {
          if (candidate.id == oldOfficer.id) {
            officer = candidate;
            break;
          }
        }
      }
      Area? area;
      final oldArea = state.selectedArea;
      if (oldArea != null) {
        for (final candidate in options.areas) {
          if (candidate.id == oldArea.id) {
            area = candidate;
            break;
          }
        }
      }
      state = state.copyWith(
        options: options,
        selectedOfficer:
            officer ?? (options.officers.isEmpty ? null : options.officers.first),
        selectedArea:
            area ?? (options.areas.isEmpty ? null : options.areas.first),
        isLoadingOptions: false,
      );
    } on Failure catch (failure) {
      state = state.copyWith(
        isLoadingOptions: false,
        optionsError: failure.message,
      );
    }
  }

  void selectOfficer(Officer officer) {
    state = state.copyWith(selectedOfficer: officer);
  }

  void selectArea(Area area) {
    state = state.copyWith(selectedArea: area);
  }

  /// Mengembalikan hasil masuk, atau `null` bila gagal (galat ada di state).
  Future<SignInResult?> submit({required String password}) async {
    final officer = state.selectedOfficer;
    if (officer == null) {
      state = state.copyWith(
        submitError: const ValidationFailure(
          'Pilih nama petugas terlebih dahulu.',
          field: 'officer',
        ),
      );
      return null;
    }

    final area = state.selectedArea;
    if (!officer.isSupervisor && area == null) {
      state = state.copyWith(
        submitError: const ValidationFailure(
          'Pilih lahan parkir terlebih dahulu.',
          field: 'area',
        ),
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final result = await ref.read(signInProvider)(
        officer: officer,
        password: password,
        area: area,
      );
      _applySession(result);
      state = state.copyWith(isSubmitting: false);
      return result;
    } on Failure catch (failure) {
      state = state.copyWith(isSubmitting: false, submitError: failure);
      return null;
    }
  }

  /// Menyimpan token ke sesi global agar `ApiClient` ikut mengirim header.
  void _applySession(SignInResult result) {
    final store = ref.read(sessionStoreProvider);
    switch (result) {
      case SupervisorSignedIn(:final session):
        store.setOfficerSession(
          token: session.token,
          id: session.officer.id,
          name: session.officer.name,
          userRole: session.officer.role,
        );
      case OfficerJoinedShift(:final login, :final officer):
        store.setShiftSession(login, userRole: officer.role);
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Failure {
      // Keluar tetap dilanjutkan; token lokal dibuang apa pun hasilnya.
    }
    ref.read(sessionStoreProvider).clear();
    state = const LoginState();
  }
}

final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
