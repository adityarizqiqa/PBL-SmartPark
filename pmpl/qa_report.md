# Laporan QA SmartPark

## Ruang lingkup

- Branch aplikasi: `eeswepe`.
- Aplikasi: Flutter Android, package ID `com.example.mobile`.
- Device: `emulator-5554`.
- Backend remote: `http://4.213.226.116:9876`.
- Endpoint health terverifikasi `HTTP 200` dengan respons `{"status":"ok","version":"0.1.0"}`.
- Acuan test case: Google Sheets, 113 test case pada `Master Test Cases`.
- Pengujian kamera sengaja dilewati sesuai instruksi pengguna.
- Tidak ada perubahan pada source code `mobile/`.
- Tidak ada staging, commit, atau push.

## Hasil yang benar-benar teramati

| Test case | Status | Hasil aktual | Bukti |
|---|---|---|---|
| TC-01-01 | PASS dengan adaptasi kontrak aplikasi | Login menggunakan `Budi Santoso` / `budi1234` pada `POS-FT` berhasil dan membuka `Beranda Petugas`. Aplikasi menampilkan status backend `Terhubung`. | Screenshot login sebelumnya tersedia di Google Drive: `https://drive.google.com/file/d/1x4IQfF_GbKhtCr_Hv-MEYQmrbgiXOtB1/view?usp=drivesdk` |
| TC-01-04 | PASS | Submit tanpa password menampilkan `Kata sandi wajib diisi.` | Screenshot: https://drive.google.com/file/d/18xoSk4lLCxzS7hP4KVlDm5nm8lQ2Oaqt/view?usp=drivesdk |
| TC-02-01 | PASS | `Keluar Sesi` membuka konfirmasi; memilih `Keluar` mengembalikan aplikasi ke halaman login. | Observasi Maestro. |
| TC-06-01 | PASS | Beranda menampilkan `Pos Parkir Fakultas Teknik` dan identitas petugas. | Observasi Maestro. |
| TC-06-02 | PASS | Beranda menampilkan `Sistem Online` dan `Terhubung`. | Observasi Maestro. |
| TC-06-06 | PASS | Tombol keluar tersedia dan alurnya berhasil digunakan. | Observasi Maestro. |

Catatan: `TC-01-01` pada spesifikasi memakai kode lahan/password, sedangkan aplikasi branch `eeswepe` memakai pilihan nama petugas, password, dan lahan. Hasil PASS mengikuti kontrak UI aplikasi yang benar-benar terpasang.

## Test case kamera yang dilewati

Test case berikut diberi status `SKIPPED_CAMERA` di Google Sheets dan tidak dijalankan:

- **Scan QR KTM:** `TC-07-01` s.d. `TC-07-07`.
- **Scan Plat (ML):** `TC-09-01` s.d. `TC-09-08`.
- **Konfirmasi Check-In:** `TC-10-01`, `TC-10-02`, `TC-10-03`, `TC-10-04`, `TC-10-05`, `TC-10-06`, `TC-10-07`.
- **Proses Check-Out:** `TC-11-01`, `TC-11-02`, `TC-11-03`, `TC-11-04`, `TC-11-05`, `TC-11-06`.
- **Pencocokan Plat:** `TC-13-01` s.d. `TC-13-07`.
- **Verifikasi Manual:** `TC-14-01` s.d. `TC-14-06`.

Alasannya: test case membutuhkan kamera, KTM/plat fisik, foto, OCR/ALPR, kondisi pencahayaan, atau verifikasi visual. Pengujian tersebut diserahkan kepada tim secara manual.

## Test case yang belum dapat diselesaikan dengan Maestro

### Keamanan, perangkat, dan jaringan

- `TC-01-05`: perlu inspeksi trafik HTTPS dan log, bukan UI saja. Selain itu konfigurasi yang dibaca memakai HTTP remote.
- `TC-01-06`: membutuhkan dua device dan sesi bersamaan.
- `TC-02-04`: perlu inspeksi secure/local storage.
- `TC-02-05`, `TC-05-03`, `TC-18-06`, `TC-18-09`: membutuhkan perubahan konektivitas dan validasi perilaku backend.
- `TC-03-01`: perlu inspeksi secure storage.
- `TC-03-03`, `TC-03-04`, `TC-03-05`, `TC-18-07`: membutuhkan token kedaluwarsa atau manipulasi waktu/server clock.
- `TC-04-03`, `TC-04-05`: membutuhkan request API langsung atau proxy untuk menguji authorization/IDOR.
- `TC-05-04`, `TC-05-06`: pengujian rate limit dan brute force tidak dijalankan agar tidak mengunci akun atau membebani backend remote.
- `TC-15-05`: membutuhkan dua request bersamaan dan verifikasi database.

### Dataset dan state backend

- `TC-02-02`, `TC-02-03`: membutuhkan workflow check-in/check-out yang sengaja dibiarkan aktif.
- `TC-04-01` s.d. `TC-04-04`: membutuhkan dataset lintas lahan dan verifikasi isolasi server.
- `TC-05-02`, `TC-05-05`: membutuhkan akun nonaktif atau state percobaan login tertentu.
- `TC-06-03` s.d. `TC-06-05`: membutuhkan alur/data transaksi; `TC-06-03` juga bergantung pada kamera.
- `TC-08-01` s.d. `TC-08-06`: membutuhkan alur input NIM yang pada aplikasi berjalan setelah alur kamera/check-in tersedia; belum dijalankan.
- `TC-12-01` s.d. `TC-12-05`: membutuhkan dataset sesi aktif dan fallback pencarian yang terkontrol.
- `TC-15-01` s.d. `TC-15-04`, `TC-15-06`: membutuhkan data transaksi aktif/closed dan state lintas lahan.
- `TC-16-01` s.d. `TC-16-06`: membutuhkan dataset kendaraan parkir yang terkontrol.
- `TC-17-01` s.d. `TC-17-07`: membutuhkan dataset riwayat dan validasi ekspor.
- `TC-18-04`, `TC-18-05`, `TC-18-08`: membutuhkan pemicu kendala yang terkontrol.

## Risiko dan catatan

1. Spesifikasi Google Sheets belum sepenuhnya mengikuti kontrak aplikasi branch `eeswepe`; spesifikasi login menyebut kode lahan, sementara UI memakai nama petugas.
2. Backend remote adalah environment bersama. Pengujian destructive, brute force, reset database, dan race condition tidak dilakukan.
3. Screenshot lokal di `pmpl/Maestro/` dihapus saat reset sesuai instruksi pengguna. Satu screenshot login sudah sempat diunggah ke Google Drive dan tercantum di atas.
4. Google Docs tidak diubah. Hasil ringkas dan status per test case ditulis ke Google Sheets.
