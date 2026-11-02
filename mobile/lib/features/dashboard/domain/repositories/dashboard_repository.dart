import '../../../../core/entities/parking_session.dart';
import '../entities/dashboard.dart';

/// Kontrak ringkasan beranda petugas.
abstract class DashboardRepository {
  /// `GET /api/sessions/dashboard` — jumlah sesi dan aktivitas terbaru.
  Future<Dashboard> fetch();
}

/// Ringkasan operasional yang sudah siap tampil.
///
/// `capacity` bukan bagian dari respons backend: nilainya berasal dari
/// konfigurasi lahan sampai ada endpoint kapasitas.
class HomeSummary {
  const HomeSummary({
    required this.dashboard,
    required this.capacity,
  });

  final Dashboard dashboard;
  final int capacity;

  int get parked => dashboard.activeNow;
  int get checkedInToday => dashboard.checkedInToday;
  int get checkedOutToday => dashboard.checkedOutToday;
  List<SessionDetail> get recent => dashboard.recent;

  double get occupancy {
    if (capacity <= 0) return 0;
    return (parked / capacity).clamp(0.0, 1.0);
  }

  int get occupancyPercent => (occupancy * 100).round();
}
