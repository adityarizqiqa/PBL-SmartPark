# Master Plan — Integrasi Backend ↔ Mobile SmartPark

> Disusun dari keadaan repo saat ini (branch `main`, commit `fa0a06e`).
> Tujuan: mengganti seluruh data statis di aplikasi Flutter dengan data asli
> dari backend FastAPI.

---

## 1. Keadaan repo saat ini

**Backend** (`backend/`) — FastAPI + SQLAlchemy, SQLite, **sudah lengkap dan
jalan**. Menyediakan dua skema token:

- `X-Shift-Token` dari `POST /api/shifts/join` → operasi sesi parkir.
- `X-Officer-Token` dari `POST /api/auth/sign-in` → operasi pengelolaan (SPV).

**Mobile** (`mobile/`) — Flutter, **masih 100% statis**:

- Belum ada dependency `http` di `pubspec.yaml`.
- `AndroidManifest.xml` utama belum punya izin `INTERNET` (hanya manifest debug).
- Semua layar memakai data hardcoded (nama petugas, plat, NIM, statistik).
- Belum ada folder `api/`, `models/`, atau layer service apa pun.

**Titik sentuh mobile** (10 layar):

| Berkas | Baris | Isi statis utama |
| --- | --- | --- |
| `login_screen.dart` | 769 | daftar petugas + daftar lahan hardcoded |
| `beranda_screen.dart` | 1431 | statistik 428/500/852/424, 3 aktivitas contoh |
| `beranda_spv_screen.dart` | 563 | statistik konsol SPV |
| `checkin_screen.dart` | 2973 | NIM `244107020204`, plat `N 1234 ABC` |
| `checkout_screen.dart` | 1369 | plat masuk/keluar, sesi `PRK-240502-089` |
| `kendaraan_screen.dart` | 1359 | daftar kendaraan contoh |
| `riwayat_screen.dart` | 1534 | daftar riwayat contoh |
| `kelola_lahan_screen.dart` | 800 | daftar lahan contoh |
| `kelola_petugas_screen.dart` | 1060 | daftar petugas contoh |
| `kelola_shift_screen.dart` | 914 | daftar shift contoh |

---

## 2. Peta fitur → endpoint

| Layar mobile | Endpoint backend | Token |
| --- | --- | --- |
| Login — daftar nama | `GET /api/officers` | publik |
| Login — daftar lahan | `GET /api/areas` | publik |
| Login petugas gerbang | `POST /api/shifts/join` | → shift |
| Login SPV | `POST /api/auth/sign-in` | → officer |
| Beranda petugas | `GET /api/sessions/dashboard` | shift |
| Check-in | `POST /api/sessions/check-in` (multipart) | shift |
| Check-out — cari sesi | `GET /api/sessions/lookup?plate=&nim=` | shift |
| Check-out — tutup | `POST /api/sessions/{id}/check-out` | shift |
| Check-out — tolak | `POST /api/sessions/{id}/reject` | shift |
| Check-in salah — batal | `POST /api/sessions/{id}/void` | shift |
| Kendaraan aktif | `GET /api/sessions/active` | shift |
| Riwayat | `GET /api/sessions/history` + `/history/meta` | shift |
| Logout petugas | `POST /api/shifts/leave` | shift |
| Logout SPV | `POST /api/auth/sign-out` | officer |
| Kelola lahan | `GET/POST/PATCH /api/areas` | officer (SPV) |
| Kelola petugas | `GET/POST/PATCH /api/officers` | officer (SPV) |
| Kelola shift | `GET /api/shifts`, `POST /api/shifts/open`, `POST /api/shifts/{id}/close` | officer (SPV) |

Catatan alur check-in/check-out:
- `POST /api/sessions/check-in` menerima `nim`, `plate`, `client_request_id`
  (opsional), dan `photo` (opsional) sebagai `multipart/form-data`.
- `POST /api/sessions/{id}/check-out` menerima `plate`, `status`
  (`matched` | `manual_verified`), `note` (wajib bila `manual_verified`),
  `match_method` (opsional), dan `photo` (opsional).

---

## 3. Konvensi bersama (WAJIB sama di semua anggota)

### 3.1 Base URL
Dibaca dari `--dart-define`, default emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```

- Emulator Android: `http://10.0.2.2:8000` (default bila define kosong).
- HP fisik: IP LAN komputer, backend `.env` sudah `HOST=0.0.0.0`.
- Backend jalan dengan `python -m app` setelah `python -m app.seed --reset`.

### 3.2 Bentuk galat backend
Seluruh galat punya bentuk seragam:

```json
{ "code": "duplicate_active_session", "message": "Plat ini sudah punya sesi aktif.", "details": {} }
```

`ApiException` (dibuat Anggota 1) memetakan ini; layar cukup menampilkan
`e.message` lewat snackbar / inline.

### 3.3 Header token
- `X-Shift-Token: <token>` untuk seluruh `/api/sessions/*` dan `shifts/leave`.
- `X-Officer-Token: <token>` untuk `areas`, `officers`, `shifts` (SPV).

`SessionStore` menyimpan token dan menyuntikkannya otomatis di `ApiClient`.

### 3.4 Struktur berkas baru
```
mobile/lib/
  api/api_client.dart      HTTP + header token + parsing galat
  api/api_exception.dart   tipe galat terpadu
  api/session_store.dart   token + identitas sesi aktif (singleton)
  models/*.dart            DTO dari skema backend
```

### 3.5 Aturan
- Tanpa package state management tambahan. Cukup `http` + `SessionStore`.
- **Hanya data yang punya endpoint backend** yang diambil dari API. Bila API
  gagal → tampilkan galat / empty state (tanpa fallback contoh untuk data itu).
- **Fitur yang belum ada di backend dibiarkan statis seperti sekarang** (lihat
  bagian 6). Jangan dihapus, jangan dikosongkan, jangan dipaksa ke API.
- Setelah selesai: `flutter analyze` harus bersih.

---

## 4. Pembagian anggota

| # | Folder | Lingkup | Bergantung pada |
| --- | --- | --- | --- |
| 1 | `anggota-1-fondasi-api` | `ApiClient`, `SessionStore`, `ApiException`, semua model, pubspec, manifest | — (blocker) |
| 2 | `anggota-2-auth-beranda` | `login_screen`, `beranda_screen` | Anggota 1 |
| 3 | `anggota-3-checkin-checkout` | `checkin_screen`, `checkout_screen` | Anggota 1 |
| 4 | `anggota-4-kendaraan-riwayat` | `kendaraan_screen`, `riwayat_screen` | Anggota 1 |
| 5 | `anggota-5-konsol-spv` | `beranda_spv_screen`, `kelola_lahan/petugas/shift_screen` | Anggota 1 |

**Urutan kerja:** Anggota 1 selesai lebih dulu (dipakai semua). Anggota 2–5
dapat berjalan paralel setelah fondasi siap.

---

## 5. Definisi selesai (Definition of Done)

1. Data yang punya endpoint backend tidak lagi statis; data yang belum ada di
   backend tetap statis (bagian 6).
2. Alur penuh berjalan di HP fisik: login → beranda → check-in → check-out →
   kendaraan → riwayat, dan untuk SPV: kelola lahan/petugas/shift.
3. Galat backend tampil sebagai pesan yang terbaca (bukan layar putih/crash).
4. `flutter analyze` bersih.
5. Backend tetap lulus uji bawaannya: `python tests/smoke_test.py`.

---

## 6. Fitur tanpa backend — dibiarkan statis

Fitur berikut **ada di tampilan tetapi belum ada di backend**. Semuanya
**dibiarkan statis seperti saat ini** — jangan dihapus dan jangan dikosongkan.
Hanya bagian yang punya endpoint yang disambungkan ke API.

| Fitur statis | Ada di layar |
| --- | --- |
| Animasi scan QR KTM & kamera (viewfinder, laser, senter) | `checkin_screen` |
| Foto plat contoh (`assets/foto-plat-checkin/checkout.png`) | `checkout_screen` |
| Kapasitas lahan (`428 / 500`, progress bar) | `beranda_screen` |
| Hitungan "Perlu Verifikasi" | `beranda_screen` |
| Nama/ruang "Shift 1 (Pagi)" | `beranda_screen` |
| Tarif / pembayaran (Rp 0 Gratis) | `checkout_screen` |
| Master data mahasiswa & validasi NIM ke basis data kampus | semua |
| Layar/menu Pengaturan Perangkat POS | `beranda_screen`, `checkin_screen` |
| Tampilan snapshot foto `GET /api/sessions/{id}/photo/{in\|out}` (opsional) | `checkout_screen` |

Aturan praktis per layar:
- Kolom yang **ada** di respons backend → isi dari API.
- Elemen yang **tidak** ada padanannya di backend → pertahankan nilai/visual
  statisnya, jangan diganti angka nol atau dihilangkan.

Contoh: pada `beranda_screen`, `active_now` / `checked_in_today` /
`checked_out_today` / `recent` diambil dari API, sementara kartu "Kapasitas
Lahan" dan "Perlu Verifikasi" tetap menampilkan angka statis seperti sekarang.
