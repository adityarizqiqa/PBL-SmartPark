# Anggota 2 — Auth & Beranda Petugas

> Bergantung pada fondasi `../anggota-1-fondasi-api`.
> Baca `../master-plan.md` bagian 2 dan 3.

## Tujuan
Mengganti daftar petugas/lahan statis dengan data backend, menegakkan login
nyata, dan menampilkan beranda petugas dari data dashboard.

## Berkas yang disentuh
- `mobile/lib/screens/login_screen.dart`
- `mobile/lib/screens/beranda_screen.dart`

## Tugas

### 1. `login_screen.dart`
- `initState`: ambil `GET /api/officers` dan `GET /api/areas` (ganti list
  hardcoded `_officers` dan `_parkingLots`). Tampilkan loading + galat.
- Hapus model `OfficerItem` lokal, pakai `models/Officer`.
- Petakan pilihan lahan ke `Area.id` (dropdown pakai nama + kode).
- Tombol "Mulai Bertugas":
  - Petugas gerbang → `POST /api/shifts/join`
    `{officer_id, password, parking_area_id}` → simpan token + assignment +
    shift + area ke `SessionStore`, navigasi ke `BerandaScreen`.
  - SPV → `POST /api/auth/sign-in` `{officer_id, password}` → simpan
    officer token, navigasi ke `BerandaSpvScreen`.
- Tangani galat: password salah (`401`), lahan tidak dipilih (`422`).
- Hapus `Future.delayed` tiruan; pakai state loading asli.

### 2. `beranda_screen.dart`
- Ganti konstanta `_currentParked`, `_todayCheckIn`, `_todayCheckOut`, dan
  `_activities` dengan `GET /api/sessions/dashboard`.
  - `active_now` → Sedang Parkir
  - `checked_in_today` → Check-In Hari Ini
  - `checked_out_today` → Check-Out Hari Ini
  - `recent[]` → Aktivitas Terakhir
- **Biarkan statis** (belum ada di backend, jangan diubah/dikosongkan):
  kartu "Kapasitas Lahan" (`_maxCapacity`, progress bar), kartu
  "Perlu Verifikasi" (`_needVerification`), dan label "Shift 1 (Pagi)".
- Ambil nama petugas/lahan dari `SessionStore`, bukan default hardcoded.
- Logout → `POST /api/shifts/leave` (shift token), lalu `SessionStore.clear()`
  dan kembali ke login.
- Tambah `RefreshIndicator` untuk memuat ulang dashboard.
- Tangani galat token kadaluarsa (`401`/`AssignmentNotFound`) → arahkan login.

## Kriteria selesai
- Login petugas & SPV benar-benar memvalidasi password ke backend.
- Beranda menampilkan angka nyata dari database (uji dengan seed).
- Logout mematikan token di server.
- `flutter analyze` bersih.
