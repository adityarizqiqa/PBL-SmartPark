import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/presentation/providers/dashboard_controller.dart';
import '../../features/history/presentation/providers/history_controller.dart';
import '../../features/vehicles/presentation/providers/vehicles_controller.dart';

/// Memicu invalidasi / penyegaran ulang seluruh provider yang terikat
/// dengan sesi operasional pos (kendaraan aktif, statistik beranda, dan riwayat).
void resetSessionScopedState(dynamic ref) {
  if (ref is WidgetRef) {
    ref.invalidate(vehiclesControllerProvider);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(historyControllerProvider);
  } else if (ref is Ref) {
    ref.invalidate(vehiclesControllerProvider);
    ref.invalidate(dashboardControllerProvider);
    ref.invalidate(historyControllerProvider);
  } else {
    // Dynamic fallback for any ProviderContainer or mock ref
    try {
      (ref as dynamic).invalidate(vehiclesControllerProvider);
      (ref as dynamic).invalidate(dashboardControllerProvider);
      (ref as dynamic).invalidate(historyControllerProvider);
    } catch (_) {
      // Ignored if ref does not support invalidate
    }
  }
}

