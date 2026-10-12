# Anggota 5 — Konsol SPV

> Bergantung pada fondasi `../anggota-1-fondasi-api`.
> Baca `../master-plan.md` bagian 2 dan 3.
> Semua endpoint di sini memakai header `X-Officer-Token` dan hanya untuk SPV.

## Tujuan
Menghubungkan konsol pengawas (SPV) ke backend: beranda ringkas, kelola lahan,
kelola petugas, dan kelola shift.

> Elemen tampilan yang tidak punya padanan di backend (mis. kartu statistik
> statis, bagan) **dibiarkan statis** seperti sekarang — lihat
> `../master-plan.md` bagian 6.

## Berkas yang disentuh
- `mobile/lib/screens/beranda_spv_screen.dart`
- `mobile/lib/screens/kelola_lahan_screen.dart`
- `mobile/lib/screens/kelola_petugas_screen.dart`
- `mobile/lib/screens/kelola_shift_screen.dart`

## Tugas

### 1. `beranda_spv_screen.dart`
- Ganti statistik konsol statis dengan `GET /api/sessions/dashboard`.
- Ambil nama SPV dari `SessionStore`.
- Logout → `POST /api/auth/sign-out`, lalu `SessionStore.clear()`.

### 2. `kelola_lahan_screen.dart`
- Daftar: `GET /api/areas?include_inactive=true`.
- Tambah: `POST /api/areas` `{code, name}` → tangani `409` (kode duplikat).
- Ubah: `PATCH /api/areas/{id}` `{name?, is_active?}`.
- Muat ulang daftar setelah tiap perubahan.

### 3. `kelola_petugas_screen.dart`
- Daftar: `GET /api/officers?include_inactive=true`.
- Tambah: `POST /api/officers`
  `{employee_no?, name, phone?, role, password}` → tangani `409` (NIP
  duplikat) dan validasi password (min 6).
- Ubah: `PATCH /api/officers/{id}` (termasuk `is_active`, `role`, `password`).
- Tampilkan badge peran (officer/SPV) dari `role`; jangan hardcode.

### 4. `kelola_shift_screen.dart`
- Daftar: `GET /api/shifts` (opsional `area_id`, `open_only`).
- Buka shift: `POST /api/shifts/open` `{parking_area_id, note?}`.
- Tutup paksa: `POST /api/shifts/{id}/close` `{note?}`.
- Tampilkan daftar penugasan (`assignments[]`) per shift: nama petugas,
  waktu bergabung, waktu keluar.

## Kriteria selesai
- CRUD lahan dan petugas benar-benar menulis ke database.
- Buka/tutup shift memengaruhi data di endpoint sesi.
- Hanya SPV yang bisa mengakses; percobaan non-SPV tampil pesan wewenang.
- `flutter analyze` bersih.
