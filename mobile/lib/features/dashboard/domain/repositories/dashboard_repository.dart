import '../entities/dashboard.dart';

/// Kontrak ringkasan beranda petugas.
abstract class DashboardRepository {
  /// `GET /api/sessions/dashboard` — jumlah sesi dan aktivitas terbaru.
  Future<Dashboard> fetch();
}
