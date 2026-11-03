/// Aturan validasi masukan yang dipakai bersama lapisan domain dan form.
///
/// Fungsi mengembalikan pesan galat siap tampil, atau `null` bila lolos —
/// bentuk yang langsung diterima `TextFormField.validator`. Aturan di sini
/// mencerminkan `backend/app/services/plate.py` agar masukan ditolak di klien
/// sebelum melakukan perjalanan ke server.
class Validators {
  const Validators._();

  static const int nimMaxLength = 32;
  static const int plateMaxLength = 12;

  /// NIM hanya berisi angka; panjangnya mengikuti batas kolom database.
  static String? nim(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'NIM wajib diisi.';
    if (!RegExp(r'^\d+$').hasMatch(text)) return 'NIM hanya boleh berisi angka.';
    if (text.length > nimMaxLength) {
      return 'NIM maksimal $nimMaxLength angka.';
    }
    return null;
  }

  /// Plat dinormalisasi dulu: kapital, hanya `A-Z0-9`, maksimal 12 karakter.
  static String? plate(String? value) {
    final text = normalizePlate(value);
    if (text.isEmpty) return 'Nomor plat wajib diisi.';
    return null;
  }

  static String? required(String? value, {String label = 'Kolom ini'}) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi.';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi wajib diisi.';
    if (value.length < 6) return 'Kata sandi minimal 6 karakter.';
    return null;
  }

  /// `" b 1234-xyz "` → `B1234XYZ`, dipotong pada [plateMaxLength].
  static String normalizePlate(String? value) {
    final cleaned = (value ?? '').toUpperCase().replaceAll(
          RegExp(r'[^A-Z0-9]'),
          '',
        );
    return cleaned.length > plateMaxLength
        ? cleaned.substring(0, plateMaxLength)
        : cleaned;
  }

  /// Kode/NIP: rapikan spasi lalu kapitalkan, tanpa membuang karakter lain.
  static String normalizeCode(String? value) =>
      (value ?? '').trim().toUpperCase();
}
