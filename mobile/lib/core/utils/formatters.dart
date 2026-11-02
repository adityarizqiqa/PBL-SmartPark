/// Pemformat tanggal dan durasi yang dipakai lintas fitur.
///
/// Semua fungsi murni dan tidak bergantung pada `BuildContext`, sehingga bisa
/// dipakai di lapisan domain maupun widget dan mudah diuji.
class Formatters {
  const Formatters._();

  /// `14:05 WIB`
  static String time(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)} WIB';
  }

  /// `14:05` — tanpa zona, untuk rentang waktu berdampingan.
  static String clock(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  /// `08/10/2026 14:05 WIB`
  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} '
        '${_two(local.hour)}:${_two(local.minute)} WIB';
  }

  /// `Rab, 08 Okt 2026`
  static String dayDate(DateTime value) {
    final local = value.toLocal();
    return '${_shortDays[local.weekday - 1]}, ${_two(local.day)} '
        '${_shortMonths[local.month - 1]} ${local.year}';
  }

  /// `2j 05m` — durasi parkir dari jumlah menit.
  static String duration(int minutes) {
    final safe = minutes < 0 ? 0 : minutes;
    return '${safe ~/ 60}j ${_two(safe % 60)}m';
  }

  /// Durasi antara dua waktu; `null` pada [end] dihitung sampai sekarang.
  static String elapsed(DateTime start, [DateTime? end]) =>
      duration((end ?? DateTime.now()).difference(start).inMinutes);

  static String _two(int value) => value.toString().padLeft(2, '0');

  static const List<String> _shortDays = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  static const List<String> _shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
}
