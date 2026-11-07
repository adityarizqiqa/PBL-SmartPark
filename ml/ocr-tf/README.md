# SmartPark OCR-TF — Plate Recognition untuk Mobile (TFLite)

Model OCR plat nomor Indonesia berbasis **TensorFlow/Keras** yang dioptimalkan untuk **on-device deployment** via TFLite. Dirancang untuk integrasi dengan **detektor YOLO TFLite** (`ml/deteksi-plat/fase8`).

- **Arsitektur**: CNN-2D + TCN (dilated Conv1D ×3) + CTC — **recurrent-free** (TFLite-safe tanpa FlexDelegate)
- **Data**: 2.890 gambar plat (42 kode wilayah Indonesia, 2.025 clean + 2.025 simulated train)
- **Hasil test 580 plat**: CER **0.0884**, Exact Match **297/580 (51,2%)**
- **TFLite FP16**: **1,11 MB** (target ≤3 MB ✅), **latency 3,56 ms** CPU, **paritas 100%**

> **Model PARSeq (CER 0.034, EM 81,6%) tetap tersedia sebagai fallback server-side** — lihat `ml/ocr/`.

---

## 1. Instalasi

```bash
python -m venv .venv
.venv\Scripts\activate

pip install -r requirements.txt
```

**Requirements** (lihat `requirements.txt`):
- `tensorflow-cpu` ≥ 2.15 (TFLite conversion + training CPU)
- `opencv-python-headless` (image I/O)
- `numpy < 2` (kompatibilitas TF 2.15)
- `pillow`
- `ultralytics` (hanya untuk smoke test integrasi YOLO, tidak wajib untuk OCR saja)

> **Catatan**: TensorFlow native Windows tidak mendukung GPU sejak v2.11 — training hanya di CPU. Untuk training GPU, gunakan WSL2 atau Kaggle (seperti pipeline teman di `ml/deteksi-plat`).

---

## 2. Struktur Repo

```
ml/ocr-tf/
├── checkpoints/
│   ├── ocr_model.keras              # checkpoint TF/Keras (6,4 MB)
│   ├── ocr_model_fp16.tflite        # ⭐ TFLite FP16 untuk Flutter (1,1 MB)
│   └── ocr_model_fp32.tflite        # TFLite FP32 (2,1 MB)
├── scripts/ocr_tf/
│   ├── train_tfocr.py               # training TF/Keras (CTC loss)
│   ├── export_tflite.py             # export FP32/FP16 + uji paritas
│   ├── eval_tf_test.py              # evaluasi test per-prefix + confusion
│   └── run_tf_seeds.py              # multi-seed driver
├── reports/
│   └── data_v2/                     # laporan, CSV hasil, montage, log
└── docs/
    ├── INTEGRASI_FLUTTER.md         # ⭐ panduan integrasi Flutter/Dart
    └── CARA_DOKUMENTASI.md
```

---

## 3. Hasil Model

| Metrik | Nilai |
|---|---|
| Val CER (3 seed, mean ± std) | 0.1062 ± 0.0164 |
| **Test CER (best seed)** | **0.0884** |
| **Test Exact Match** | **297/580 (51,2%)** |
| TFLite FP16 size | 1,11 MB |
| TFLite latency (CPU) | 3,56 ms/img |
| TFLite paritas (string match) | 100,0% |
| TFLite paritas (logit MAE) | 0,0052 (<0,01 ✅) |
| TFLite EM degradation | 0 (identik) |

---

## 4. Kontrak Input/Output

| Interface | Spek |
|---|---|
| **Input** | Grayscale `[1, 48, 192, 1]` float32, normalisasi `[0.0, 1.0]` |
| **Output** | Logits `[1, 48, 37]` float32 (CTC greedy decode di aplikasi) |
| **Vocab** | 37 token: `<blank>`=0, `0-9`=1–10, `A-Z`=11–36 (kontrak fase4 deteksi-plat) |
| **Preprocessing** | Grayscale → CLAHE (clip 2.0) → auto-crop tax line (AR < 1.8) → resize 48×192 → [0,1] |

> **Penting**: preprocessing di Flutter harus **identik** dengan training — perbedaan resize/normalisasi akan mengubah output. Lihat `docs/INTEGRASI_FLUTTER.md` untuk detail.

---

## 5. CTC Greedy Decode (Dart pseudocode)

```
logits = tflite.run(input_tensor)          // [1, 48, 37]
ids = argmax(logits, axis=-1)               // [48]

chars = []
prev = null
for id in ids:
    if id != prev and id != 0:             // 0 = blank
        chars.append(vocab[id])            // vocab: 0-9, A-Z
    prev = id

text = chars.join("")                       // "B1234XYZ"
```

---

## 6. Integrasi Cascade dengan YOLO

```
[Flutter camera] → frame BGR
  → YOLO TFLite detect → bbox [x1,y1,x2,y2]
  → crop + margin 8%
  → grayscale 48×192 [0,1]     (preprocessing Flutter)
  → OCR TFLite → logits [48,37]
  → CTC greedy decode → text
  → regex validasi → final plate
  → kirim ke backend (POST /check-in)
```

**Kontrak backend** (sudah terimplementasi di `backend/app/services/plate.py`):
- `normalize_plate(raw)` → uppercase, buang non-alnum
- `plate_similar_max_distance = 1` (Levenshtein) → check-out memperbaiki 1 karakter salah

---

## 7. Uji Cepat

```bash
# Verifikasi TFLite interpreter
python -c "
import tensorflow as tf, numpy as np
it = tf.lite.Interpreter('checkpoints/ocr_model_fp16.tflite')
it.allocate_tensors()
print('input:', it.get_input_details()[0]['shape'])
print('output:', it.get_output_details()[0]['shape'])
"

# Evaluasi test
python scripts/ocr_tf/eval_tf_test.py \
  --manifest reports/data_v2/final_manifest.csv \
  --model reports/data_v2/tfocr/tfocr_v2_seed42/ocr_model.keras
```

---

## 8. Limitasi

1. Akurasi **lebih rendah dari PARSeq** (test CER 0.088 vs 0.034) — ini konsekuensi arsitektur from-scratch tanpa pretrained encoder.
2. Variansi antar-seed masih ada (std 0.016) — gunakan multi-seed untuk pelaporan.
3. Prefix dengan sampel <10 masih CER tinggi (G: 0.215, K: 0.220).
4. Belum diuji pada **kamera SmartPark nyata** — seluruh angka dari dataset publik.
5. Kuantisasi INT8 belum dilakukan — FP16 sudah memadai untuk Flutter.
