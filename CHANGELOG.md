# Changelog

Semua perubahan penting pada proyek SmartPark didokumentasikan di berkas ini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
dan proyek ini memakai [Semantic Versioning](https://semver.org/lang/id/).

## [0.2.0-beta.1] - 2026-10-12

Rilis beta pertama dengan integrasi backend. Integrasi belum penuh — sebagian
fitur yang belum punya endpoint backend tetap memakai data statis.

### Added
- Fondasi API: `ApiClient`, `SessionStore`, `ApiException`, dan model DTO dari
  skema backend (`mobile/lib/api/`, `mobile/lib/models/`).
- Integrasi backend untuk login petugas & SPV, beranda petugas, check-in,
  check-out, kendaraan aktif, dan riwayat.
- Integrasi konsol SPV: beranda SPV serta kelola lahan, petugas, dan shift.
- Izin `INTERNET` pada `AndroidManifest.xml` utama.
- Dependency `http` dan sejumlah test integrasi API/layar.
- Dokumentasi master plan integrasi backend dan rencana per anggota
  (`docs/plan/integrasi-backend/`).

### Changed
- Sepuluh layar beralih dari data hardcoded ke data backend untuk kolom yang
  tersedia di API. Fitur tanpa endpoint backend dibiarkan statis.

### Known Limitations
- Integrasi backend belum penuh; beberapa fitur masih statis (lihat
  `docs/plan/integrasi-backend/master-plan.md` bagian 6).
- APK rilis masih ditandatangani debug key — hanya untuk uji internal/demo.

[0.2.0-beta.1]: https://github.com/adityarizqiqa/PBL-SMT5-KELOMPOK-4/releases/tag/v0.2.0-beta.1
