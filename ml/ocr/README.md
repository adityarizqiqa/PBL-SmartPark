# SmartPark OCR — Indonesian License Plate Recognition

Modul OCR (pengenalan teks plat nomor Indonesia) untuk sistem parkir otomatis **SmartPark**.

Menerima **crop plat** (hasil deteksi YOLO) dan mengembalikan teks plat beserta skor keyakinan.

- **Model**: PARSeq (transformer encoder–decoder, pretrained + fine-tune + augmentasi)
- **Kelas**: `A–Z`, `0–9` (charset ASCII, otomatis dinormalisasi)
- **Hasil (validation, 105 plat)**: CER **0.029**, Exact Match **85/105**
- **Hasil (test, 108 plat)**: CER **0.084**, Exact Match **64/108**
- **Lisensi model dasar**: Apache-2.0 (baudm/parseq)

---

## 1. Instalasi

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# Linux/macOS
source .venv/bin/activate

pip install -r requirements.txt
```

Butuh Python ≥ 3.10. GPU opsional — model berjalan di CPU juga (lebih lambat).

---

## 2. Cara Pakai (integrasi dengan YOLO)

### 2.1 Alur sistem

```
Kamera → YOLO (deteksi plat) → crop + padding → PARSeq (OCR) → validasi format → hasil
```

### 2.2 Kode integrasi

```python
import cv2
from ultralytics import YOLO

from scripts.benchmark.predict import load_ocr, predict_from_yolo_result

# Muat sekali saat service start (jangan per request)
detector = YOLO("checkpoints/plate_detector.pt")          # <- detektor milik tim YOLO
ocr = load_ocr("checkpoints/parseq_plate_best.pt", device="cuda")

# Per frame
frame = cv2.imread("foto_parkir.jpg")
result = detector.predict(frame, conf=0.25, verbose=False)[0]

plates = predict_from_yolo_result(ocr, result, image=frame, conf_threshold=0.25)
# -> [
#      {"text": "B1234XYZ", "confidence": 0.97, "valid_format": True,
#       "box": [x1, y1, x2, y2], "det_conf": 0.88},
#      ...
#    ]
```

### 2.3 Pakai crop langsung (tanpa helper YOLO)

```python
from scripts.benchmark.predict import load_ocr

ocr = load_ocr("checkpoints/parseq_plate_best.pt")

result = ocr(crop_bgr)            # crop_bgr: np.ndarray HxWx3 (OpenCV BGR)
print(result["text"])             # "B1234XYZ"
print(result["confidence"])       # 0.97
print(result["valid_format"])     # True

# Batch (lebih cepat, ~2-3x throughput)
results = ocr.predict_batch([crop1, crop2, crop3])
```

### 2.4 Output

| Field | Tipe | Keterangan |
|---|---|---|
| `text` | `str` | Teks plat, sudah dinormalisasi (A–Z, 0–9) |
| `confidence` | `float` | Rata-rata probabilitas token (0–1). **Bukan** kalibrasi absolut — pakai sebagai ambang relatif |
| `valid_format` | `bool` | Cocok dengan pola plat Indonesia `[1–2 huruf][1–4 digit][1–3 huruf]` |
| `box` | `list[float]` | Koordinat bbox YOLO `[x1,y1,x2,y2]` (hanya dari helper YOLO) |
| `det_conf` | `float` | Confidence detektor (hanya dari helper YOLO) |

### 2.5 Rekomendasi ambang (berbasis eksperimen)

- `det_conf ≥ 0.25` — ambang deteksi yang dipakai saat validasi.
- `ocr confidence ≥ 0.85` + `valid_format == True` → terima otomatis.
- Di bawah itu → masuk antrean verifikasi manual.

---

## 3. Source Data & Invarian

| Aspek | Nilai |
|---|---|
| Input OCR | crop plat (BGR atau grayscale) |
| Resolusi internal | 32×128, RGB, normalisasi [-1, 1] (ditangani `predict.py`) |
| Padding crop | **8%** di tiap sisi — sudah diterapkan helper YOLO |
| Ukuran crop minimal | 8×8 px (di bawah itu dilewati) |
| Multi-plat | Semua bbox di atas `conf_threshold` diproses |

> **Penting**: margin 8% meniru kondisi data latih. Tanpa margin, karakter di tepi plat bisa terpotong dan CER naik.

---

## 4. Struktur Repo

```
smartpark-ocr/
├── checkpoints/
│   ├── parseq_plate_best.pt          # model OCR final (91 MB)
│   └── parseq_pretrained_base.pt     # bobot pretrained dasar (91 MB)
├── scripts/
│   └── benchmark/
│       ├── predict.py                # ⭐ API integrasi (numpy crop)
│       ├── parseq_common.py          # model, preprocessing, metrik
│       ├── smoke_yolo_ocr.py         # uji end-to-end YOLO + OCR
│       ├── train_parseq.py           # fine-tuning
│       ├── eval_parseq.py            # evaluasi (CER/EM)
│       ├── eval_parseq_enhanced.py   # beam search / TTA
│       ├── eval_parseq_ensemble.py   # ensemble multi-seed
│       └── parseq_vendor/            # kode model PARSeq (Apache-2.0)
├── reports/                          # seluruh laporan eksperimen
├── docs/                             # panduan integrasi & dokumentasi
├── kaggle/                           # notebook pipeline awal
├── requirements.txt
└── README.md
```

---

## 5. Uji Cepat

```bash
# OCR pada satu gambar crop
python -m scripts.benchmark.predict \
  --ckpt checkpoints/parseq_plate_best.pt \
  --image path/to/plate_crop.jpg --json

# End-to-end YOLO + OCR pada beberapa gambar
python scripts/benchmark/smoke_yolo_ocr.py \
  --yolo checkpoints/plate_detector.pt \
  --ocr checkpoints/parseq_plate_best.pt --limit 5
```

---

## 6. Riwayat Model (ringkas)

| Model | val CER | val EM | test CER | test EM |
|---|---|---|---|---|
| CRNN from-scratch | 0.651 | 0/105 | 0.667 | 0/108 |
| CRNN + ResNet18 (transfer) | 0.4657 | 1/105 | 0.5236 | 1/108 |
| PARSeq fine-tune | 0.065 | 66/105 | — | — |
| **PARSeq + augmentasi (final)** | **0.029** | **85/105** | **0.084** | **64/108** |

Detail lengkap: `reports/laporan_smartpark_ocr.pdf`.

---

## 7. Limitasi yang Perlu Diketahui

1. Model dilatih pada **crop plat**, bukan frame penuh — deteksi tetap tanggung jawab YOLO.
2. Test set sudah dipakai **sekali** untuk evaluasi final; belum diuji pada data kamera nyata.
3. `confidence` bukan kalibrasi absolut — jangan dipakai sebagai probabilitas transaksi.
4. Gap validation (0.029) vs test (0.084) menunjukkan sebagian hasil dipengaruhi pemilihan checkpoint pada validation.
5. Belum ada dukungan multi-baris atau plat non-standar (mis. plat khusus/asing).

---

## 8. Lisensi & Kredit

- Model dasar **PARSeq** © 2022 Darwin Bautista — Apache-2.0, kode di-*vendor* pada `scripts/benchmark/parseq_vendor/`.
- Dataset: `plate_text_dataset` (multi-source), `plate_detection_dataset`.
