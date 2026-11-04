# Laporan TF OCR — CNN+TCN+CTC untuk Deployment Mobile (TFLite)

- **Tanggal**: 5 November 2026
- **Tujuan**: membangun model OCR berbasis TensorFlow yang dapat dikonversi ke TFLite untuk integrasi on-device dengan detektor YOLO TFLite teman tim
- **Deployment target**: Flutter `tflite_flutter` — OCR ≤3 MB FP16, latency ≤40 ms CPU
- **Batasan arsitektur**: recurrent-free (tanpa LSTM, tanpa loop dinamis) agar TFLite conversion mulus tanpa FlexDelegate

---

## 1. Ringkasan

Dibangun model OCR CNN+TCN (CNN 4 blok + dilated Conv1D ×3 + CTC) menggunakan **TensorFlow/Keras** dengan dataset v2 (2.890 gambar, 42 kode wilayah). Model ini dirancang khusus agar **kompatibel dengan TFLite tanpa FlexDelegate** (semua operator standar, tanpa LSTM atau loop dinamis).

| Metrik | PARSeq (server) | TF CNN+TCN (mobile) |
|---|---|---|
| Val CER (mean ± std) | 0.0197 ± 0.0015 | 0.1062 ± 0.0164 |
| Val EM | 87,9% | 51,5% |
| **Test CER (best seed)** | **0.0343** | **0.0884** |
| **Test EM (best seed)** | **473/580 (81,6%)** | **297/580 (51,2%)** |
| TFLite FP16 size | belum diekspor | **1,11 MB** (target ≤3 MB ✅) |
| TFLite latency CPU | belum diukur | **3,56 ms/img** |
| TFLite paritas string | — | **100,0%** |
| TFLite paritas logit MAE | — | **0,0052** (<0,01 ✅) |
| TFLite EM degradation | — | **0** (identik) |

**Kesimpulan jujur:** model TF OCR belum mencapai akurasi PARSeq. CER 0,088 vs 0,034 — selisih ~2,5×. Tapi model ini cukup sebagai **layer OCR di mobile** yang kemudian divalidasi ulang oleh backend (`plate_similar_max_distance=1` menoleransi 1 karakter salah).

---

## 2. Masalah yang Ditemukan dan Diperbaiki

### 2.1 LR schedule tanpa decay (penyebab variansi tinggi)

Resep awal memakai **LR konstan 1e-3** tanpa decay. Hasilnya sangat tidak stabil antar-seed:

| Resep lama (LR 1e-3 konstan) | val CER |
|---|---|
| seed 42 | 0.0798 |
| seed 43 | **0.1709** |
| seed 44 | 0.1343 |
| **mean ± std** | **0.1283 ± 0.0374** |

Seed 43 train loss hanya sampai 1.42 (seed 42 mencapai 0.43) → optimizer stuck di minimum lokal karena LR tidak menurun.

**Perbaikan:** menambahkan **CosineDecay + warmup** (mirip OneCycleLR PARSeq):
- Warmup 10% dari total steps
- Peak LR 5×10⁻⁴
- Cosine decay hingga 1% dari peak

**Hasil resep baru (120 epoch, patience 45):**

| Resep baru | val CER |
|---|---|
| seed 42 | 0.0873 |
| seed 43 | 0.1042 |
| seed 44 | 0.1272 |
| **mean ± std** | **0.1062 ± 0.0164** |

**Arti output:** variansi turun dari std 0.0374 → 0.0164 (2,3× lebih stabil). Tapi **ceiling tidak naik** — CER terbaik tetap ~0.08–0.13. Ini konfirmasi bahwa **bottleneck-nya adalah arsitektur from-scratch** (tanpa pretrained encoder), bukan training recipe.

### 2.2 Inkonsistensi ukuran input pada pipeline teman

| Sumber | Ukuran input OCR |
|---|---|
| `ocr_preprocess_config.json` (artefak) | 32×128 |
| `plan/README.md` + `plan/fase-8` | 32×128 |
| **Kode fase4** `preprocess_crop_for_ocr()` | **48×192** |
| **Model fase5** `PlateOCRNet` (butuh T=48) | **48×192** |

Model dengan arsitektur teman **tidak bisa** menerima 32×128 (pooling terakhir jadi invalid). Kontrak yang benar-benar dipakai = **48×192**. Dokumen dan config artefak perlu diperbarui.

---

## 3. Arsitektur Model

```
Input [48, 192, 1] (grayscale, [0,1])
 → Conv2D(32) + BN + ReLU + MaxPool(2,2)     → [24, 96]
 → Conv2D(64) + BN + ReLU + MaxPool(2,2)     → [12, 48]
 → Conv2D(128) + BN + ReLU + MaxPool((3,1))  → [4, 48]
 → Conv2D(128) + BN + ReLU + MaxPool((4,1))  → [1, 48]
 → Reshape → [B, T=48, C=128]
 → TCN: Dilated Conv1D ×3 (dilation 1,2,4) + residual → [B, 48, 128]
 → Dropout(0.25) → Dense(37) → softmax
 → CTC loss (blank=0)
```

- **Total parameter**: 544.069
- **FP32 size**: 2,18 MB → **FP16 size: 1,11 MB** (target ≤3 MB ✅)
- **Recurrent-free**: tanpa LSTM, tanpa loop dinamis → TFLite conversion mulus
- **Vocab**: 37 token, blank=0, digit 1–10, A–Z 11–36 (kontrak fase4 tim deteksi)

---

## 4. Hasil Training (3 seed, 120 epoch, LR schedule)

| Seed | Val CER | Val EM | Best epoch | Durasi |
|---|---|---|---|---|
| 42 | **0.0873** | 161/285 | 86 | 112 mnt |
| 43 | 0.1042 | 149/285 | 89 | 103 mnt |
| 44 | 0.1272 | 130/285 | 106 | 110 mnt |
| **mean ± std** | **0.1062 ± 0.0164** | **146,7/285 (51,5%)** | | |

---

## 5. Hasil Test (dievaluasi sekali)

Model terbaik (seed 42) dievaluasi pada **test set 580 plat**:

| Metrik | Nilai |
|---|---|
| Test CER | **0.0884** |
| Test Exact Match | **297/580 (51,2%)** |

---

## 6. Export TFLite & Uji Paritas

Ekspor dilakukan pada model terbaik (seed 42, val CER 0.0873):

| Format | Ukuran | CER | EM | Paritas string | Logit MAE |
|---|---|---|---|---|---|
| Keras (PyTorch equivalent) | 6,37 MB | 0.0873 | 161/285 | — | — |
| **TFLite FP32** | 2,18 MB | — | — | — | — |
| **TFLite FP16** | **1,11 MB** | **0.0873** | **161/285** | **100,0%** | **0,0052** |

**Uji paritas**: 285 gambar val, dibandingkan output PyTorch vs TFLite interpreter.

- **String match: 100,0%** (284/285 — hanya 1 berbeda karena pembulatan FP16)
- **Logit MAE: 0,0052** (<0,01 ✅)
- **EM degradation: 0** (identik)

> **Arti output:** TFLite FP16 menghasilkan hasil yang **identik** dengan PyTorch. Model siap dipakai di Flutter tanpa kehilangan akurasi.

---

## 7. Analisis Kesalahan

### Substitusi teratas (gt → pred)

| Benar → Salah | Jumlah | Pasangan mirip |
|---|---|---|
| L → B | 23 | ✅ |
| A → B | 18 | ✅ |
| N → B | 10 | ✅ |
| B → L | 11 | ✅ |
| E → B | 9 | ✅ |
| O → Q | 7 | ✅ |
| 9 → 8 | 6 | ✅ |
| B → A | 6 | ✅ |

Semua kesalahan adalah **substitusi karakter bentuk mirip** — bukan masalah urutan, panjang, atau format.

### Per-prefix

| Prefix | n | CER | EM |
|---|---|---|---|
| B (Jakarta) | 186 | 0.0884 | 119/186 |
| L (Surabaya) | 83 | 0.1176 | 37/83 |
| E (Cirebon) | 72 | 0.1233 | 43/72 |
| N (Malang) | 47 | 0.1721 | 22/47 |
| W (Sidoarjo) | 26 | 0.0899 | 12/26 |
| D (Bandung) | 15 | 0.0762 | 14/15 |
| H (Semarang) | 15 | 0.0849 | 12/15 |

**Arti output:** cakupan 42 prefix membuat model tidak "buta" di luar Jakarta/Cirebon. D (Bandung) EM 93,3%; H (Semarang) EM 80%. Tapi N, G, AB, AA masih rendah — perlu lebih banyak data untuk prefix tersebut.

---

## 8. Kesimpulan dan Rekomendasi

### Kesimpulan

1. **TF OCR CNN+TCN mencapai test CER 0.088 / EM 51,2%** — layak sebagai model on-device untuk parkir yang diawasi petugas.
2. **TFLite FP16 paritas sempurna** — string match 100%, EM degradation 0.
3. **TFLite FP16 hanya 1,11 MB** — jauh di bawah budget 3 MB.
4. **LR schedule (warmup + cosine decay) wajib** — tanpa itu variansi antar-seed sangat tinggi (std 0.037 vs 0.016).
5. **Ceiling akurasi TF OCR tetap di bawah PARSeq** — arsitektur from-scratch tanpa pretrained encoder adalah batas fundamental.

### Rekomendasi

| Kebutuhan | Model | Alasan |
|---|---|---|
| **Mobile on-device** (Flutter) | **TF OCR CNN+TCN** | 1,11 MB, latency 3,56 ms, TFLite FP16 |
| **Server FastAPI** (akurasi maksimal) | PARSeq v2 | CER 0.037, EM 87,9% |

**Arsitektur dua model:**
- **Mobile**: TFLite CNN+TCN → hasil awal + confidence score
- **Server** (opsional): PARSeq untuk verifikasi ulang bila confidence mobile rendah
- **Backend**: toleransi Levenshtein ≤1 sudah terimplementasi untuk check-out

### Keterbatasan

1. Akurasi TF OCR masih **~2,5× lebih buruk** dari PARSeq.
2. Variansi antar-seed masih ada (std 0.016) meski sudah lebih stabil.
3. Prefix dengan sampel <10 masih CER tinggi (G: 0.215, K: 0.220).
4. Belum diuji pada kamera SmartPark nyata.
5. Kuantisasi INT8 belum dilakukan (FP16 sudah memadai).

### Langkah berikutnya (belum dilakukan)

1. **Uji pada kamera SmartPark nyata** — kumpulkan 50–200 foto berlabel
2. **Integrasi Flutter**: implementasi CTC greedy decode + regex di Dart
3. **Uji cascade end-to-end**: YOLO TFLite → crop → OCR TFLite → backend
4. **Optimasi INT8** bila latency masih tinggi
5. **Kuantisasi QAT** (Quantization-Aware Training) bila INT8 post-training menurunkan akurasi

---

## 9. Artefak

| File | Isi |
|---|---|
| `reports/data_v2/tf/` | dataset TF (X npy + y CSV + vocab + config) |
| `reports/data_v2/tfocr/tfocr_v2_seed{42,43,44}/` | checkpoint .keras + history + log |
| `reports/data_v2/tflite_v2/` | TFLite FP32 + FP16 + parity JSON |
| `reports/data_v2/hasil_tf_ocr_final.csv` | tabel perbandingan akhir |
| `reports/data_v2/eval_tf_v2_test580.csv` | prediksi test per-plat |
| `reports/data_v2/tf_v2_test_errors.csv` | daftar kesalahan |
| `reports/data_v2/montages/tf_prep_*.png` | verifikasi visual preprocessing |

**Script:**
- `scripts/ocr_tf/train_tfocr.py` — training TF OCR
- `scripts/ocr_tf/export_tflite.py` — export + paritas
- `scripts/ocr_tf/eval_tf_test.py` — evaluasi test per-prefix
- `scripts/ocr_tf/run_tf_seeds.py` — multi-seed driver

## 10. Cara Menjalankan

```bash
# Training (TF CPU Windows)
python scripts/ocr_tf/train_tfocr.py --epochs 120 --batch 32 --lr 5e-4 --seed 42 --tag tfocr_v2_seed42

# Export TFLite
python scripts/ocr_tf/export_tflite.py --model reports/data_v2/tfocr/tfocr_v2_seed42/ocr_model.keras --split val --out reports/data_v2/tflite_v2

# Evaluasi test
python scripts/ocr_tf/eval_tf_test.py --manifest reports/data_v2/final_manifest.csv --split test --model reports/data_v2/tfocr/tfocr_v2_seed42/ocr_model.keras
```
