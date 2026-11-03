# Rencana Proyek: Sistem Deteksi & Pengenalan Plat Nomor Indonesia (On-Device Mobile)

## 1. Ringkasan Arsitektur (2-Stage Cascade Architecture)

Sistem dirancang sebagai **2-Stage Cascade Pipeline** terpisah:
1. **Track 1: Plate Detector (YOLOv8n)**: Bertugas mendeteksi koordinat lokasi plat nomor pada citra penuh (*full frame*). Dilatih, divalidasi, dan dievaluasi secara independen.
2. **Crop & Normalization Module**: Modul jembatan yang melakukan ekstraksi area plat dengan margin adaptif ($5\text{--}15\%$) serta standarisasi citra ke grayscale $32 \times 128$.
3. **Track 2: Plate Recognizer / OCR (CNN-2D + TCN + CTC)**: Bertugas membaca teks dari potongan plat terisolasi. Dilatih dengan data crop nyata ditambah simulasi *imperfect crop* agar kebal terhadap deviasi detector.
4. **Post-Processing & Formatting**: CTC greedy decoder, koreksi ambiguitas posisi karakter, dan validasi pola plat nomor Indonesia.

```mermaid
flowchart TD
    subgraph Track1 ["Track 1: Deteksi Plat (Fase 2 & 3)"]
        A[Full Frame RGB 640x640] --> B["Model 1: YOLOv8n Detector"]
        B -->|BBox & Confidence| C["BBox Pasca-NMS [x1, y1, x2, y2]"]
    end

    subgraph Bridge ["Bridge: Crop Engine"]
        C --> D["Crop + Padding Margin (+5-15%)"]
        D --> E["Resize Adaptif Grayscale 32x128"]
    end

    subgraph Track2 ["Track 2: Pengenalan Karakter OCR (Fase 4, 5, 6)"]
        E --> F["Model 2: CNN-2D + TCN + CTC Loss"]
        F -->|Logits [1, 32, 37]| G[CTC Greedy Decoder]
        G --> H[Raw String Karakter]
    end

    subgraph PostProcess ["Integrasi & Output (Fase 7 & 8)"]
        H --> I[Heuristic Char Mapping & Regex Parser]
        I --> J["Final Verified Plate Number + Confidence Score"]
    end
```

---

## 2. Dataset Sumber
- **Kaggle Dataset**: `linkgish/indonesian-plate-number-from-multi-sources`
  - `plate_detection_dataset`: 1.383 citra kendaraan + anotasi COCO (`annotations.json`).
  - `plate_text_dataset`: 1.863 citra potongan plat + `label.csv`.

---

## 3. Kontrak Data Antar-Modul (Pipeline Contracts)

Untuk mencegah *train-inference skew*, kontrak data dikunci sebagai acuan bersama antara training PyTorch dan runtime Flutter (`tflite_flutter`):

| Interface | Input Specification | Output Specification / Format |
|---|---|---|
| **Detector (Model 1)** | Citra RGB `[1, 640, 640, 3]`, normalisasi $[0.0, 1.0]$ | Bounding box `[x1, y1, x2, y2]` absolut, score $\ge 0.40$, single class `0: license_plate` |
| **Crop Bridge Module** | Full image + BBox | Crop diperluas margin $5\text{--}15\%$, aspect-preserving resize dengan padding ke `[1, 32, 128, 1]` |
| **OCR (Model 2)** | Grayscale `[1, 32, 128, 1]`, normalisasi $[0.0, 1.0]$ | Logits probabilitas karakter `[1, 32, 37]` |
| **CTC Decoder** | Tensor logits `[1, 32, 37]` | Raw string (CTC Blank pada index 0, vocabulary: `0-9, A-Z`) |
| **Post-Processor** | Raw string OCR | Format plat Indonesia tervalidasi (`^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$`) |

> ### ⚠️ Keputusan terbuka: resolusi input detektor (640 vs 1280)
>
> Kontrak `[1, 640, 640, 3]` di atas berasal dari asumsi bahwa plat selalu besar di dalam
> frame. Hasil audit dataset menunjukkan asumsi itu **tidak berlaku untuk 219 citra CCTV
> (1280x720)** yang menyumbang ~40% bbox val/test:
>
> | imgsz | skala CCTV | bbox CCTV < 8 px | bbox RF < 8 px | bbox ALL < 8 px |
> | :---: | :---: | :---: | :---: | :---: |
> | 640 | 0,50 | **76,0%** | 1,4% | 32,5% |
> | 1280 | 1,00 | **3,3%** | 0,1% | 1,4% |
>
> Pada 640, mayoritas bbox CCTV berada di bawah jangkauan minimum stride P3 YOLO (8 px).
> Karena itu **Fase 3 v5 dilatih dan dievaluasi pada `imgsz=1280`**.
>
> Dua jalur yang masih terbuka:
>
> - **Opsi A (latency tidak berubah).** CCTV dipertahankan sebagai *hard example* di
>   training, tetapi metrik produk didefinisikan pada strata close-range (mis. plat
>   $\ge 3\%$ tinggi frame) dan dilaporkan terpisah per sumber. Kontrak detektor tetap 640.
> - **Opsi B (CCTV harus akurat saat inference).** Kontrak detektor berubah menjadi
>   `[1, 1280, 1280, 3]` dan target latensi ($\le 70$ ms / $\le 250$ ms) direvisi.
>
> Yang **tidak** dianjurkan: latih pada 1280 lalu inference pada 640. Keuntungan resolusi
> datang dari tahap *inference*, bukan *training*; mismatch skala $2\times$ akan merugikan.
>
> Metrik stratified dari Fase 3 v5 (`stratified_at_op_conf` di `detector_eval_metrics.json`)
> adalah dasar untuk memutuskan A atau B.


---

## 4. Matriks 8 Fase Eksekusi Proyek

Training masing-masing model dipisahkan menjadi dua jalur independen lengkap dengan evaluasinya sendiri sebelum disatukan pada fase evaluasi cascade dan deployment:

| No | Fase Utama | Kategori | Deskripsi Singkat | Dokumen Panduan |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **EDA & Leakage Audit** | Persiapan Data | Audit anotasi, deteksi duplikasi pHash, dan pencegahan leakage antara dataset deteksi vs teks. | [Fase 1: EDA & Audit](fase-1-eda-audit.md) |
| **2** | **Prep Dataset Deteksi** | Track 1: Detector | Konversi COCO $\rightarrow$ YOLO txt, penyusunan `data.yaml`, dan isolasi train/val/test split. | [Fase 2: Prep Deteksi](fase-2-prep-dataset-detector.md) |
| **3** | **Training & Evaluasi Deteksi** | Track 1: Detector | Training YOLOv8n dengan prioritas Recall ($\ge 90\%$), mAP@50 $\ge 0.88$, dan error analysis BBox. | [Fase 3: Training Deteksi](fase-3-training-eval-detector.md) |
| **4** | **Prep Dataset OCR Realistis** | Track 2: OCR | Ekstraksi clean crop + sintesis imperfect crop simulation (perturbasi koordinat & margin variatif). | [Fase 4: Prep OCR](fase-4-prep-dataset-ocr.md) |
| **5** | **Training Model OCR** | Track 2: OCR | Training CNN-2D + Stacked Conv-1D (TCN) + CTCLoss dari scratch dengan asymmetric pooling ($T=32$). | [Fase 5: Training OCR](fase-5-training-ocr-recognizer.md) |
| **6** | **Evaluasi Multi-Tier OCR** | Track 2: OCR | Evaluasi 3 tingkat: Oracle GT crop vs Simulated crop vs Predicted detector crop + confusion matrix. | [Fase 6: Evaluasi OCR](fase-6-evaluasi-ocr-multitier.md) |
| **7** | **Evaluasi Cascade End-to-End** | Integrasi | Simulasi pipeline gabungan dari full frame, evaluasi bottleneck, dan toleransi post-processing regex. | [Fase 7: Evaluasi Cascade](fase-7-evaluasi-cascade-e2e.md) |
| **8** | **Export TFLite & Deployment** | Deployment | Kuantisasi FP16, standalone NMS, paritas numerik PyTorch vs TFLite, dan benchmark latensi mobile. | [Fase 8: Export TFLite](fase-8-export-tflite-deployment.md) |

### Status kernel per fase

| Fase | Kernel Kaggle | Versi | Status |
| :---: | :--- | :---: | :--- |
| 1 | `indonesian-plate-eda-and-audit` | v7 | `COMPLETE` |
| 1 | `detection-indonesian-plate-label-audit` | v4 | `COMPLETE` |
| 2 | `detection-indonesian-plate-prep-detector` | v7 | `COMPLETE` |
| 3 | `detection-indonesian-plate-train-detector` | v8 | `COMPLETE` (150 epoch, GPU T4) |
| 4 | `recognition-indonesian-plate-prep-ocr` | v3 | `COMPLETE` (2.861 sampel, 32x128) |
| 5 | `recognition-indonesian-plate-train-ocr` | v1 | `RUNNING` (60 epoch, GPU T4) |
| 6-8 | — | — | belum dibuat |

Notebook Track 1 (detektor) memakai prefix slug `detection-` supaya terpisah jelas dari
Track 2 (OCR) yang akan menyusul dengan prefix `recognition-`. Rename dilakukan in-place
lewat metadata (`title` + `id`), sehingga nomor versi dan riwayat run tidak hilang.
Lihat `AGENTS.md` untuk struktur direktori.

---

## 5. Target Metrik Keberhasilan Deployment
- **Total Ukuran Bobot**: $\le 10\text{ MB}$ (`plate_detector_fp16.tflite` $\le 6\text{ MB}$, `plate_ocr_fp16.tflite` $\le 3\text{ MB}$).
- **Detector Recall@0.50 (Test Set)**: $\ge 92\%$.
  - **Syarat pelaporan:** angka ini wajib disertai **strata sumber** (CCTV vs RF) dan
    **strata ukuran plat**. Dataset memuat dua rezim skala yang berbeda (tinggi plat/frame
    median 1,81% untuk CCTV vs 3,05% untuk RF); satu angka agregat mencampur keduanya dan
    tidak dapat ditafsirkan.
- **OCR Exact Match (Oracle GT Crop)**: $\ge 85\%$.
- **OCR Exact Match (Predicted Crop)**: $\ge 78\%$.
- **End-to-End Cascade Accuracy (Full Frame)**: $\ge 75\%$.
- **Target Latensi End-to-End**: $\le 70\text{ ms}$ (Mobile GPU/NPU) / $\le 250\text{ ms}$ (Mobile CPU).
  - **Tergantung keputusan terbuka di §3**: bila detektor memakai `imgsz=1280` (Opsi B),
    latensi naik $\approx 4\times$ pada tahap deteksi dan target ini harus direvisi.

