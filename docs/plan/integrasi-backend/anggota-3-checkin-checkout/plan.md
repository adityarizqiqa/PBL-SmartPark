# Anggota 3 — Check-In & Check-Out

> Bergantung pada fondasi `../anggota-1-fondasi-api`.
> Baca `../master-plan.md` bagian 2 dan 3.

## Tujuan
Menghubungkan alur check-in dan check-out ke backend, termasuk pencarian sesi
berlapis (plat persis → plat mirip → NIM) dan verifikasi manual.

## Berkas yang disentuh
- `mobile/lib/screens/checkin_screen.dart`
- `mobile/lib/screens/checkout_screen.dart`

## Tugas

### 1. `checkin_screen.dart`
- Alur 3 langkah (Scan KTM → Scan Plat → Konfirmasi) tetap sebagai tampilan.
- **Biarkan statis** animasi/visual pemindai (viewfinder, laser, tombol senter,
  kartu KTM contoh) — kamera/QR tidak ada di backend.
- Ganti NIM `244107020204` dan plat `N 1234 ABC` dengan input pengguna.
- Kirim `POST /api/sessions/check-in` sebagai **multipart**:
  - `nim`, `plate`, `client_request_id` (opsional), `photo` (opsional).
  - Pakai `ApiClient.postMultipart`.
- Tangani galat:
  - `409` (`duplicate_active_session`) → pesan "NIM/plat sudah punya sesi
    aktif", tidak lanjut ke sukses.
  - `422` validasi NIM/plat.
- Setelah sukses: tampilkan data sesi asli (waktu masuk dari respons), bukan
  `_scanTime` hardcoded.
- Sediakan tombol aksi `POST /api/sessions/{id}/void` (batalkan check-in salah)
  bila layar memang menyediakannya.

### 2. `checkout_screen.dart`
- Ganti `_checkOutPlateNormal`, `_checkOutPlateMismatch`, `_sessionId`,
  `_duration`, dan data contoh lain dengan data asli.
- **Biarkan statis** foto plat contoh (`assets/foto-plat-checkin.png`,
  `assets/foto-plat-checkout.png`) dan baris tarif "Rp 0 (Gratis)" — belum ada
  di backend.
- Langkah cari sesi: `GET /api/sessions/lookup?plate=<scan>&nim=<opsional>`.
  - `plate_exact` → langsung tampilkan `session`.
  - `plate_similar` → tampilkan `candidates[]` untuk dipilih petugas.
  - `nim_fallback` → sesi ketemu lewat NIM.
  - `null` → pesan "sesi tidak ditemukan".
- Tampilkan perbandingan plat check-in (`session.plate_in`) vs plat keluar.
- Tombol konfirmasi → `POST /api/sessions/{id}/check-out` (multipart):
  - `status=matched` bila plat sama.
  - `status=manual_verified` + `note` (wajib) bila ada selisih.
- Tombol tolak → `POST /api/sessions/{id}/reject` `{note}` (sesi tetap aktif).
- Tampilkan durasi dari `duration_minutes` (sesi aktif) atau hitung dari waktu
  pada riwayat; jangan pakai `_duration` hardcoded.
- Sediakan tombol aksi `POST /api/sessions/{id}/void` (batalkan check-in salah)
  bila layar memang menyediakannya.

## Kriteria selesai
- Check-in menolak duplikat dengan pesan benar dan membuat baris di database.
- Check-out mencari sesi asli, menutup dengan status tepat, dan mewajibkan
  catatan pada verifikasi manual.
- Skenario plat mirip (satu karakter beda) benar-benar muncul sebagai kandidat.
- `flutter analyze` bersih.
