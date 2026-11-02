import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../session/session_store.dart';

/// Akar komposisi aplikasi.
///
/// Instance jangka panjang dibuat di sini; layar tidak mengonstruksi
/// dependensinya sendiri. Pengujian menimpa provider ini lewat
/// `ProviderScope(overrides: [...])`.
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokens: ref.watch(sessionStoreProvider));
});
