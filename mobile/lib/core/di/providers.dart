import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/history/data/repositories/history_repository_impl.dart';
import '../../features/history/domain/repositories/history_repository.dart';
import '../../features/session_ops/data/repositories/session_repository_impl.dart';
import '../../features/session_ops/domain/repositories/session_repository.dart';
import '../../features/supervisor/areas/data/repositories/area_repository_impl.dart';
import '../../features/supervisor/areas/domain/repositories/area_repository.dart';
import '../../features/supervisor/officers/data/repositories/officer_repository_impl.dart';
import '../../features/supervisor/officers/domain/repositories/officer_repository.dart';
import '../../features/supervisor/shifts/data/repositories/shift_repository_impl.dart';
import '../../features/supervisor/shifts/domain/repositories/shift_repository.dart';
import '../../features/vehicles/data/repositories/vehicle_repository_impl.dart';
import '../../features/vehicles/domain/repositories/vehicle_repository.dart';

import '../alpr/plate_recognizer.dart';
import '../network/api_client.dart';
import '../session/session_store.dart';

/// Akar komposisi aplikasi.
///
/// Instance jangka panjang dibuat di sini; layar dan controller tidak
/// mengonstruksi dependensinya sendiri, melainkan menonton provider di bawah.
/// Pengujian menimpa provider ini lewat `ProviderScope(overrides: [...])`.
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokens: ref.watch(sessionStoreProvider));
});

/// Singleton deteksi+OCR plat (dimuat lazily saat pertama dipakai).
final plateRecognizerProvider = Provider<PlateRecognizer>((ref) {
  return PlateRecognizer();
});

// --- sumber data ------------------------------------------------------------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

// --- repositori -------------------------------------------------------------
//
// Di-deklarasikan terhadap interface domain; implementasi konkret hanya
// dipilih di sini sehingga lapisan presentation tidak pernah menyentuh
// lapisan `data` secara langsung.

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepositoryImpl(ref.watch(apiClientProvider));
});

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepositoryImpl(ref.watch(apiClientProvider));
});

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepositoryImpl(ref.watch(apiClientProvider));
});

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(ref.watch(apiClientProvider));
});

final officerRepositoryProvider = Provider<OfficerRepository>((ref) {
  return OfficerRepositoryImpl(ref.watch(apiClientProvider));
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepositoryImpl(ref.watch(apiClientProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(apiClientProvider));
});