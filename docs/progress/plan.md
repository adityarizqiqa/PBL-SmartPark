# Plan — SmartPark Campus (PBL Semester 5, Kelompok 4)

> Dokumen perencanaan pengembangan. Status: **draft**.
> Disusun dari inspeksi repo pada 2026-10-08 (branch `main`, HEAD `a4109bc`).
> Bagian yang ditandai `[ASUMSI]` belum diverifikasi dan perlu konfirmasi tim.

---

## 1. Ringkasan Proyek

SmartPark Campus: sistem manajemen parkir kampus berbasis pemindaian KTM mahasiswa dan
plat kendaraan. Petugas pos melakukan check-in/check-out; pengawas (SPV) mengelola lahan,
shift, dan petugas.

**Aktor / peran** (dari `mobile/lib/screens/login_screen.dart`):

| Peran | Deskripsi | Beranda |
|---|---|---|
| Petugas Gerbang / Petugas Pos | Check-in, check-out, monitoring kendaraan | `beranda_screen.dart` |
| Pengawas (SPV) | Kelola lahan, shift, petugas | `beranda_spv_screen.dart` |

---

## 2. Status Saat Ini (evidence-based)

| Area | Direktori | Status |
|---|---|---|
| Mobile (Flutter) | `mobile/` | UI **statis**, ~13.6k LOC Dart, 11 screen + 2 widget + 1 konstanta warna. Belum ada state management, networking, atau persistensi. |
| Backend (API) | `backend/` | Kosong (hanya `.gitkeep`). |
| ML | `ml/` | Kosong (hanya `.gitkeep`). |
| PMPL | `pmpl/` | Kosong (hanya `.gitkeep`). |
| Docs | `docs/` | Kosong; `docs/plan`, `docs/progress`, `docs/etc` hanya `.gitkeep`. |
| UI/UX referensi | `tmp/uiux/` | 16 mockup HTML hasil migrasi Figma (`hT9J40t8qA4YcvtgQwKMVi`). **Di-gitignore** (`tmp/`) — hanya referensi lokal. |

Screen Flutter yang sudah ada (semua statis / data dummy):

- `login_screen.dart` — pilih petugas + lahan, login.
- `beranda_screen.dart` — beranda petugas.
- `beranda_spv_screen.dart` — beranda SPV.
- `checkin_screen.dart` — 3 langkah: Scan KTM → Scan Plat → Konfirmasi sukses (+ input NIM manual).
- `checkout_screen.dart` — verifikasi kendaraan & KTM.
- `kendaraan_screen.dart` — kendaraan sedang parkir.
- `riwayat_screen.dart` — riwayat sesi parkir.
- `kelola_lahan_screen.dart`, `kelola_shift_screen.dart`, `kelola_petugas_screen.dart` — konsol SPV.

**Gap utama:** tidak ada API, database, autentikasi nyata, integrasi kamera/OCR,
state management, maupun pengujian. Semua data masih hardcoded di widget.

---

## 3. Arsitektur Target `[ASUMSI]`

```
mobile (Flutter)  ──HTTP/JSON──>  backend (API)  ──>  DB (PostgreSQL/MySQL)
      │                               │
      └── kamera (KTM/plat) ──> ml/ (deteksi & OCR) ──> backend
```

- **Mobile**: Flutter. Tambah state management (Riverpod/Provider), `http`/`dio`, model JSON,
  kamera (`camera`/`mobile_scanner`), penyimpanan token (`flutter_secure_storage`).
- **Backend**: REST API. Stack `[ASUMSI]` FastAPI (Python) atau Node/Express — **harus diputuskan tim**.
  Autentikasi JWT, role-based access (petugas vs SPV).
- **ML**: `[ASUMSI]` OCR plat nomor (mis. YOLO + CRNN / Tesseract) dan/atau decode QR KTM.
- **DB**: tabel inti `[ASUMSI]`: `petugas`, `lahan_parkir`, `shift`, `sesi_parkir`,
  `kendaraan`, `mahasiswa`, `slot`, `log_kendala`.

> Keputusan stack backend & ML adalah **blocker** untuk seluruh fase implementasi. Tandai
> dan putuskan lebih dulu.

---

## 4. Kontrak API `[ASUMSI — draft, perlu disepakati]`

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/auth/login` | Login petugas, balas JWT + profil + role |
| GET | `/lahan` | Daftar lahan + kapasitas terisi |
| GET | `/lahan/{id}/kendaraan` | Kendaraan sedang parkir |
| POST | `/checkin` | Buat sesi parkir (NIM, plat, lahan, petugas) |
| POST | `/checkout` | Tutup sesi parkir |
| GET | `/riwayat` | Riwayat sesi (filter tanggal/lahan) |
| POST | `/ml/scan-ktm` | OCR/decode KTM → NIM |
| POST | `/ml/scan-plat` | OCR plat → nomor plat |
| CRUD | `/lahan`, `/shift`, `/petugas` | Konsol SPV |

---

## 5. Roadmap

### Fase 0 — Fondasi & Keputusan
- [ ] Tetapkan stack backend, DB, dan pendekatan ML.
- [ ] Sepakati model data & kontrak API (bagian 3–4).
- [ ] Setup repo: struktur `backend/`, `ml/`, skema DB, `.env.example`, README tiap modul.
- [ ] Setup lint/format & CI dasar (Flutter analyze, Python lint).

### Fase 1 — Backend + DB
- [ ] Skema DB + migrasi + seed data (petugas, lahan, shift).
- [ ] Auth JWT + middleware role.
- [ ] Endpoint inti: auth, lahan, check-in/out, riwayat.
- [ ] Endpoint CRUD SPV (lahan, shift, petugas).
- [ ] Dokumentasi API (OpenAPI/Swagger).

### Fase 2 — Integrasi Mobile
- [ ] Layer networking + model + error handling.
- [ ] State management; ganti data dummy di semua screen.
- [ ] Login nyata + simpan token + routing sesuai role.
- [ ] Check-in/check-out terhubung API.
- [ ] Riwayat, kendaraan, konsol SPV terhubung API.

### Fase 3 — ML
- [ ] Kumpulkan & anotasi dataset (KTM, plat kendaraan kampus).
- [ ] Latih model OCR plat dan/atau decode KTM.
- [ ] Bungkus jadi service (endpoint `/ml/*`) + integrasi ke alur check-in.

### Fase 4 — Hardening & Demo
- [ ] Validasi input, penanganan kendala/error (screen `status kendala & solusi`).
- [ ] Pengujian: unit test backend, widget/unit test mobile, uji alur end-to-end.
- [ ] Isi `docs/plan`, `docs/progress`, `docs/etc` (dokumen PBL/PMPL).
- [ ] Build & demo perangkat (Android).

---

## 6. Konvensi & Aturan Repo

- Bahasa dokumen & UI: Indonesia.
- Branch per fitur; PR ke `main`. Commit mengikuti gaya yang sudah ada (`feat: ...`).
- **Jangan** commit isi `tmp/` (sudah di-gitignore) — mockup hanya referensi lokal.
- Simpan rahasia di `.env` (di-gitignore); sediakan `.env.example`.

## 7. Risiko

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Stack backend/ML belum diputuskan | Blokir semua implementasi | Putuskan di Fase 0 |
| Akurasi OCR plat rendah | Alur check-in gagal | Fallback input manual (sudah ada di UI) |
| Dataset ML terbatas | Model lemah | Mulai pengumpulan data lebih awal |
| UI statis besar (~13.6k LOC) tanpa test | Refactor berisiko | Tambah test bertahap saat integrasi |
| `tmp/` di-gitignore | Mockup hilang bila lokal terhapus | Salin spesifikasi penting ke `docs/` |

## 8. Definisi Selesai (DoD)

- Fitur berjalan end-to-end (mobile → API → DB), bukan data dummy.
- Ada pengujian untuk logika inti + verifikasi alur manual.
- Dokumentasi API & modul diperbarui.
- Tidak ada rahasia ter-commit; `tmp/` tidak ikut commit.
