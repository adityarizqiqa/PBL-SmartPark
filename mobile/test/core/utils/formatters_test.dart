import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/formatters.dart';

void main() {
  test('jam ditampilkan dalam waktu lokal dengan label WIB', () {
    final value = DateTime(2026, 10, 8, 14, 5);
    expect(Formatters.time(value), '14:05 WIB');
    expect(Formatters.clock(value), '14:05');
  });

  test('tanggal lengkap memakai urutan hari/bulan/tahun', () {
    expect(
      Formatters.dateTime(DateTime(2026, 10, 8, 14, 5)),
      '08/10/2026 14:05 WIB',
    );
    expect(Formatters.dayDate(DateTime(2026, 10, 8)), 'Kam, 08 Okt 2026');
  });

  test('durasi negatif dijepit ke nol', () {
    expect(Formatters.duration(-5), '0j 00m');
    expect(Formatters.duration(125), '2j 05m');
    expect(Formatters.duration(59), '0j 59m');
  });

  test('durasi berjalan dihitung sampai sekarang bila akhir kosong', () {
    final start = DateTime.now().subtract(const Duration(minutes: 90));
    expect(Formatters.elapsed(start), '1j 30m');
  });
}
