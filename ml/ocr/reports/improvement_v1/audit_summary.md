# Audit Summary — SmartPark-OCR Improvement v1 (Phases A–D)

- **Tanggal**: 14 Oktober 2026
- **Status**: audit selesai; belum ada training baru, belum ada perubahan dataset/arsitektur.
- **Baseline yang dipertahankan**: `artifacts/transfer_run_wp_lr1e3_bb03_strong/ocr_model.pt`
- **Direktori hasil**: `reports/improvement_v1/`

---

## 1. Ringkasan Temuan (Evidence-Based)

### 1.1 Baseline reproducible (Phase A) ✅
Evaluasi ulang checkpoint terbaik (`scripts/improve_baseline_eval.py`) menghasilkan angka **identik** dengan laporan historis:

| Split | greedy CER | greedy EM | TTA+greedy CER | TTA+greedy EM |
|---|---|---|---|---|
| val | 0.4657 | 1/105 | 0.4619 | 2/105 |
| test | 0.5236 | 1/108 | 0.5136 | 1/108 |

Checkpoint terverifikasi: epoch 125, `best_val_cer` 0.4657, backbone ResNet18-pretrained, charset `A-Z0-9`, blank=0, img 32×160, 14,352,761 parameter. Vocabulary/preprocess/decoder/CTC length konsisten antara train & inference (dicek ulang; lihat §1.6).

### 1.2 Integritas dataset bersih (Phase B/C) ✅
- 1863 pasangan gambar-label: **0 file hilang, 0 label kosong, 0 karakter ilegal, 0 mismatch manifest vs `label.csv`**.
- Split lama (831/105/108): **0 exact-duplicate cross-split, 0 near-duplicate cross-split, 0 label leakage** (train∩val, train∩test, val∩test semuanya kosong).
- Split **layak dipertahankan**.

### 1.3 Klasifikasi kualitas visual (Phase B) — `dataset_quality.csv`
| Kategori | Jumlah | Catatan |
|---|---|---|
| crop_ok | 987 | termasuk 347 `rf_detection` (square berkonteks) |
| full_vehicle | 716 | 358 plain + 358 rf_vehicle (dikecualikan dari OCR) |
| blur_dark_bright_extreme | 75 | semua `datatrain` |
| crop_too_small | 69 | semua `datatrain` (min dim < 24 px) |
| near_duplicate | 16 | semua `datatrain` (dhash ≤ 4, tidak cross-split) |
| label_mismatch_suspect | **0** | label diverifikasi visual, semuanya benar |
| unreadable | 0 | semua gambar terbuka |

Verifikasi visual dilakukan pada montage `montages/` (cat1..cat5, cat9, `suspicious_label_review.png`, `error_original_vs_preprocessed.png`). **Tidak ditemukan label noise sistematis.** Kasus `DataTrain1.png` (label A7814) memang gelap/blur ekstrem (brightness 30.9, sharpness 4.4) — sampel sulit valid, bukan label salah.

### 1.4 AKAR MASALAH UTAMA: resolusi karakter `rf_detection` (Phase D) 🔴
`rf_detection` (347 sampel, 416×416 square) setelah preprocessing hanya menempati **32 px dari 160 px** kanvas → **~4.6 px per karakter** (7 karakter), vs `datatrain` ~13.7 px/karakter. Terkonfirmasi di montage: plat di baris "preprocessed" nyaris tak terbaca.

Akibatnya, performa terpecah tajam per domain (val+test, TTA+greedy):

| Domain | n | CER | EM |
|---|---|---|---|
| datatrain | 147 | **0.4062** | 3 |
| rf_detection | 66 | **0.6814** | 0 |

**Ini masalah preprocessing/resolusi, bukan jumlah data, bukan arsitektur, bukan label.** (Catatan: 347 `rf_detection` **tidak ada** di `annotations.json` dataset deteksi → tidak bisa di-crop ulang tanpa detector.)

### 1.5 Pola kesalahan = substitution, bukan panjang (Phase D) 🔴
Agregat val+test (TTA+greedy): **subs=661, dels=17, ins=100**. Panjang prediksi hampir selalu benar (Δlen = 0 pada 122/213; hanya 7 sampel lebih panjang). Jadi model **gagal mendiskriminasi karakter**, bukan gagal memprediksi jumlah karakter.

Confusion teratas (gt→pred): `8→9`, `2→3`, `0→8`, `6→9`, `6→8`, `9→6`, `7→1`, `2→5`, `4→6`, `T→S`. **Semuanya digit/near-shape**, konsisten dengan kehilangan detail akibat resolusi rendah.

Distribusi longest-common-prefix: mayoritas 0.1–0.5 → model sering hanya benar di 1–2 karakter awal, lalu runtuh di digit.

### 1.6 Pipeline & CTC valid (Phase A)
- `input_lengths` = `out.shape[1]` (T=40 untuk `wp`), `target_lengths` = panjang label; T ≥ target untuk semua sampel.
- Decoder greedy collapse+blank benar (unit test lolos di `phase3_checks.json`).
- Preprocessing train == inference (`prep()` di `phase5_transfer.py` dipakai untuk load & eval).
- TTA hanya memakai transformasi geometri ringan (shift ±2px, skala 0.95/1.05, brightness ±15) — tidak merusak karakter; terbukti **memperbaiki** CER (0.5236→0.5136).
- Laporan historis memang dihasilkan oleh checkpoint & kode yang disebutkan.

### 1.7 Test set mengandung sampel berkualitas rendah
19/108 sampel test berkategori `crop_too_small`/`blur_dark`/`near_duplicate` (mis. `DataTrain1.png`, `DataTrain110.png` 69×22). Ini membatasi plafon metrik test dan sebagian error bukan kesalahan model yang bisa diperbaiki.

---

## 2. Masalah Paling Berpengaruh (Prioritas)

1. **Resolusi karakter rendah untuk input square/crop berkonteks (`rf_detection`)** → CER domain ini 0.68 vs 0.41. Berdampak ~31% sampel.
2. **Substitution-dominated errors** → kapasitas fitur visual kurang untuk membedakan digit mirip.
3. **Test set bercampur domain & kualitas** → metrik tunggal menyesatkan; perlu evaluasi per-domain.
4. **Domain shift dari 355 crop recovered (motor)** → jangan dimasukkan tanpa kurasi (sesuai aturan misi).

---

## 3. Perubahan yang Direkomendasikan (BELUM dijalankan — butuh persetujuan)

| # | Perubahan | Alasan | Risiko | Kategori |
|---|---|---|---|---|
| R1 | Naikkan resolusi input (mis. IMG_H 32→48/64, IMG_W 160→320/384) atau hilangkan width-cap agar plat square tidak menyusut | Menyerang akar R1 §1.4/§1.5 | Model lebih lambat; perlu re-train; harus pilih lewat val, bukan test | preprocessing |
| R2 | Eksperimen resolusi kecil (subset) dulu sebelum full training | Aturan misi §8 | — | prosedur |
| R3 | Gunakan TTA+greedy sebagai inference baseline | Terbukti menurunkan val & test CER | minor | decoding |
| R4 | Bangun set evaluasi per-domain (datatrain vs rf_detection) + laporkan terpisah | Metrik tunggal menutupi kegagalan domain | — | evaluasi |
| R5 | Kuras 355 crop recovered: pisahkan domain motor, cek label, jangan campur sembarangan | Aturan misi §7; mencegah domain shift | kehilangan data jika terlalu ketat | data |
| R6 | (Perlu persetujuan terpisah) Crop ulang `rf_detection` dari sumber beresolusi lebih tinggi **memerlukan detector** karena tidak ada bbox | Mengembalikan detail karakter | **STOP sebelum latih detector** | deteksi |

**Tidak diusulkan**: mengganti arsitektur menyeluruh (belum ada bukti), menambah 355 crop otomatis (melanggar §7).

---

## 4. Perintah untuk Fase Berikutnya (setelah persetujuan)

```powershell
# R2: eksperimen resolusi kecil (subset train, val) — bukan test
& "D:\spocr-venv\Scripts\python.exe" scripts\phase5_transfer.py `
    --device cuda --backbone wp --lr 0.001 --backbone-lr-mult 0.3 --strong-aug `
    --epochs 40 --patience 20 --tag res_small --manifest reports\clean_manifest.csv
# (IMG_H/IMG_W diubah lewat argumen baru yang akan ditambahkan, atau varian script terpisah)

# Evaluasi per-domain setiap kandidat
& "D:\spocr-venv\Scripts\python.exe" scripts\eval_by_pattern.py `
    --model artifacts\<tag>\ocr_model.pt --manifest reports\clean_manifest.csv
```

---

## 5. Deliverable Phase A–D yang sudah dibuat

| File | Isi |
|---|---|
| `baseline/metrics.json`, `baseline/predictions_val.csv`, `baseline/predictions_test.csv`, `baseline/baseline_log.txt` | baseline reproducible |
| `dataset_quality.csv` | kualitas 1863 gambar + kategori + alasan |
| `recovered_quality.csv` | kualitas 355 crop recovered |
| `near_duplicates.csv` | pasangan near-duplicate (dhash ≤ 4) |
| `split_audit.json`, `split_audit_log.txt` | integritas label/split/duplikasi/leakage |
| `label_review.csv` | review label per baris |
| `split_manifest.csv` | manifest baru (split lama dipertahankan + kategori kualitas) |
| `error_analysis.csv`, `error_summary.json` | analisis error per sampel + confusion |
| `experiment_results.csv` | skeleton hasil eksperimen (diisi di Phase F) |
| `montages/cat1..cat9_*.png`, `suspicious_label_review.png`, `error_original_vs_preprocessed.png` | montage verifikasi visual |
| `audit_summary.md` | dokumen ini |

**Tidak ada** checkpoint, manifest lama, dataset, atau log lama yang diubah/dihapus.
