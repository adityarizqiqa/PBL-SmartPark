# PBL-SmartPark

Sistem parkir otomatis berbasis pengenalan plat nomor.

## Struktur

| Folder | Isi |
|---|---|
| `backend/` | API & logika transaksi parkir |
| `ml/` | Model machine learning (deteksi plat & OCR) |
| `mobile/` | Aplikasi mobile |
| `pmpl/` | Manajemen proyek & dokumentasi proses |
| `docs/` | Dokumen perencanaan & integrasi |

## ML

- [`ml/ocr/`](ml/ocr/README.md) — **OCR plat nomor** (PARSeq, CER 0.029 / EM 85 dari 105 pada validation)
  - Cara pakai: `ml/ocr/README.md`
  - Panduan integrasi YOLO → OCR: [`ml/ocr/docs/INTEGRASI_YOLO.md`](ml/ocr/docs/INTEGRASI_YOLO.md)
  - Laporan lengkap: `ml/ocr/reports/laporan_smartpark_ocr.pdf`
