# Resolution Experiment Report — SmartPark-OCR (Phase E/F, Tahap 1–4)

- **Tanggal**: 14 Oktober 2026
- **Tujuan**: menguji apakah peningkatan resolusi input memperbaiki generalisasi OCR, terutama domain `rf_detection`.
- **Baseline (tidak diubah)**: `artifacts/transfer_run_wp_lr1e3_bb03_strong/ocr_model.pt` — val CER 0.4657, test CER 0.5236.
- **Split & manifest**: sama dengan baseline (`reports/clean_manifest.csv`, 831/105/108). Seed 42, backbone `wp`, lr 1e-3, backbone-lr-mult 0.3, strong-aug, AdamW, OneCycleLR.
- **Aturan**: resolusi dipilih **hanya dari validation CER**; test tidak dijalankan untuk memilih konfigurasi (`--no-test`). Checkpoint/manifest lama tidak disentuh.

---

## Tahap 1 — Dukungan resolusi & smoke test ✅

Perubahan pada `scripts/phase5_transfer.py` (default **tidak berubah**: `--img-h 32 --img-w 160`):
- `--img-h` / `--img-w`: mengubah resolusi target.
- `--no-test`: melewati evaluasi test (untuk seleksi val-only).

Smoke test (`scripts/improve_res_smoke.py`, hasil `resolution_smoke.json`):

| Config | canvas | T (CNN) | out shape | loss finite | grad finite | T ≥ target | peak GPU (batch 32) |
|---|---|---|---|---|---|---|---|
| H32×W160 | 32×160 | 40 | (32,40,37) | ✅ | ✅ | ✅ | 329 MB |
| H48×W240 | 48×240 | 60 | (32,60,37) | ✅ | ✅ | ✅ | 535 MB |
| H64×W320 | 64×320 | 80 | (32,80,37) | ✅ | ✅ | ✅ | 761 MB |

Aspect-ratio & padding konsisten, preprocess train/val/inference identik, vocab/blank/decoder tidak berubah. GPU (RTX 2050, 4 GB) aman.

---

## Tahap 2 — Pilot 40 epoch (val only)

| Run | val CER @ep40 | best val CER | waktu |
|---|---|---|---|
| baseline H32×W160 (dari history) | 0.6637 | — | — |
| H48×W240 pilot | **0.6421** | 0.6396 @ep37 | 3.2 min |
| H64×W320 pilot | 0.6726 | 0.6599 @ep31 | 4.8 min |

Tren awal: H48 paling menjanjikan, H64 lebih buruk (insertion mulai muncul).

---

## Tahap 3 — Perbandingan adil (val-only, early stop)

H48×W240 dilatih lebih panjang (250 epoch, patience 60). H64 tidak dilanjutkan karena pilot sudah lebih buruk dari baseline.

| Run | val CER | val EM | datatrain CER | rf_detection CER | subs | dels | ins |
|---|---|---|---|---|---|---|---|
| **baseline 32×160** | **0.4657** | **1** | **0.3876** | 0.6637 | 310 | 13 | 44 |
| h48w240 long (250ep) | 0.5343 | 0 | 0.5310 | **0.5426** | 361 | 15 | 45 |
| h64w320 pilot (40ep) | 0.6599 | 0 | 0.6389 | 0.7130 | 398 | 6 | 116 |

Waktu: baseline 2.3 min (early stop ep185), H48-long 20.6 min, H64-pilot 4.8 min. Peak GPU 329 / 535 / 761 MB.

### Temuan utama
1. **H48 memperbaiki domain sulit `rf_detection`** (0.6637 → 0.5426, −18% relatif) — hipotesis Phase D **terkonfirmasi sebagian**.
2. **Tetapi H48 memperburuk `datatrain`** (0.3876 → 0.5310, +37% relatif) sehingga **CER keseluruhan memburuk** (0.4657 → 0.5343).
3. **H64×W320 lebih buruk lagi**; insertion melonjak 44 → 116 (sequence CTC lebih panjang → alignment lebih sulit & over-generate).
4. Montage `montages/h48_val_errors.png` menunjukkan: pada H48 gambar **jauh lebih terbaca** (mis. `B 1045 WMU`, `B 1265 FFK`, `B 1549 RFS`), tetapi model **tetap salah**. → **Resolusi bukan bottleneck utama**; masalahnya adalah diskriminasi karakter / overfitting pada dataset kecil.

**Kesimpulan: meningkatkan resolusi tidak meningkatkan validation CER. Tidak ada konfigurasi yang mengalahkan baseline 32×160.** Baseline dipertahankan.

---

## Tahap 4 — Artefak & rekomendasi

### Artefak baru (tidak menimpa yang lama)
| File | Isi |
|---|---|
| `reports/improvement_v1/resolution_smoke.json` | hasil smoke test 3 resolusi |
| `reports/improvement_v1/resolution_comparison.csv` | tabel perbandingan val |
| `reports/improvement_v1/val_perdomain.txt` | per-domain val |
| `reports/improvement_v1/val_errors_*.csv` | prediksi salah per run |
| `reports/improvement_v1/montages/h48_val_errors.png` | original vs preprocessed H48 |
| `reports/improvement_v1/experiment_results.csv` | ringkasan eksperimen |
| `artifacts/transfer_run_res_h48w240/` | pilot H48 (checkpoint val terbaik) |
| `artifacts/transfer_run_res_h48w240_long/` | H48 250 epoch |
| `artifacts/transfer_run_res_h64w320/` | pilot H64 |

Script baru: `improve_res_smoke.py`, `improve_res_compare.py`. Perubahan: `phase5_transfer.py` (+`--img-h/--img-w/--no-test`), `eval_by_pattern.py` (+`--splits`, baca resolusi dari checkpoint).

### Rekomendasi (butuh persetujuan, belum dijalankan)
1. **Pertahankan 32×160** sebagai resolusi produksi.
2. Karena resolusi menolong `rf_detection` tapi merugikan `datatrain`, akar masalah berikutnya adalah **overfitting/regularisasi**, bukan resolusi. Uji terkontrol satu faktor: freeze backbone warmup → fine-tune bertahap, atau weight-decay/dropout lebih kuat, atau LR backbone lebih rendah.
3. Alternatif berdampak besar: tambah **data domain lapangan** (crop mobil utuh via detector) — **memerlukan persetujuan terpisah** karena menyentuh pipeline deteksi.
4. Jika kelak ingin memakai resolusi lebih tinggi untuk `rf_detection`, pertimbangkan **resolusi adaptif per-gambar** (hanya upscale plat berkonteks kecil) — bukan mengubah resolusi global.

Tidak ada training detector, penggabungan crop, atau perubahan arsitektur yang dilakukan.
