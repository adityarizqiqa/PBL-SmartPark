import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';
import '../../../../core/failures/failure.dart';
import '../../../../core/session/officer_identity.dart';
import '../../../dashboard/presentation/providers/dashboard_controller.dart';
import '../../../history/presentation/providers/history_controller.dart';
import '../../../supervisor/areas/presentation/providers/areas_controller.dart';
import '../../../supervisor/home/presentation/providers/supervisor_home_controller.dart';
import '../../../supervisor/officers/presentation/providers/officers_controller.dart';
import '../../../supervisor/shifts/presentation/providers/shifts_controller.dart';
import '../../../vehicles/presentation/providers/vehicles_controller.dart';
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

/// `true` bila ada token sesi aktif.
final hasSessionProvider = Provider<bool>((ref) {
  final store = ref.watch(sessionStoreProvider);
  return store.hasShift || store.hasOfficerSession;
});

/// Membuang state milik sesi sebelumnya agar tidak terbaca pemakai berikutnya.
///
/// WAJIB dipanggil setelah sesi baru tersimpan (login berhasil): controller
/// berumur aplikasi dibangun ulang malas lalu mengambil ulang data dengan
/// token baru. JANGAN dipanggil saat logout — `build()` tiap controller
/// langsung mengambil data, sehingga invalidate tanpa sesi aktif hanya
/// meracuni state dengan galat 401 untuk login berikutnya.
void resetSessionScopedState(Ref ref) {
  ref.invalidate(officerIdentityProvider);
  ref.invalidate(hasSessionProvider);
  ref.invalidate(dashboardControllerProvider);
  ref.invalidate(vehiclesControllerProvider);
  ref.invalidate(historyControllerProvider);
  ref.invalidate(supervisorHomeControllerProvider);
  ref.invalidate(areasControllerProvider);
  ref.invalidate(shiftsControllerProvider);
  ref.invalidate(officersControllerProvider);
}

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
      resetSessionScopedState(ref);
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
}

final loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);
