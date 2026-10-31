# Fine-tuning & Regularization Experiment Report — SmartPark-OCR (Phase F lanjutan)

- **Tanggal**: 14 Oktober 2026
- **Tujuan**: menguji apakah gradual unfreezing dan pengaturan learning rate backbone (Exp A) serta regularisasi (Exp B) meningkatkan generalisasi tanpa mengubah arsitektur atau menaikkan resolusi.
- **Input**: 32×160 (tidak diubah).
- **Seleksi**: hanya **validation CER** (`--no-test`). Test tidak dijalankan untuk memilih konfigurasi/epoch/checkpoint.
- **Baseline lama dipertahankan**: `artifacts/transfer_run_wp_lr1e3_bb03_strong/ocr_model.pt`.

---

## Tahap 1 — Audit konfigurasi & reproduksi baseline

### Konfigurasi optimizer/scheduler (dibaca dari `phase5_transfer.py`)
| Komponen | Nilai baseline |
|---|---|
| Optimizer | AdamW |
| LR head (BiLSTM+classifier) | 1e-3 |
| LR backbone | 1e-3 × 0.3 = 3e-4 |
| Scheduler | OneCycleLR, `pct_start=0.1`, `total_steps=epochs×steps_per_epoch` |
| Weight decay | 1e-4 |
| Dropout (LSTM) | 0.3 |
| Freezing | **tidak ada** mekanisme di baseline |
| Batch / seed | 32 / 42 |

Ditambahkan (default **tidak berubah**): `--img-h/--img-w`, `--dropout`, `--weight-decay`, `--freeze-epochs`, `--unfreeze-at`, `--no-test`.

### ⚠️ Temuan penting: baseline historis TIDAK reproducible
Menjalankan ulang konfigurasi default (backbone `wp`, lr 1e-3, bb-mult 0.3, strong-aug, seed 42, 300 ep, patience 60) **tiga kali**:

| Run | best val CER | best epoch | train CER @best |
|---|---|---|---|
| **historis `wp_lr1e3_bb03_strong`** | **0.4657** | 125 | 0.1456 |
| baseline_repro | 0.6193 | 63 | 0.5931 |
| baseline_repro2 | 0.5952 | 98 | 0.4106 |
| baseline_repro3 | 0.5609 | 101 | 0.3361 |

Tiga run segar konsisten di **0.561–0.619** (mean ≈ 0.59). Dua run dengan config identik pun berbeda (det_a ep30 0.6713 vs det_b ep30 0.6751) → **training nondeterministik** (cuDNN LSTM). Arsitektur & key checkpoint identik (dibandingkan langsung), jadi perbedaannya murni lintasan optimasi. **Kesimpulan: 0.4657 historis adalah outlier di luar sebaran run segar; baseline yang adil untuk perbandingan adalah baseline segar (~0.59).** Ini juga menjelaskan mengapa H48 (0.5343) sebelumnya tampak "lebih buruk dari baseline" padahal baseline segar sendiri ~0.59.

---

## Tahap 2 — Eksperimen A: gradual unfreezing

- Input 32×160, manifest/split/seed/aug/lr/optimizer **sama** dengan baseline.
- Backbone dibekukan seluruhnya; dibuka bertahap (paling dalam dulu):
  `layer4@ep5 → layer3@ep15 → layer2@ep30 → layer1@ep45 → stem@ep60`.
- LR backbone tetap 3e-4 (< head 1e-3). Scheduler OneCycleLR menangani semua grup.

Hasil (val, `--no-test`):

| Run | val CER | val EM | datatrain CER | rf_detection CER | train CER @best |
|---|---|---|---|---|---|
| baseline segar (repro2) | 0.5952 | 0 | 0.5646 | 0.6726 | 0.4106 |
| **Exp A (unfreeze)** | **0.5914** | 1 | 0.5611 | 0.6682 | 0.1472 |

Durasi 9.1 min. Exp A menyamai baseline segar dalam hal fitting training (train CER 0.147) tetapi **val CER hampir tidak berubah** (0.5914 vs 0.5952; selisih di dalam noise).

---

## Tahap 3 — Eksperimen B: regularisasi (satu faktor)

Mengubah **hanya** weight decay 1e-4 → 1e-3 (10×), sisanya identik dengan baseline.

| Run | val CER | val EM | datatrain CER | rf_detection CER | train CER @best |
|---|---|---|---|---|---|
| baseline segar (repro2) | 0.5952 | 0 | 0.5646 | 0.6726 | 0.4106 |
| **Exp B (wd 1e-3)** | **0.6003** | 0 | 0.5681 | 0.6816 | 0.3285 |

Durasi 7.8 min. **Tidak ada perbaikan** (sedikit lebih buruk).

---

## Evaluasi (ringkas)

| Run | val CER | val EM | datatrain | rf_detection | gap domain |
|---|---|---|---|---|---|
| historis (outlier) | 0.4657 | 1 | 0.3876 | 0.6637 | 0.276 |
| baseline segar terbaik (repro3) | 0.5609 | 0 | 0.5292 | 0.6413 | 0.112 |
| baseline segar (repro2) | 0.5952 | 0 | 0.5646 | 0.6726 | 0.108 |
| Exp A unfreeze | 0.5914 | 1 | 0.5611 | 0.6682 | 0.107 |
| Exp B wd 1e-3 | 0.6003 | 0 | 0.5681 | 0.6816 | 0.114 |

- **Tidak ada peningkatan val CER**: Exp A (0.5914) dan Exp B (0.6003) berada di dalam sebaran baseline segar (0.561–0.619). Bahkan baseline segar repro3 (0.5609) lebih baik dari keduanya.
- **Kesenjangan antar-domain tidak berkurang**: ~0.107–0.114 pada semua run segar.
- Pola kesalahan **tidak berubah**: masih didominasi substitution digit (8↔0, 9↔1, 6↔5, 4↔3). Lihat `montages/expA_unfreeze_val_errors.png`, `montages/expB_wd1e3_val_errors.png`.

---

## Kesimpulan (jujur, tanpa klaim berlebihan)

1. **Baseline historis 0.4657 tidak dapat direproduksi** dengan kode/environment saat ini; tiga run identik memberi 0.561–0.619.
2. **Gradual unfreezing (Exp A) tidak meningkatkan generalisasi** (val CER 0.5914, di dalam noise baseline).
3. **Weight decay lebih kuat (Exp B) tidak meningkatkan generalisasi** (val CER 0.6003).
4. **Kesenjangan datatrain↔rf_detection tidak berkurang**; akar masalah (substitution digit) tetap.

## Rekomendasi berikutnya (berbasis bukti, belum dijalankan)
1. **Stabilkan dulu evaluasi**: karena variansi run besar, keputusan selanjutnya sebaiknya memakai **rata-rata beberapa seed** atau `torch.backends.cudnn.deterministic=True`, agar perbandingan tidak menyesatkan.
2. Uji faktor lain satu per satu pada baseline segar: dropout 0.3→0.5, atau LR backbone lebih kecil (0.3→0.1), dengan protokol multi-seed.
3. Akar masalah sebenarnya kemungkinan **kapasitas data**, bukan optimisasi: pertimbangkan menambah data domain lapangan (butuh persetujuan terpisah, menyentuh pipeline deteksi).
4. **Jangan** mengejar training loss lebih rendah — Exp A sudah menunjukkan train CER 0.147 tapi val tetap ~0.59.

## Artefak baru (tidak menimpa yang lama)
- Run: `artifacts/transfer_run_baseline_repro{,2,3}`, `artifacts/transfer_run_expA_unfreeze`, `artifacts/transfer_run_expB_wd1e3`.
- Laporan: `reports/improvement_v1/phaseF_finetune_report.md`, `experiment_results.csv`, `expA_B_perdomain.txt`, `baseline_fresh_perdomain.txt`, `*_console.txt`, `val_errors_expA_unfreeze.csv`, `val_errors_expB_wd1e3.csv`, `montages/expA_unfreeze_val_errors.png`, `montages/expB_wd1e3_val_errors.png`.
- Script: `scripts/improve_val_errors.py`; perubahan opt-in pada `scripts/phase5_transfer.py`.
