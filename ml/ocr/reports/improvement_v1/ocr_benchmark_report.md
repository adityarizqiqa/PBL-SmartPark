# SmartPark OCR — Evaluation Stabilization & Pretrained OCR Benchmark

- **Tanggal**: 14 Oktober 2026
- **Lingkup**: OCR saja (YOLO/detektor TIDAK disentuh).
- **Aturan**: pemilihan konfigurasi/checkpoint **hanya dari validation**; test tidak dipakai untuk tuning. Semua artefak lama dipertahankan.
- **Direktori hasil**: `reports/improvement_v1/ocr_benchmark/`
- **Baseline lama**: `artifacts/transfer_run_wp_lr1e3_bb03_strong/ocr_model.pt` (tidak diubah).

---

## 1. Temuan Audit Nondeterminisme (Tahap 1)

Environment: Python 3.10.6, torch 2.6.0+cu124, torchvision 0.21.0+cu124, CUDA 12.4, cuDNN 9.1.0, RTX 2050 (4 GB).

`scripts/phase5_transfer.py` (audit kode):
- Seed: hanya `random.seed(42)`, `np.random.seed(42)`, `torch.manual_seed(42)` — **tidak ada** `torch.cuda.manual_seed_all`.
- `torch.backends.cudnn.deterministic` / `benchmark`: **tidak diset**.
- `torch.use_deterministic_algorithms`: **tidak dipakai**.
- Tidak ada DataLoader (data dimuat penuh ke memori); augmentasi memakai modul `random` global.
- `random.shuffle(idx)` untuk urutan batch — deterministik bila seed direset.

**Penyebab nondeterminisme teridentifikasi:**
1. Algoritma cuDNN (khususnya LSTM/RNN) memilih kernel non-deterministik secara default.
2. `ctc_loss_backward_gpu` **tidak punya implementasi deterministik** (peringatan resmi dari PyTorch saat `use_deterministic_algorithms(True)`).
3. Attention backward PARSeq (memory-efficient attention) juga non-deterministik.

**Perubahan terkontrol** (opt-in, default TIDAK berubah): menambahkan `--seed`, `--deterministic` (set `cudnn.deterministic=True`, `benchmark=False`, `use_deterministic_algorithms(True, warn_only=True)`, `CUBLAS_WORKSPACE_CONFIG=:4096:8`, `cuda.manual_seed_all`).

**Bukti determinisme tercapai** (untuk CRNN): dua run seed 42, 15 epoch → log **identik bit-per-bit** (`tr_loss 2.6360 / valCER 0.7766` dst.), dan full-run seed 42 direplikasi → best val CER **0.4530 keduanya**. Jadi training CRNN **reproducible** pada level run penuh meski backward CTC secara teknis non-deterministik (efeknya tak terukur pada setup ini).

**Keterbatasan determinisme yang didokumentasikan**: `ctc_loss_backward_gpu` dan attention-backward PARSeq dilaporkan non-deterministik; klaim reproduksibilitas hanya berlaku untuk CRNN dan diverifikasi secara empiris, bukan dijamin lintas versi/GPU.

---

## 2. Protokol Evaluasi (konsisten untuk semua model)

- Manifest & split sama: `reports/clean_manifest.csv` → **train 831 / val 105 / test 108**. Val dipakai untuk semua keputusan.
- CER = total edit distance / total karakter GT; EM = jumlah plat yang persis benar.
- Metrik per-domain dari kolom `pattern` (`datatrain`, `rf_detection`).
- Decoding sesuai arsitektur: CRNN = greedy CTC; PARSeq = autoregressive.
- Preprocessing sesuai model: CRNN = grayscale 32×160; PARSeq = RGB 32×128 (native).
- Evaluator bersama: `scripts/benchmark/eval_bench.py` (CRNN), `scripts/benchmark/eval_parseq.py` (PARSeq), `scripts/benchmark/compare_val.py` (gabungan).

---

## 3. Replikasi Baseline (multi-seed, deterministik)

5 seed (42–46), config default, val-only (`--no-test`):

| Seed | best val CER | val EM |
|---|---|---|
| 42 | 0.4530 | 1 |
| 43 | 0.5673 | 0 |
| 44 | 0.6117 | 0 |
| 45 | 0.5736 | 0 |
| 46 | 0.5838 | 0 |

**Ringkasan: mean 0.5579, std 0.0546, min 0.4530, max 0.6117, mean EM 0.2.**
(CSV: `baseline_multiseed.csv`, `baseline_multiseed_summary.json`.)

**Kesimpulan penting:** baseline historis 0.4657 berada di **ujung bawah** sebaran seed (dekat min 0.4530), bukan performa umum. Nilai representatif baseline ≈ **0.56 ± 0.05**. Setiap perbandingan harus menyebut variasi antar-run ini.

---

## 4. Analisis per Domain (baseline, val)

| Checkpoint | overall CER | EM | datatrain CER | rf_detection CER |
|---|---|---|---|---|
| seed42 (best) | 0.4530 | 1 | 0.3699 | 0.6637 |
| historical | 0.4657 | 1 | 0.3876 | 0.6637 |
| seed44 (worst) | 0.6117 | 0 | 0.5894 | 0.6682 |

`rf_detection` **stabil di ~0.66** pada semua run — bottleneck konsisten (plat square berkonteks yang menyusut jadi ~4.6 px/karakter pada input 32×160). `datatrain` bervariasi besar (0.37–0.59). Error baseline didominasi **substitution digit** (8↔0, 9↔1, 6↔5). (Montage: `montages/error_original_vs_preprocessed.png`, `val_errors_*`.)

---

## 5. Kandidat Pretrained OCR (Tahap 3)

**Dipilih: PARSeq** (baudm/parseq, ECCV 2022).
- **Dukungan karakter**: charset 94 printable ASCII — mencakup A–Z/0–9. Label kita subset penuh. ✅
- **Pretrained weights**: `parseq-bb5792a6.pt` (STR scene-text), tersedia publik. ✅
- **Lisensi**: Apache-2.0 (aman untuk produk). ✅
- **Dependensi**: `torch` + `timm` (kode model di-vendor ke `scripts/benchmark/parseq_vendor`, tanpa `pytorch_lightning`). ✅
- **Kompatibilitas**: berjalan di GPU 4 GB (peak ~2 GB, batch 16). ✅
- **Memori/komputasi**: 23.8 M param, ~9 s/epoch fine-tune. ✅
- **Evaluasi di gambar/label sama**: ya (manifest identik). ✅

Alternatif dipertimbangkan: PaddleOCR (rec) dan EasyOCR — lebih berat dependensinya dan/atau pretrained dominan non-latin; PARSeq paling ringan & terintegrasi. Dipilih **satu** kandidat sesuai instruksi.

**Verifikasi penting:** PARSeq **zero-shot TIDAK berguna** untuk plat kita (val CER **1.0406**, EM 0) karena tidak pernah melihat font/format plat Indonesia. Maka **fine-tuning wajib**, dan itulah yang diukur.

**Environment terpisah**: dibuat venv `D:\spocr-parseq-venv` yang **me-reuse torch baseline** (via `.pth`) dan hanya menambah `timm` — agar environment baseline tidak berubah.

---

## 6. Hasil Benchmark (validation, 105 sampel)

Protokol: fine-tune hanya pada train (831), checkpoint dipilih via val CER. Budget: 80 epoch (konvergen ~ep45), batch 16, AdamW lr 1e-4, wd 0.05.

| Model | Checkpoint | Param | Run | val CER | val EM | datatrain CER | rf_detection CER | latency |
|---|---|---|---|---|---|---|---|---|
| CRNN-ResNet18(wp) | 5-seed (mean) | 14.3 M | 5 | **0.5579 ± 0.0546** | 0.2 | — | — | ~0.8–2.9 ms |
| CRNN-ResNet18(wp) | historical | 14.3 M | 1 | 0.4657 | 1 | 0.3876 | 0.6637 | 0.78 ms |
| **PARSeq-finetuned** | seed42 | 23.8 M | 1 | **0.0685** | **64/105** | 0.0779 | **0.0448** | 6.11 ms |
| **PARSeq-finetuned** | seed43 | 23.8 M | 1 | **0.0647** | **66/105** | 0.0726 | **0.0448** | 4.78 ms |

(CSV: `bench_comparison_val.csv`, `benchmark_summary.csv`. Run: `parseq_runs/parseq_ft_seed{42,43}/`.)

**Temuan:**
- PARSeq fine-tuned **jauh mengalahkan** baseline: val CER ~**0.065** vs ~0.56 (≈8.6× lebih rendah); EM **64–66/105** vs 0–1.
- **Gap antar-domain hilang**: `rf_detection` CER turun **0.66 → 0.045** dan `datatrain` **0.39 → 0.07**; PARSeq bahkan sedikit lebih baik di `rf_detection` (0.0448) daripada `datatrain` (0.073–0.078) → **konsisten di kedua domain** (kriteria keberhasilan misi terpenuhi).
- Dua seed PARSeq **konsisten** (0.0685 vs 0.0647, selisih 0.004 — jauh lebih kecil dari std baseline 0.055). Jadi peningkatan **bukan artefak satu run**.
- Biaya: param 1.66×, latency ~5–6 ms/gambar (masih sangat cepat untuk parkir).
- Sisa error PARSeq = **near-miss pada plat sulit/blur** (mis. `AB6729NC→AB6723NG`), bukan kegagalan sistematis (montage: `montages/parseq_val_errors.png`).

---

## 7. Keterbatasan

1. **Test set tidak dievaluasi** untuk kandidat (sesuai aturan: test tidak dipakai memilih). Angka di atas semuanya **validation**.
2. **Perbedaan preprocessing & arsitektur** (grayscale 32×160 CRNN vs RGB 32×128 PARSeq) adalah bagian dari pendekatan, bukan perbandingan apple-to-apple satu-faktor. Yang diukur adalah *pendekatan OCR*, sesuai tujuan misi.
3. **Keuntungan data pretraining**: PARSeq dilatih pada data scene-text skala besar; ini justru lever yang ingin dibuktikan, tetapi berarti peningkatan tidak berasal dari arsitektur semata.
4. **Potensi overlap data**: sebagian data kita berasal dari Roboflow/publik; tidak dapat dipastikan PARSeq pretraining tidak pernah melihat gambar serupa. Klaim hanya berlaku untuk **split val kita**.
5. Baseline determinisme terverifikasi (CRNN); PARSeq attention-backward dilaporkan non-deterministik (belum diuji full-run replicate).
6. Latency diukur pada RTX 2050, batch 32, bukan kondisi CPU/deployment.

---

## 8. Rekomendasi

1. **Pertahankan & adopsi PARSeq fine-tuned sebagai kandidat OCR utama** untuk SmartPark. Dasarnya: val CER 0.065 vs 0.56, EM 64–66/105 vs 0–1, dan konsisten di kedua domain.
2. **Langkah berikutnya yang disarankan (belum dijalankan, butuh persetujuan)**:
   - Evaluasi **sekali** pada test 108 (atau data kamera SmartPark baru) sebagai ukuran independen final, setelah keputusan model ditetapkan.
   - Uji kestabilan PARSeq dengan 3–5 seed + protokol deterministik penuh.
   - Benchmark efisiensi deployment (ONNX/TensorRT, latency CPU) karena PARSeq 1.66× lebih besar.
3. **Baseline CRNN tetap disimpan** sebagai fallback ringan; jangan dihapus.
4. Untuk produksi, pasangkan PARSeq dengan **plate-format validation** (prefix wilayah + panjang) sebagai post-processing untuk menaikkan EM.

---

## 9. File yang Dibuat/Diubah

**Baru (script):**
- `scripts/benchmark/parseq_common.py` — util PARSeq (model, preprocess, decode, CER/EM)
- `scripts/benchmark/train_parseq.py` — fine-tuning PARSeq (val-selected)
- `scripts/benchmark/eval_parseq.py` — evaluasi PARSeq
- `scripts/benchmark/eval_bench.py` — evaluasi CRNN per-domain + latency
- `scripts/benchmark/compare_val.py` — tabel perbandingan gabungan
- `scripts/benchmark/parseq_errors.py` — dump error + montage
- `scripts/benchmark/smoke_test.py` — smoke test
- `scripts/benchmark/parseq_vendor/` — kode model PARSeq (Apache-2.0) + bobot pretrained
- `scripts/improve_multiseed.py` — replikasi baseline multi-seed

**Diubah (opt-in, default aman):**
- `scripts/phase5_transfer.py` — `--seed`, `--deterministic` (+ flag sebelumnya)

**Artefak hasil:** `reports/improvement_v1/ocr_benchmark/` (CSV, log, `parseq_runs/`, `montages/`).

**Tidak diubah:** semua checkpoint lama, `reports/clean_manifest*.csv`, dataset, dan integrasi YOLO/SmartPark.

---

## 10. Cara Menjalankan

```powershell
# Baseline multi-seed deterministik (val-only)
& "D:\spocr-venv\Scripts\python.exe" scripts\improve_multiseed.py --seeds 42,43,44,45,46

# PARSeq fine-tune (dari venv terpisah)
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\train_parseq.py --epochs 80 --batch 16 --lr 1e-4 --seed 42 --tag parseq_ft_seed42

# Evaluasi PARSeq (val)
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\eval_parseq.py --split val --ckpt reports\improvement_v1\ocr_benchmark\parseq_runs\parseq_ft_seed42\best.pt

# Tabel perbandingan baseline vs PARSeq
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\compare_val.py --crnn artifacts\transfer_run_bench_seed42\ocr_model.pt --parseq reports\improvement_v1\ocr_benchmark\parseq_runs\parseq_ft_seed42\best.pt

# Smoke test
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\smoke_test.py
```

## 11. Status Eksperimen

- **Selesai & terukur**: audit nondeterminisme; perbaikan determinisme; replikasi baseline 5 seed; analisis per-domain; benchmark PARSeq vs baseline (2 seed PARSeq).
- **Gagal/negatif**: PARSeq **zero-shot** (CER 1.04) — butuh fine-tuning. (Tidak ada klaim keberhasilan dari zero-shot.)
- **Belum dijalankan**: evaluasi test independen; multi-seed PARSeq 3–5 run; benchmark deployment (ONNX/latency CPU); integrasi YOLO (di luar lingkup).
