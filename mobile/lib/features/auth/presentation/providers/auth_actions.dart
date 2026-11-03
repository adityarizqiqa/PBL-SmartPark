import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/session/officer_identity.dart';
import '../../../../core/di/providers.dart';
import 'login_controller.dart';

/// Menandai identitas sesi sebagai keluar agar layar yang masih menonton
/// ulang ke keadaan belum-masuk, sekaligus mereset formulir login agar sesi
/// berikutnya (mis. POS bersama) tidak terisi pilihan petugas sebelumnya.
///
/// HANYA state sesi/formulir yang dibuang di sini: controller data (beranda,
/// kendaraan, riwayat, konsol SPV) mengambil data langsung di `build()`,
/// sehingga invalidate tanpa sesi aktif justru meracuni state dengan galat
/// 401 untuk login berikutnya. Data basi milik sesi lama dibuang lewat
/// [resetSessionScopedState] tepat setelah login berikutnya berhasil.
void _resetIdentityOnly(Ref ref) {
  ref.invalidate(officerIdentityProvider);
  ref.invalidate(hasSessionProvider);
  ref.invalidate(loginControllerProvider);
}

/// Keluar dari sesi: memanggil endpoint lalu membersihkan token lokal.
///
/// Dipakai layar mana pun yang menampilkan tombol keluar, sehingga tidak ada
/// salinan logika `leave`/`sign-out` di tiap layar.
final signOutActionProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Failure {
      // Sesi lokal tetap dibuang meski server tidak terjangkau.
    }
    ref.read(sessionStoreProvider).clear();
    _resetIdentityOnly(ref);
  };
});

/// Mengakhiri penugasan jaga lalu membersihkan sesi.
 ///
/// Mengembalikan `null` bila aman keluar (server tutup shift, atau sesi
/// sudah mati di server). Mengembalikan [Failure] bila keadaan server tidak
/// pasti (jaringan/timeout/kesalahan server): pemanggil WAJIB menahan
/// pengguna di layar dan menampilkan galat, bukan membersihkan sesi lokal.
/// Membersihkan sesi lokal saat gagal membuat shift tetap terbuka di server
/// sehingga petugas terkunci ("masih bertugas di shift lain") saat masuk lagi.
final leaveShiftActionProvider =
    Provider<Future<Failure?> Function(String)>((ref) {
   return (note) async {
     try {
       await ref.read(authRepositoryProvider).leaveShift(note: note);
      ref.read(sessionStoreProvider).clear();
      _resetIdentityOnly(ref);
      return null;
     } on Failure catch (failure) {
      if (failure is UnauthorizedFailure ||
          failure is NotFoundFailure ||
          failure is ConflictFailure) {
        // Token/sesi sudah mati di server (mis. shift ditutup paksa
        // pengawas): tidak ada yang perlu ditutup, aman keluar lokal.
        ref.read(sessionStoreProvider).clear();
        _resetIdentityOnly(ref);
        return null;
      }
      return failure;
     }
   };
 });


