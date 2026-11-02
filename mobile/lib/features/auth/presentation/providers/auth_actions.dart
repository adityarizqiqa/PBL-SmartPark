import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/failure.dart';
import '../../../../core/session/session_store.dart';
import '../../../../core/di/providers.dart';
import 'login_controller.dart';

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
      return null;
     } on Failure catch (failure) {
      if (failure is UnauthorizedFailure ||
          failure is NotFoundFailure ||
          failure is ConflictFailure) {
        // Token/sesi sudah mati di server (mis. shift ditutup paksa
        // pengawas): tidak ada yang perlu ditutup, aman keluar lokal.
        ref.read(sessionStoreProvider).clear();
        return null;
      }
      return failure;
     }
   };
 });

/// `true` bila belum ada token sama sekali.
final hasSessionProvider = Provider<bool>((ref) {
  final store = ref.watch(sessionStoreProvider);
  return store.hasShift || store.hasOfficerSession;
});

/// Alias agar layar tidak mengimpor kelas penyimpanan langsung.
typedef SessionSnapshot = SessionStore;
