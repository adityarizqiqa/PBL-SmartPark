/// Tab status pada daftar riwayat.
enum HistoryStatusFilter {
  all('Semua'),
  matched('Sesuai'),
  manualVerified('Verifikasi Manual');

  const HistoryStatusFilter(this.label);

  final String label;

  /// Status backend yang lolos saringan ini; `null` berarti semua.
  String? get status => switch (this) {
        HistoryStatusFilter.all => null,
        HistoryStatusFilter.matched => 'matched',
        HistoryStatusFilter.manualVerified => 'manual_verified',
      };
}

/// Periode ringkas yang tersedia di layar.
enum HistoryPeriod {
  today('Hari Ini'),
  yesterday('Kemarin'),
  custom('Pilih Tanggal');

  const HistoryPeriod(this.label);

  final String label;
}
