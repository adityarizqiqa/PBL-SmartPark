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
final leaveShiftActionProvider = Provider<Future<void> Function(String)>((ref) {
  return (note) async {
    try {
      await ref.read(authRepositoryProvider).leaveShift(note: note);
    } on Failure {
      // Sama seperti keluar: kegagalan server tidak menahan pengguna.
    }
    ref.read(sessionStoreProvider).clear();
  };
});

/// `true` bila belum ada token sama sekali.
final hasSessionProvider = Provider<bool>((ref) {
  final store = ref.watch(sessionStoreProvider);
  return store.hasShift || store.hasOfficerSession;
});

/// Alias agar layar tidak mengimpor kelas penyimpanan langsung.
typedef SessionSnapshot = SessionStore;
