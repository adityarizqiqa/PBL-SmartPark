# Dokumentasi Proyek SmartPark-OCR

Catatan lengkap proses pembangunan model OCR plat nomor Indonesia (Indonesian License Plate Recognition) — dari audit dataset, training from-scratch, transfer learning, perluasan data, perbaikan decoding, audit kualitas, eksperimen resolusi, fine-tuning, stabilisasi evaluasi, sampai benchmark model pretrained (PARSeq) — beserta kondisi terkini dan rekomendasi lanjutan.

- **Tanggal dokumen**: 14 Oktober 2026
- **Root proyek**: `D:\CollegeFile\SMT 5\SmartPark-OCR`
- **Environment utama**: `D:\spocr-venv` (torch 2.6.0+cu124, cv2 5.0.0, PIL 12.3.0, numpy 2.2.6)
- **Environment benchmark PARSeq**: `D:\spocr-parseq-venv` (memakai ulang torch di atas + `timm`)
- **Perangkat**: GPU CUDA (RTX 2050, 4 GB)

> Catatan: dokumen ini adalah ringkasan naratif. Laporan per-tahap yang lebih rinci ada di `reports/improvement_v1/` (`audit_summary.md`, `resolution_report.md`, `phaseF_finetune_report.md`, `ocr_benchmark_report.md`).

---

## 1. Ringkasan Eksekutif

| Tahap | Pendekatan | Hasil utama (validation) |
|---|---|---|
| Baseline from-scratch | CRNN CNN + CTC | test CER 0.6675, EM 0/108 |
| Transfer learning | ResNet18 pretrained (`wp`) + CTC | test CER 0.5236, EM 1/108 |
| + TTA + greedy | decoding tambahan | test CER 0.5136 |
| Perluasan data (v2) | +355 crop baru (1399 data) | lebih buruk (test CER 0.6005) |
| Eksperimen resolusi | input 48×240 / 64×320 | lebih buruk keseluruhan |
| Fine-tuning / regularisasi | gradual unfreezing, weight decay | tidak meningkat |
| **PARSeq pretrained + fine-tune** | **transformer pretrained** | **val CER ~0.065, EM 64–66/105** |

**Kesimpulan utama (diperbarui):** hambatan utama **bukan** jumlah data, augmentasi, regularisasi, atau resolusi — melainkan **pilihan pendekatan OCR**. Mengganti CRNN from-scratch dengan **model pretrained (PARSeq) yang di-fine-tune** menurunkan validation CER dari ~0.56 menjadi ~0.065 (≈8.6× lebih baik) dan menaikkan Exact Match dari 0–1 menjadi 64–66 dari 105 plat. Peningkatan ini konsisten di kedua domain data, sehingga kesenjangan antar-domain yang sebelumnya menjadi masalah kini hilang.

---

## 2. Struktur Direktori

```
SmartPark-OCR/
├── plate_text_dataset/plate_text_dataset/    # dataset OCR
│   ├── dataset/                              # 1863 gambar
│   └── label.csv                             # 1863 label
├── plate_detection_dataset/plate_detection_dataset/
│   ├── images/                               # 1383 gambar deteksi
│   └── annotations/annotations.json          # anotasi COCO (plate_number)
├── scripts/                                  # semua script pipeline
│   └── benchmark/                            # toolkit benchmark OCR (PARSeq dll)
├── reports/                                  # laporan & manifest
│   └── improvement_v1/                       # seluruh hasil tahap perbaikan
├── artifacts/                                # checkpoint, log, evaluasi
├── kaggle/smartpark_ocr_training.ipynb       # notebook training Kaggle
└── yolov8n.pt                                # bobot YOLO (untuk detektor)
```

---

## 3. Dataset

### 3.1 Dataset OCR (teks plat)

`plate_text_dataset/plate_text_dataset/`:

- `label.csv`: **1863 baris** (`filename,label`)
- folder `dataset/`: **1863 gambar**
- **Verifikasi integritas**: 0 gambar tanpa label, 0 label tanpa gambar, 0 duplikat nama, 0 label kosong, semua karakter `A-Z0-9`.

**Distribusi panjang label:**

| Panjang | Jumlah |
|---|---|
| 4 | 2 |
| 5 | 14 |
| 6 | 55 |
| 7 | 1016 |
| 8 | 764 |
| 9 | 12 |

**Klasifikasi berdasarkan pola nama file:**

| Pola | Jumlah | Keterangan | Dipakai training? |
|---|---|---|---|
| `datatrain*` | 800 | crop plat lebar | ✅ |
| `*-<region>-...-*.rf.*` | 347 | crop deteksi (416×416) | ✅ |
| plain `PLAT.jpg` | 358 | foto motor utuh | ❌ |
| `*.rf.*` non-deteksi | 358 | foto motor utuh | ❌ |

**Hasil audit bersih** (`reports/dataset_audit_clean.json`):

- Kandidat crop: 1147 → setelah dedup md5: **1044**
- Dikecualikan (mobil utuh): **716** + duplikat persis: **103**
- Split bersih (grouped by label, no leakage): **train 831 / val 105 / test 108**
- Label leakage train-val & train-test: **0**

**Charset**: `ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789` (36 kelas) + blank (index 0) = **37 kelas**.

### 3.2 Dataset Deteksi (bounding box plat)

`plate_detection_dataset/plate_detection_dataset/`:

- `images/`: **1383 gambar** (1158 Roboflow `*.rf.*` 640×640 + 225 `Cars*.png`)
- `annotations/annotations.json`: COCO, **1377 gambar**, **2128 bounding box**, 1 kelas `plate_number`
- Catatan: 8 file `Cars*` belum teranotasi; 2 anotasi menunjuk file yang tidak ada.

**Temuan penting**: 358 gambar `rf_vehicle` yang dikecualikan dari OCR **ternyata ada di `annotations.json`** dengan bbox plat → bisa di-crop tanpa melatih detektor.

---

## 4. Arsitektur Model

### 4.1 Baseline from-scratch (`scripts/phase5_train.py`)

```
Input: grayscale 32×160
  ↓
CNN (dari nol): 4 lapis konvolusi + MaxPool + BatchNorm
  ↓
mean over height → sequence
  ↓
BiLSTM(256, 2 layer, bidirectional) → dropout 0.2
  ↓
Linear(512 → 37) + log_softmax
  ↓
CTC Loss (blank=0)
```

### 4.2 Transfer learning (`scripts/phase5_transfer.py`)

Backbone **ResNet18 ImageNet-pretrained**, dua varian:

- **`wp` (width-preserving)**: lebar sequence dijaga → output panjang `T = 40`. Ini yang terbaik.
- **`l2`**: hanya pakai lapisan awal pretrained → output `T = 20`.

Adaptasi input grayscale: bobot lapisan pertama dijumlahkan sepanjang channel agar menerima 1 channel.
Kepala: `BiLSTM(256, 2 layer)` → `Linear(512 → 37)` → CTC.

### 4.3 Model pretrained PARSeq (`scripts/benchmark/parseq_vendor`)

- **Jenis**: transformer encoder-decoder untuk scene text recognition (Permuted Autoregressive Sequence models), lisensi Apache-2.0.
- **Pretrained**: bobot STR publik (`parseq-bb5792a6.pt`), charset 94 karakter ASCII yang mencakup A–Z dan 0–9.
- **Fine-tuning**: pada dataset plat kita, memakai preprocessing native (RGB, 32×128) dan objective autoregresif.
- Alasan pemilihan: ringan (23,8 juta parameter), berjalan di GPU 4 GB, dukungan karakter alfanumerik, weights publik, dan kode model bisa di-*vendor* tanpa dependensi berat.

### 4.4 Preprocessing

- **CRNN**: grayscale → resize aspek-preserving tinggi 32 → zero-pad ke 32×160 → normalisasi.
- **PARSeq**: RGB → resize ke 32×128 → normalisasi (native).

### 4.5 Augmentasi

- **mild** (`aug`): rotasi ±2.5°, skala 0.92–1.08, brightness/contrast, Gaussian blur opsional.
- **strong** (`aug_strong`): perspective warp 5%, rotasi ±5°, skala 0.85–1.15, translasi, brightness, blur, noise.

---

## 5. Kronologi Eksperimen

### Fase 0 — Diagnosa awal (`step0_diagnose.py`, `step0b_converge.py`)

**Tujuan**: memastikan apakah masalahnya bug pipeline, label noise, atau keterbatasan data.

- **Sweep jumlah data**: CER turun konsisten dengan bertambahnya data → data adalah faktor utama.
  | N train | CER |
  |---|---|
  | 100 | 0.7407 |
  | 300 | 0.6592 |
  | 500 | 0.5937 |
  | 831 | 0.4141 |
- **Augmentasi A/B**: dengan augmentasi (0.4009) lebih baik daripada tanpa (0.4432).
- **Uji hafal** (500 epoch): model mencapai **train CER 0.0000, EM 831/831 (100%)**.

**Arti output**: model mampu menghafal seluruh data latih dengan sempurna → label konsisten (bukan label noise) dan pipeline tidak rusak. Masalah sesungguhnya adalah generalisasi ke data baru.

### Fase 1 — Audit dataset bersih (`phase2_audit.py`)

Membuat `reports/clean_manifest.csv` (1044 baris) dengan split stratifikasi tanpa kebocoran. Lihat §3.1.

**Arti output**: tersedia dataset bersih dan terpisah (train/val/test) yang bisa dipercaya untuk evaluasi.

### Fase 2–3 — Validasi pipeline (`phase34_validate.py`)

Semua pemeriksaan lolos: bentuk tensor, normalisasi, kosakata, rentang target, decoding CTC (collapse/repeat/blank), loss & gradient finite.

**Arti output**: perhitungan CTC dan decoding benar; tidak ada bug diam-diam pada alur data.

### Fase 4 — Uji overfit kecil (`overfit_test.py`)

24 sampel → **CER 0.0, EM 24/24 (100%)**.

**Arti output**: pada data sangat kecil, model bisa mencapai sempurna → arsitektur dan loss terbukti bisa belajar.

### Fase 5 — Training from-scratch (`phase5_train.py`)

`artifacts/clean_run_fresh/`: best val CER **0.6510**, **test CER 0.6675, EM 0/108**.

**Arti output**: model dari nol gagal generalisasi — CER tinggi di data uji.

### Fase 5b — Sweep transfer learning (`sweep_transfer.py`)

| Run | Backbone | val CER | test CER | test EM |
|---|---|---|---|---|
| `l2_lr1e3_bb03_strong` | l2 | 0.5825 | 0.6203 | 0/108 |
| `l2_lr3e4_bb01_strong` | l2 | 0.6231 | 0.6762 | 0/108 |
| **`wp_lr1e3_bb03_strong`** | **wp** | **0.4657** | **0.5236** | **1/108** |

**Arti output**: backbone pretrained (`wp`) menurunkan test CER dari 0.6675 → 0.5236 (≈21% relatif). Ini menjadi **baseline terbaik** saat itu.

### Fase 6 — Diagnosa final

Model **overfit** (hafal train, gagal generalisasi). Bukan bug preprocessing, BatchNorm, atau label noise. Semua tuas yang dicoba (pad/squash, tinggi 32/48, augmentasi, learning rate, epoch) mentok di CER ~0.65.

### Fase 7 — Perluasan data (`recover_crops.py`)

**Hipotesis**: 358 gambar `rf_vehicle` punya bbox di `annotations.json` → bisa di-crop untuk menambah data.

- Hasil: **355 crop** baru lolos verifikasi (semua label cocok, tidak ada duplikat, tidak ada kebocoran).
- Train 831 → **1186**; val/test tetap (test 108 utuh → pembanding tetap sah).

**Retrain** dengan konfigurasi `wp`:

| Metrik | Baseline (1044) | v2 (1399) |
|---|---|---|
| val CER | **0.4657** | 0.5470 |
| test CER | **0.5236** | 0.6005 |
| test EM | **1/108** | 0/108 |

**Analisis per-domain:**

| Domain | Baseline test | v2 test |
|---|---|---|
| datatrain (plat terang) | **0.4288** | 0.5604 |
| rf_detection (416² miring/blur) | 0.7331 | **0.6892** |

**Arti output**: menambah data **memperburuk** hasil secara keseluruhan. Data baru berasal dari domain berbeda (foto motor miring/HP) dibanding data lama (plat mobil terang). Model kehabisan kapasitas menyeimbangkan dua domain → domain utama turun jauh, domain kedua naik sedikit. Ini **pergeseran domain (domain shift)**, bukan label noise.

### Fase 8 — Perbaikan decoding (`eval_enhanced.py`)

| Mode | test CER | test EM |
|---|---|---|
| greedy (acuan) | 0.5236 | 1/108 |
| beam10 | 0.6030 | 0/108 |
| tta+beam10 | 0.5844 | 0/108 |
| **tta+greedy** | **0.5136** | 1/108 |
| ensemble 2 model | 0.6241 | 0/108 |

**Arti output**: beam search justru lebih buruk karena menghasilkan karakter berlebih (insertion) pada output CTC yang pendek. **TTA + greedy = perbaikan gratis terbaik (0.5136).**

---

### Fase 9 — Audit implementasi & baseline (14 Okt 2026)

**Tujuan**: memastikan baseline historis dapat direproduksi dan pipeline konsisten.

- Evaluasi ulang checkpoint terbaik → **test CER 0.5236 (greedy) / 0.5136 (TTA)** — **persis sama** dengan laporan historis.
- Verifikasi: checkpoint, kosakata, blank CTC, preprocessing, dan decoder konsisten antara training dan evaluasi.

**Arti output**: laporan historis memang dihasilkan oleh checkpoint dan kode yang benar. Baseline sah dijadikan acuan.

### Fase 10 — Audit visual seluruh dataset

- 1863 pasangan gambar-label diperiksa: **0 file hilang, 0 label kosong, 0 karakter ilegal, 0 label salah** (diverifikasi dengan melihat gambarnya langsung).
- Kategori kualitas: 987 crop layak, 716 foto kendaraan utuh, 75 gelap/blur, 69 terlalu kecil, 16 duplikat dekat.
- Split 831/105/108: **0 duplikat persis antar-split, 0 duplikat dekat antar-split, 0 kebocoran label**.

**Arti output**: dataset bersih dan split-nya dapat dipercaya. Tidak ada label noise sistematis, sehingga tidak ada alasan menyalahkan kualitas data.

### Fase 11 — Analisis kesalahan OCR

- Komposisi kesalahan pada baseline (val+test): **substitution 661, deletion 17, insertion 100**.
- Panjang prediksi hampir selalu benar → masalahnya **membedakan karakter**, bukan menghitung jumlah karakter.
- Karakter yang sering tertukar: pasangan digit/bentuk mirip (`8↔0`, `9↔1`, `6↔5`, `4↔3`, `T↔S`).
- Performa per-domain: `datatrain` ~0.41, `rf_detection` ~0.68.
- Temuan kunci: crop `rf_detection` (416×416) setelah preprocessing hanya menyisakan **~4,6 piksel per karakter** (vs `datatrain` ~13,7).

**Arti output**: model gagal karena kehilangan detail karakter (terutama pada plat berkonteks yang menyusut), bukan karena salah panjang atau bug. Ada kesenjangan jelas antar-domain.

### Fase 12 — Eksperimen resolusi (H48×240, H64×320)

| Run | val CER | datatrain CER | rf_detection CER |
|---|---|---|---|
| baseline 32×160 | **0.4657** | **0.3876** | 0.6637 |
| H48×240 (250 epoch) | 0.5343 | 0.5310 | **0.5426** |
| H64×320 (pilot) | 0.6599 | 0.6389 | 0.7130 |

**Arti output**: resolusi lebih tinggi **memperbaiki** domain sulit (`rf_detection` 0.66 → 0.54) tetapi **memperburuk** domain utama (`datatrain` 0.39 → 0.53), sehingga keseluruhan lebih buruk. Montage menunjukkan gambar H48 jauh lebih terbaca, namun prediksi tetap salah → **resolusi bukan akar masalah**. Baseline 32×160 dipertahankan.

### Fase 13 — Fine-tuning & regularisasi

- **Eksperimen A** (gradual unfreezing): val CER **0.5914**.
- **Eksperimen B** (weight decay lebih kuat): val CER **0.6003**.
- Pembanding: tiga run baseline segar menghasilkan **0.5609 / 0.5952 / 0.6193**.

**Arti output**: kedua strategi **tidak meningkatkan** generalisasi — hasilnya berada di dalam rentang variasi antar-run. Yang lebih penting: baseline historis 0.4657 **tidak dapat direproduksi**; performa wajar baseline lebih tinggi dari itu.

### Fase 14 — Stabilisasi evaluasi & replikasi multi-seed

- Penyebab nondeterminisme diidentifikasi (operasi cuDNN/CTC non-deterministik; seed GPU tidak lengkap).
- Ditambahkan mode deterministik (opsional). **Terbukti**: dua run identik menghasilkan angka yang sama persis.
- Baseline dijalankan dengan **5 seed**:

| Statistik | val CER |
|---|---|
| mean | 0.5579 |
| std | 0.0546 |
| min | 0.4530 |
| max | 0.6117 |

**Arti output**: performa asli baseline ≈ **0.56 ± 0.05**, bukan 0.4657 (angka itu ujung terbaik dari sebaran). Setiap perbandingan selanjutnya harus menyebut rentang ini agar tidak menyesatkan. Evaluasi sekarang dapat diulang dan dipercaya.

### Fase 15 — Benchmark model pretrained: PARSeq

**Uji awal (zero-shot)**: PARSeq tanpa fine-tuning → val CER **1.04, EM 0** (gagal total).

**Arti output zero-shot**: model pretrained generik tidak mengenali font/format plat Indonesia → **fine-tuning wajib**.

**Setelah fine-tuning** (hanya pada train, checkpoint dipilih dari validation):

| Model | val CER | val EM | datatrain CER | rf_detection CER |
|---|---|---|---|---|
| CRNN baseline (5 seed) | 0.5579 ± 0.0546 | 0.2 | — | — |
| CRNN baseline (terbaik) | 0.4530 | 1/105 | 0.3699 | 0.6637 |
| **PARSeq seed 42** | **0.0685** | **64/105** | 0.0779 | 0.0448 |
| **PARSeq seed 43** | **0.0647** | **66/105** | 0.0726 | 0.0448 |

**Arti output**:
- Validation CER turun drastis (~0.56 → ~0.065), Exact Match melonjak (0–1 → 64–66 dari 105).
- **Kesenjangan antar-domain hilang**: `rf_detection` turun 0.66 → 0.045 dan `datatrain` 0.39 → 0.07. PARSeq bahkan sedikit lebih baik pada domain yang tadinya paling sulit.
- Hasil **konsisten di dua seed** (0.0685 vs 0.0647), jadi peningkatan bukan kebetulan satu run.
- Biaya: model 1,66× lebih besar dan sedikit lebih lambat (~5–6 ms/gambar), masih sangat cepat untuk kebutuhan parkir.
- Sisa kesalahan berupa *near-miss* pada plat yang memang sulit/blur, bukan kegagalan sistematis.

**Ini adalah peningkatan nyata dan terukur, bukan klaim.**

---

## 6. Kondisi Saat Ini

### Model terbaik (kandidat utama)
- **Pendekatan**: PARSeq pretrained + fine-tune (`reports/improvement_v1/ocr_benchmark/parseq_runs/parseq_ft_seed42/best.pt`)
- **Performa (validation)**: CER ~0.065, Exact Match 64–66/105, konsisten di dua domain.
- **Catatan**: angka ini dari **validation**; test sengaja tidak dipakai untuk memilih model.

### Model cadangan (fallback ringan)
- **Checkpoint**: `artifacts/transfer_run_wp_lr1e3_bb03_strong/ocr_model.pt`
- CRNN ResNet18 pretrained + CTC; lebih kecil dan lebih cepat, tapi CER jauh lebih tinggi.

### Pola error
- **CRNN**: sering benar di awalan plat lalu salah digit tengah (substitution), terutama pada plat berkonteks kecil.
- **PARSeq**: hampir semua benar; sisanya salah tipis pada plat yang benar-benar blur/gelap.

### Peta artefak penting

| Path | Isi |
|---|---|
| `reports/clean_manifest.csv` | manifest 1044 data (baseline) |
| `reports/clean_manifest_v2.csv` | manifest 1399 data (v2) |
| `reports/improvement_v1/` | seluruh hasil tahap perbaikan (audit, resolusi, fine-tuning, benchmark) |
| `reports/improvement_v1/ocr_benchmark/` | benchmark PARSeq vs baseline (CSV, log, checkpoint, montage) |
| `reports/improvement_v1/ocr_benchmark/parseq_runs/` | checkpoint PARSeq hasil fine-tune |
| `artifacts/transfer_run_wp_lr1e3_bb03_strong/` | model CRNN terbaik (fallback) |
| `artifacts/transfer_run_bench_seed*/` | baseline multi-seed |
| `artifacts/cropped_plates/` | 355 crop recovered (Fase 7) |

### Script utama

| Script | Fungsi |
|---|---|
| `phase2_audit.py` | audit dataset → manifest bersih |
| `phase5_train.py` | training CRNN from-scratch |
| `phase5_transfer.py` | training CRNN + ResNet18 pretrained (+ mode deterministik) |
| `eval_by_pattern.py` | evaluasi per-domain |
| `eval_enhanced.py` | evaluasi greedy/beam/TTA/ensemble |
| `recover_crops.py` | crop dari anotasi COCO |
| `improve_*.py` | audit kualitas, analisis error, resolusi, multi-seed |
| `scripts/benchmark/train_parseq.py` | fine-tuning PARSeq |
| `scripts/benchmark/eval_parseq.py` | evaluasi PARSeq |
| `scripts/benchmark/compare_val.py` | tabel perbandingan baseline vs PARSeq |
| `scripts/benchmark/smoke_test.py` | uji cepat seluruh stack |

---

## 7. Pelajaran Kunci

1. **Pendekatan pretrained mengalahkan training from-scratch.** Model transformer pretrained yang di-fine-tune memberi lompatan terbesar (CER 0.56 → 0.065).
2. **Menambah data tanpa konsistensi domain bisa merugikan** (domain shift).
3. **Resolusi, regularisasi, dan fine-tuning bertahap tidak menyelesaikan masalah utama** — hanya memberi perubahan kecil atau bahkan memperburuk.
4. **Evaluasi harus multi-seed.** Angka terbaik satu run (0.4657) menyesatkan; performa wajar ≈ 0.56.
5. **Beam search tidak selalu lebih baik** untuk output CTC pendek.
6. **Verifikasi integritas data penting** dan terbukti: label ↔ gambar cocok 100%, split bersih.

---

## 8. Rekomendasi Lanjutan

1. **Adopsi PARSeq fine-tuned sebagai kandidat OCR utama** untuk SmartPark (dasar: CER ~0.065 vs ~0.56, EM 64–66 vs 0–1, konsisten dua domain).
2. **Simpan CRNN sebagai fallback ringan** — jangan dihapus.
3. **Evaluasi satu kali pada test set (108) atau data kamera baru** sebagai ukuran independen final, setelah keputusan model ditetapkan.
4. **Uji kestabilan PARSeq dengan 3–5 seed** dan protokol deterministik penuh.
5. **Uji efisiensi deployment** (ONNX/TensorRT, latency CPU) karena PARSeq sedikit lebih besar.
6. **Post-processing validasi format plat Indonesia** (awalan wilayah + panjang) untuk menaikkan Exact Match.
7. **Belum dilakukan / butuh persetujuan terpisah**: melatih detektor YOLO dan meng-crop seluruh foto kendaraan utuh (di luar lingkup OCR saat ini).

---

## 9. Cara Menjalankan Ulang

```powershell
# 1. Audit dataset → manifest bersih
& "D:\spocr-venv\Scripts\python.exe" scripts\phase2_audit.py

# 2. Training from-scratch
& "D:\spocr-venv\Scripts\python.exe" scripts\phase5_train.py --device cuda

# 3. Training transfer (CRNN + ResNet18)
& "D:\spocr-venv\Scripts\python.exe" scripts\phase5_transfer.py `
    --device cuda --backbone wp --lr 0.001 --backbone-lr-mult 0.3 `
    --strong-aug --epochs 300 --patience 60 --tag wp_best

# 4. Baseline multi-seed (deterministik, val-only)
& "D:\spocr-venv\Scripts\python.exe" scripts\improve_multiseed.py --seeds 42,43,44,45,46

# 5. Evaluasi enhanced CRNN (TTA + greedy)
& "D:\spocr-venv\Scripts\python.exe" scripts\eval_enhanced.py `
    --model artifacts\transfer_run_wp_lr1e3_bb03_strong\ocr_model.pt --split test --tta --show 20

# 6. Fine-tuning PARSeq (dari venv terpisah)
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\train_parseq.py `
    --epochs 80 --batch 16 --lr 1e-4 --seed 42 --tag parseq_ft_seed42

# 7. Evaluasi PARSeq (validation)
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\eval_parseq.py `
    --split val --ckpt reports\improvement_v1\ocr_benchmark\parseq_runs\parseq_ft_seed42\best.pt

# 8. Tabel perbandingan baseline vs PARSeq
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\compare_val.py `
    --crnn artifacts\transfer_run_bench_seed42\ocr_model.pt `
    --parseq reports\improvement_v1\ocr_benchmark\parseq_runs\parseq_ft_seed42\best.pt

# 9. Smoke test seluruh stack
& "D:\spocr-parseq-venv\Scripts\python.exe" scripts\benchmark\smoke_test.py
```

---

## 10. Peta Perubahan & Output Sementara

### Script baru (dibuat selama perbaikan)
- `scripts/recover_crops.py` — crop dari anotasi COCO (Fase 7)
- `scripts/eval_by_pattern.py` — evaluasi per-domain
- `scripts/eval_enhanced.py` — decoding greedy/beam/TTA/ensemble
- `scripts/improve_baseline_eval.py`, `improve_dataset_audit.py`, `improve_split_audit.py`, `improve_error_analysis.py`, `improve_build_manifest.py` — audit (Fase 9–11)
- `scripts/improve_res_smoke.py`, `improve_res_compare.py` — eksperimen resolusi (Fase 12)
- `scripts/improve_val_errors.py` — contoh kesalahan
- `scripts/improve_multiseed.py` — replikasi multi-seed (Fase 14)
- `scripts/benchmark/*` — toolkit PARSeq + benchmark (Fase 15)

### Script yang diubah (perubahan opsional, default tidak berubah)
- `scripts/phase5_transfer.py` — menambah dukungan resolusi (`--img-h/--img-w`), mode deterministik (`--seed/--deterministic`), gradual unfreezing (`--freeze-epochs/--unfreeze-at`), `--dropout/--weight-decay/--no-test`.

### Output sementara utama
- `reports/improvement_v1/` — audit, resolusi, fine-tuning, benchmark (CSV, JSON, log, montage).
- `reports/improvement_v1/ocr_benchmark/parseq_runs/` — checkpoint PARSeq hasil fine-tune.
- `artifacts/transfer_run_*` — checkpoint CRNN berbagai eksperimen.

### Catatan keamanan perubahan
- **Tidak ada** checkpoint, manifest, dataset, atau laporan lama yang dihapus/ditimpa.
- Semua eksperimen baru ditempatkan di direktori terpisah dengan nama jelas.
- Inference baseline lama diverifikasi masih berjalan.
- Integrasi YOLO/SmartPark tidak disentuh.
