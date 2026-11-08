# Panduan Integrasi OCR dengan YOLO

Dokumen ini untuk anggota tim yang menangani **deteksi plat (YOLO)**. Tujuannya:
menyambungkan detektor dengan modul OCR tanpa mengubah kode OCR.

---

## 1. Kontrak Antarmuka (yang perlu dipenuhi)

Modul OCR hanya butuh **satu hal**: `numpy.ndarray` berisi crop plat.

| Parameter | Nilai |
|---|---|
| Format array | `np.ndarray`, shape `(H, W, 3)`, `dtype=uint8` |
| Urutan warna | **BGR** (default OpenCV / ultralytics). RGB juga bisa — modul konversi sendiri |
| Grayscale | Boleh, shape `(H, W)` |
| Ukuran minimum | 8×8 piksel |
| Rasio aspek | Bebas (di-*resize* ke 32×128 di dalam) |
| Padding | **8%** tiap sisi (disarankan) |

Modul **tidak** melakukan deteksi, tidak membaca file, dan tidak menyimpan state antar-request.

---

## 2. Langkah Integrasi

### Langkah 1 — Salin checkpoint

Minta dari tim OCR / ambil dari repo:

```
checkpoints/parseq_plate_best.pt
```

Taruh di folder `checkpoints/` pada service kamu.

### Langkah 2 — Muat model sekali saat startup

```python
from scripts.benchmark.predict import load_ocr

OCR_MODEL = load_ocr("checkpoints/parseq_plate_best.pt", device="cuda")
```

> **Jangan** memuat model per request — butuh ~2 detik dan ~500 MB VRAM.

### Langkah 3 — Panggil per frame

```python
import cv2
from ultralytics import YOLO
from scripts.benchmark.predict import predict_from_yolo_result

detector = YOLO("checkpoints/plate_detector.pt")

def read_plates(frame_bgr):
    result = detector.predict(frame_bgr, conf=0.25, verbose=False)[0]
    return predict_from_yolo_result(
        OCR_MODEL, result, image=frame_bgr,
        pad_ratio=0.08,        # margin crop
        conf_threshold=0.25,   # ambang deteksi
    )
```

### Langkah 4 — Tangani hasil

```python
plates = read_plates(frame)

if not plates:
    return {"status": "no_plate_detected"}

best = max(plates, key=lambda p: p["confidence"] * p["det_conf"])

if best["valid_format"] and best["confidence"] >= 0.85:
    status = "accepted"
else:
    status = "needs_manual_review"

return {
    "status": status,
    "plate": best["text"],
    "confidence": best["confidence"],
    "box": best["box"],
}
```

---

## 3. Referensi Fungsi

### `load_ocr(ckpt_path, device="cuda") -> PlateOCR`

Muat model sekali. Kembalikan objek yang bisa dipanggil.

- `ckpt_path` — path ke `.pt`
- `device` — `"cuda"` atau `"cpu"` (otomatis fallback ke CPU jika CUDA tidak ada)

### `PlateOCR.__call__(crop_bgr) -> dict`

Satu crop, satu hasil.

### `PlateOCR.predict_batch(crops) -> list[dict]`

Banyak crop sekaligus. **2–3× lebih cepat** daripada memanggil satu per satu. Gunakan ini bila ada beberapa plat per frame.

### `predict_from_yolo_result(ocr, yolo_result, image=None, pad_ratio=0.08, conf_threshold=0.25) -> list[dict]`

Membungkus alur `bbox → crop+padding → OCR`. `image` boleh `None` (pakai `result.orig_img`).

---

## 4. Field Output

| Field | Tipe | Contoh | Catatan |
|---|---|---|---|
| `text` | `str` | `"B1234XYZ"` | Sudah dinormalisasi, hanya A–Z dan 0–9 |
| `confidence` | `float` | `0.97` | Rata-rata probabilitas token. **Relatif**, bukan probabilitas absolut |
| `valid_format` | `bool` | `true` | Pola `[1–2 huruf][1–4 digit][1–3 huruf]` |
| `box` | `list[float]` | `[120,340,300,395]` | `[x1,y1,x2,y2]` dalam piksel frame asli |
| `det_conf` | `float` | `0.88` | Confidence dari YOLO |

---

## 5. Ambang yang Disarankan

| Parameter | Default | Alasan |
|---|---|---|
| `conf_threshold` (deteksi) | `0.25` | Ambang yang dipakai saat validasi internal |
| `confidence` (OCR) | `≥ 0.85` untuk auto-accept | Di bawah ini akurasi turun tajam pada data uji |
| `valid_format` | harus `true` untuk auto-accept | Filter murah untuk salah baca |
| `pad_ratio` | `0.08` | Meniru kondisi data latih |

> **Jangan** menurunkan `confidence` ke <0.7 untuk "mengejar" hasil — risiko salah baca plat tinggi dan berbahaya untuk transaksi parkir.

---

## 6. Kinerja

Diukur pada GPU RTX 2050 (4 GB):

| Komponen | Latency |
|---|---|
| YOLOv8n deteksi (640px) | ~20–30 ms |
| PARSeq OCR per crop | ~5–10 ms (batch) |
| **Total per frame (1 plat)** | **~30–40 ms** |

Di CPU: OCR ~40–80 ms per crop. Untuk >10 frame/detik, gunakan GPU.

---

## 7. Kesalahan Umum

| Gejala | Penyebab | Solusi |
|---|---|---|
| `text` kosong / aneh | crop bukan plat, atau terlalu kecil | naikkan `conf_threshold`, cek bbox |
| Karakter tepi hilang | tanpa padding | pakai `pad_ratio=0.08` |
| Confidence tinggi tapi salah | plat blur / karakter mirip (O↔0, I↔1) | aktifkan `valid_format` dan verifikasi manual |
| Render lambat | model dimuat per request | pindahkan `load_ocr` ke startup |
| `CUDA out of memory` | batch terlalu besar | turunkan ukuran batch di `predict_batch` |
| Hasil berbeda dari test | input bukan crop plat | OCR butuh **crop**, bukan frame penuh |

---

## 8. Uji Integrasi

Jalankan skrip yang sudah disediakan:

```bash
python scripts/benchmark/smoke_yolo_ocr.py \
  --yolo checkpoints/plate_detector.pt \
  --ocr checkpoints/parseq_plate_best.pt \
  --limit 10
```

Output yang diharapkan:

```
AA4103KN_....jpg  boxes=1 -> AA4103KN(0.91)
AA5045YN_....jpg  boxes=1 -> AA5045YN(0.94)

SMOKE RESULT: 10 images, 9 plate crops, 9 valid format
PASS
```

Jika muncul `WARN: detector produced no boxes`, berarti path model detektor salah atau `--conf` terlalu tinggi.

---

## 9. Checklist Go-Live

- [ ] Checkpoint `parseq_plate_best.pt` tersedia dan versi-nya dicatat
- [ ] Detektor final sudah dilatih pada data yang representatif (bukan model 3-epoch lokal)
- [ ] Smoke test lulus ≥ 80% crop valid
- [ ] Ambang `confidence` & `valid_format` diterapkan
- [ ] Ada jalur verifikasi manual untuk hasil di bawah ambang
- [ ] Latency terukur pada hardware produksi
- [ ] Diuji pada ≥ 50 foto kamera nyata dengan label ground truth

---

## 10. Menghubungi Tim OCR

Saat melaporkan masalah, sertakan:

1. File gambar asli (frame penuh)
2. `text`, `confidence`, `valid_format`, `box` yang dihasilkan
3. Teks plat yang seharusnya
4. Versi checkpoint yang dipakai
