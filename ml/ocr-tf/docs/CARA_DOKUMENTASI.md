# Panduan Dokumentasi Proyek

Panduan singkat cara mendokumentasikan pekerjaan OCR SmartPark agar konsisten dan mudah dirujuk tim lain.

---

## 1. Struktur Dokumentasi

```
├── README.md                              # pintu masuk: cara pakai & kontrak integrasi
├── DOKUMENTASI.md                         # kronologi lengkap proyek (bahasa Indonesia)
├── docs/
│   ├── INTEGRASI_YOLO.md                  # panduan untuk tim detektor
│   └── CARA_DOKUMENTASI.md                # dokumen ini
└── reports/
    ├── laporan_smartpark_ocr.pdf           # laporan utama (Typst)
    ├── laporan_ocr_from_scratch.pdf        # laporan model dari nol
    ├── laporan_smartpark_ocr.typ           # sumber Typst
    ├── laporan_ocr_from_scratch.typ
    └── improvement_v1/
        ├── audit_summary.md                # audit data & pipeline
        ├── resolution_report.md            # eksperimen resolusi
        ├── phaseF_finetune_report.md       # fine-tuning & regularisasi
        ├── ocr_benchmark_report.md         # benchmark PARSeq
        ├── ocr_benchmark/                  # CSV hasil, log, montage
        ├── dataset_quality.csv             # kualitas tiap gambar
        ├── error_analysis.csv              # kesalahan per sampel
        └── montages/                       # visualisasi verifikasi
```

---

## 2. Aturan Penulisan

### 2.1 Selalu tulis dengan angka

❌ "Modelnya sudah bagus"
✅ "val CER 0.029, exact match 85/105"

### 2.2 Sebutkan split dan jumlah sampel

Setiap metrik wajib menyebut: **split apa** dan **berapa sampel**.

❌ "CER 0.084"
✅ "CER 0.084 (test, n=108)"

### 2.3 Pisahkan hasil positif dan negatif

Eksperimen yang gagal tetap dicatat. Contoh dari proyek ini:

| Eksperimen | Hasil | Verdict |
|---|---|---|
| Resolusi 48×240 | val 0.5343 | gagal |
| Gradual unfreezing | val 0.5914 | di dalam noise |
| Beam search | 0.0393 vs 0.0368 | lebih buruk |
| Ensemble 3 seed | 0.0355 vs 0.0292 | lebih buruk |

Tanpa catatan negatif, tim lain akan mengulang kesalahan yang sama.

### 2.4 Jangan klaim sebelum diukur

Jangan menulis "meningkat" tanpa tabel pembanding sebelum/sesudah.

### 2.5 Tautkan bukti

Setiap klaim harus menunjuk file: `reports/improvement_v1/ocr_benchmark/parseq_augmented_results.csv`.

---

## 3. Format Laporan

### 3.1 Laporan per-eksperimen (Markdown)

```markdown
# <Judul eksperimen>

- **Tanggal**:
- **Tujuan**:
- **Perubahan** (satu faktor):
- **Baseline pembanding**:

## Hasil
| Metrik | Baseline | Eksperimen |
|---|---|---|
| val CER | | |
| val EM | | |

## Arti output
<kenapa angkanya begitu>

## Verdict
BERHASIL / GAGAL / TIDAK KONKLUSIF

## Artefak
<path file>
```

### 3.2 Laporan formal (Typst → PDF)

Dipakai untuk laporan yang dibaca pihak luar / dosen.

```bash
typst compile --root . reports/laporan_smartpark_ocr.typ
```

Struktur minimal: Ringkasan Eksekutif → Pendahuluan → Dataset → Metodologi → Hasil → Kesimpulan.

### 3.3 Visualisasi wajib

Untuk setiap klaim kualitas, sertakan montage gambar:
- Sampel benar
- Sampel salah (dengan gt vs prediksi)
- Gambar asli **dan** setelah praproses

Simpan di `reports/improvement_v1/montages/`.

---

## 4. Penamaan File

| Jenis | Pola | Contoh |
|---|---|---|
| Script eksperimen | `improve_<topik>.py` | `improve_res_smoke.py` |
| Run artifact | `<tag>/` | `parseq_aug_seed44/` |
| Tag run | `<model>_<variasi>_seed<N>` | `parseq_aug_seed44` |
| CSV hasil | `<topik>_results.csv` | `parseq_augmented_results.csv` |
| Montage | `<topik>_<jenis>.png` | `parseq_val_errors.png` |
| Laporan | `<topik>_report.md` | `resolution_report.md` |

**Aturan tag:** tag harus unik dan deskriptif. Jangan pernah menimpa tag lama — buat tag baru.

---

## 5. Protokol Eksperimen

Wajib dipatuhi agar hasil bisa dipercaya:

1. **Satu faktor per eksperimen.** Ubah augmentasi saja, atau LR saja — jangan sekaligus.
2. **Pilih dari validation.** Test set hanya dipakai **sekali** di akhir.
3. **Multi-seed.** Minimal 3 seed; laporkan mean ± std.
4. **Simpan konfigurasi** di `best.json` (otomatis oleh `train_parseq.py`).
5. **Jangan hapus artefak lama.** Run baru = folder baru.
6. **Catat durasi** training dan penggunaan GPU.

---

## 6. Checklist Sebelum Melaporkan

- [ ] Angka menyebut split + jumlah sampel
- [ ] Ada baseline pembanding
- [ ] Eksperimen gagal ikut dilaporkan
- [ ] Bukti file (CSV montage/log) ditautkan
- [ ] Kesimpulan tidak melebihi data
- [ ] Keterbatasan disebutkan

---

## 7. Menyimpan Data Besar

| Item | Disimpan di repo? | Alasan |
|---|---|---|
| Kode (`scripts/`) | ✅ | inti pekerjaan |
| Laporan (`reports/`, `docs/`) | ✅ | bukti & rujukan |
| Checkpoint final (`checkpoints/`) | ✅ | dibutuhkan integrasi |
| Dataset | ❌ | >1 GB, minta terpisah |
| Run artifacts (`artifacts/`) | ❌ | ratusan MB, bisa direproduksi |
| Checkpoint eksperimen | ❌ | cukup yang terbaik |

Lihat `.gitignore` untuk aturan lengkap.

---

## 8. Konvensi Bahasa

- **Dokumen tim (README, docs/)**: Indonesia, istilah teknis tetap Inggris (`checkpoint`, `augmentasi`, `inference`).
- **Kode & komentar**: Inggris.
- **Commit message**: Inggris, format `area: perubahan` (mis. `ocr: add numpy crop inference API`).
