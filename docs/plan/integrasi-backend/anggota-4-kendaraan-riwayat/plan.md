# Anggota 4 — Kendaraan & Riwayat

> Bergantung pada fondasi `../anggota-1-fondasi-api`.
> Baca `../master-plan.md` bagian 2 dan 3.

## Tujuan
Menampilkan daftar kendaraan yang masih parkir dan riwayat sesi dari backend,
lengkap dengan pencarian dan paginasi.

> Elemen tampilan yang tidak punya padanan di backend (mis. filter/tab atau
> ringkasan statis) **dibiarkan statis** seperti sekarang — lihat
> `../master-plan.md` bagian 6.

## Berkas yang disentuh
- `mobile/lib/screens/kendaraan_screen.dart`
- `mobile/lib/screens/riwayat_screen.dart`

## Tugas

### 1. `kendaraan_screen.dart`
- Ganti daftar kendaraan statis dengan `GET /api/sessions/active`.
- Pakai model `ActiveSession`:
  - plat (`plate_in`), NIM, waktu masuk (`checked_in_at`),
    durasi (`duration_minutes`), petugas (`checked_in_by`), lahan (`area_name`).
- Format durasi dari `duration_minutes` (mis. "3j 24m").
- Tambah `RefreshIndicator`.
- Empty state: "Tidak ada kendaraan yang sedang parkir".
- Bila ada tombol aksi per baris, arahkan ke layar check-out dengan membawa
  sesi terpilih (koordinasi dengan Anggota 3).

### 2. `riwayat_screen.dart`
- Ganti daftar riwayat statis dengan `GET /api/sessions/history`.
- Pakai model `HistoryItem`: `nim, plate_in, plate_out, checked_in_at,
  checked_out_at, status, verification_note`.
- Pencarian: kirim parameter `q` (NIM atau plat) ke endpoint.
- Paginasi: pakai `limit`/`offset`; ambil total dari
  `GET /api/sessions/history/meta` (`PageMeta`).
- Tampilkan status: `matched` (Sesuai) vs `manual_verified` (Verifikasi Manual),
  dan catatan bila ada.
- Tangani daftar kosong dan galat dengan rapi.

## Kriteria selesai
- Daftar kendaraan aktif dan riwayat sesuai isi database.
- Pencarian dan paginasi benar-benar memanggil backend (bukan filter lokal).
- `flutter analyze` bersih.
