# Daftar Bug Aplikasi Parkir (Belum Diperbaiki)

> Hasil observasi + pelacakan kode `mobile/lib`. Tidak ada kode yang diubah.

## 1. Badge "Perlu Verifikasi" statis — disarankan dihapus

- Lokasi: `lib/features/dashboard/presentation/widgets/operational_stats.dart:18-19,45`
- Bukti:
  ```dart
  /// Ambang "Perlu Verifikasi" belum punya endpoint; nilai tetap sampai ada.
  static const int needVerification = 3;
  ```
- Dampak: angka selalu `3` walau tidak ada sesi yang butuh verifikasi. Menyesatkan karena tidak merefleksikan data backend.
- Keputusan yang diminta: **hapus badge/kartu ini** sampai ada endpoint pendukung.

## 2. Scan QR KTM tiba-tiba tidak jalan

- Lokasi: `lib/features/session_ops/presentation/pages/check_in_page.dart:96-98,118-121,436-440,534-564`, `lib/features/session_ops/presentation/pages/check_in_step_ktm.dart:165-169`
- Bukti:
  - Controller dibuat dengan `autoStart: true`, callback `onDetect: _onQrDetect`.
  - `_onQrDetect` langsung `return` bila `_currentStep != CheckInStep.ktm` (`check_in_page.dart:535`), throttle 5 detik untuk kode yang sama (`:546-550`).
  - Saat pindah ke step plat: `_qrController.stop()` (`:436`); kembali ke KTM: `_qrController.start()` (`:440`) dengan `catchError((_) {})` yang menelan kegagalan start.
  - Tidak ada `errorBuilder` yang memulihkan scanner — error kamera hanya menampilkan kontainer gelap (`check_in_step_ktm.dart:169-173`).
- Kemungkinan penyebab (belum dipastikan, perlu reproduksi di perangkat):
  1. Controller gagal `start()` ulang setelah `stop()` dan errornya ditelan.
  2. Throttle `_lastQrCode` tidak di-reset saat kembali dari step plat (reset hanya ada di `_rescanQrNim`), sehingga QR yang sama diabaikan.
  3. Izin kamera dicabut / kamera dipakai halaman lain.

## 3. Data kendaraan masuk tidak muncul sebelum reload manual

- Lokasi: `lib/features/vehicles/presentation/providers/vehicles_controller.dart:59-64`, `lib/features/auth/presentation/providers/login_controller.dart:42-49`, `lib/core/widgets/app_entry.dart:165-183`
- Bukti:
  - `VehiclesController.build()` hanya memanggil `refresh()` sekali saat provider pertama dibuat (`Future.microtask(refresh)`).
  - `resetSessionScopedState` (dipanggil setelah login) memang invalidate `vehiclesControllerProvider`, tapi tidak ada invalidate/refresh setelah **check-in/check-out berhasil**.
  - `_checkOutPage` / `CheckInPage` dibuka via `_push` (route baru); tidak ada `onFinished` yang memicu `refresh()` saat kembali ke daftar.
- Dampak: kendaraan yang baru check-in tidak tampil di tab Kendaraan sampai user pull-to-refresh / pindah sesi.
- Catatan: pola yang sama berpotensi berlaku untuk tab Riwayat dan statistik Beranda (perlu dicek satu per satu).

## 4. Check-out: sesi tidak ada yang terbaca

### 4a. Dibuka dari Beranda selalu mulai kosong

- Lokasi: `lib/core/widgets/app_entry.dart:169-183`, `lib/features/session_ops/presentation/pages/check_out_page.dart:88-113`
- Bukti: `_checkOutPage()` tanpa `vehicle` mengirim `nim: ''` dan `checkInPlate: ''`. Di `initState`, `_session = null` dan auto-lookup hanya jalan bila `seedPlate/seedNim` tidak kosong (`:106-112`). Hasil: user harus ketik manual dan tekan Cari.
- Ini by-design untuk jalur "scan di pintu keluar", tapi membingungkan bila ekspektasinya sesi langsung terisi.

### 4b. Dibuka dari daftar Kendaraan tanpa `initialSession`

- Lokasi: `lib/core/widgets/app_entry.dart:185-186`, `lib/features/session_ops/presentation/pages/check_out_page.dart:93-99`
- Bukti: `_openCheckOutFor(vehicle)` hanya meneruskan `nim` + `checkInPlate` (string), bukan objek sesi. `initialSession` selalu `null`, jadi halaman tetap lewat jalur lookup ulang (`_performLookup`) alih-alih langsung memakai data kendaraan yang sudah ada.
- Dampak: satu request lookup tambahan; bila lookup gagal / token hilang, sesi "tidak terbaca" walau user mengetuk kendaraan dari daftar.

### 4c. Foto saat masuk belum tentu tampil di halaman check-out

- Lokasi: `lib/features/session_ops/presentation/pages/check_out_page.dart:279-289`, `lib/features/session_ops/presentation/pages/check_out_verification.dart:196-210`
- Bukti:
  ```dart
  if (session == null || session.plateInPhotoPath == null) return;
  ```
  Bila `plateInPhotoPath == null` (mis. check-in tanpa foto, atau backend tidak mengembalikan path), `_loadInPhoto()` berhenti dan panel "Foto Saat Masuk" hanya menampilkan ikon placeholder — tanpa pesan bahwa foto memang tidak ada.
- Perlu dipastikan: apakah check-in selalu mengirim foto (`photoPath` opsional di `session_repository.dart:11-13`), dan apakah backend selalu mengisi `plateInPhotoPath`.

## 5. Check-out belum dinamis: foto keluar & plat keluar harus mulai kosong

- Lokasi:
  - Foto keluar: `lib/features/session_ops/presentation/pages/check_out_verification.dart:331-359`, state `_outPhotoPath` di `check_out_page.dart:80`
  - Plat keluar: `lib/features/session_ops/presentation/pages/check_out_page.dart:89-91,124-125` (`_outPlateController = TextEditingController(text: widget.checkInPlate)`)
- Bukti:
  - Panel "Foto Saat Keluar" memang menampilkan placeholder "Ketuk untuk foto plat" bila `_outPhotoPath == null` — perilaku ini sudah benar, tapi diminta ditegaskan sebagai syarat.
  - Kolom plat keluar saat ini **di-prefill dengan plat check-in** (`text: widget.checkInPlate`). Akibatnya perbandingan `_isPlateMatched` (`:156-160`) langsung "Sesuai" sebelum user memindai/mengetik plat keluar yang sebenarnya.
- Yang diminta:
  1. Foto keluar: selalu mulai kosong (placeholder) setiap sesi baru; tampil hanya setelah user memotret.
  2. Plat keluar: selalu mulai kosong; perbandingan Sesuai/Manual hanya dihitung setelah ada input.
  3. Metadata sesi (NIM, plat check-in, waktu masuk, durasi) mengikuti sesi yang dipilih dari lookup, bukan nilai bawaan tombol yang menekan.
- Catatan: perubahan ini menyentuh `initState` + reset `_clearSessionState` (`check_out_page.dart:413-432`) — belum dikerjakan sesuai permintaan.
