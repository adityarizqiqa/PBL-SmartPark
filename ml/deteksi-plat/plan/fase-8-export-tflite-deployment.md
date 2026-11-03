# Fase 8: Export TFLite, Parity Testing & Integrasi Mobile (Flutter)

## 1. Tujuan
Mengonversi kedua model (`best_detector.pt` dan `best_ocr.pt`) ke format TensorFlow Lite (FP16), memverifikasi paritas numerik terhadap model asli PyTorch ($< 1\%$ penurunan metrik), menyusun skrip inferensi mandiri tanpa dependensi runtime berat, serta menyiapkan artefak dan kontrak deployment untuk aplikasi Flutter (`tflite_flutter`).

---

## 2. Rincian Pekerjaan

### A. Ekspor Model Deteksi (YOLOv8n) ke TFLite
1. **Pipeline Ekspor**:
   - Ekspor menggunakan Ultralytics exporter dengan kuantisasi FP16:
     ```python
     from ultralytics import YOLO
     model = YOLO("best_detector.pt")
     model.export(format="tflite", imgsz=640, half=True)  # atau quantize=16
     ```
2. **Spesifikasi Model Deteksi TFLite**:
   - File output: `plate_detector_fp16.tflite` (target ukuran $\le 6\text{ MB}$).
   - Input tensor: `[1, 640, 640, 3]` (Float32, normalisasi $[0.0, 1.0]$).
   - Output tensor: `[1, 5, 8400]` (format channel-first: $[cx, cy, w, h, \text{confidence}]$).
3. **Modul Standalone NMS**:
   - Karena embedding operator NMS ke dalam TFLite seringkali membutuhkan TensorFlow FlexDelegate (yang memperbesar binary app Flutter hingga 30–50 MB), NMS dieksekusi secara native di sisi aplikasi / skrip inferensi:
     - Filtering confidence threshold $\ge 0.40$.
     - Transpose koordinat box ke piksel absolut.
     - Non-Maximum Suppression (IoU threshold $0.45$).

### B. Ekspor Model OCR (CNN-2D + TCN) ke TFLite
1. **Pipeline Konversi Bebas FlexDelegate**:
   - Arsitektur OCR konvolusional murni menjamin konversi mulus tanpa custom ops:
   - *Tahap 1*: PyTorch $\rightarrow$ ONNX:
     ```python
     dummy_input = torch.randn(1, 1, 32, 128, dtype=torch.float32)
     torch.onnx.export(
         ocr_model,
         dummy_input,
         "ocr_model.onnx",
         input_names=["input"],
         output_names=["logits"],
         opset_version=13
     )
     ```
   - *Tahap 2*: ONNX $\rightarrow$ TFLite (via `onnx2tf` atau `tf.lite.TFLiteConverter`) dengan optimasi FP16.
2. **Spesifikasi Model OCR TFLite**:
   - File output: `plate_ocr_fp16.tflite` (target ukuran $\le 3\text{ MB}$).
   - Input tensor: `[1, 32, 128, 1]` (Float32, Grayscale, $[0.0, 1.0]$).
   - Output tensor: `[1, 32, 37]` (Logits probabilitas karakter).

### C. Pengujian Paritas Numerik (PyTorch vs TFLite)
1. Eksekusi 100 citra test set secara berdampingan antara model PyTorch dan model TFLite (`tflite_runtime`).
2. Hitung selisih numerik:
   - Mean Absolute Error (MAE) logits OCR harus $< 10^{-2}$.
   - Degradasi Exact Match (EM) pasca-kuantisasi harus $< 1\%$.
   - Selisih koordinat bounding box detector harus $< 2$ piksel.

### D. Standalone Inference Pipeline Wrapper
Menyusun file referensi Python `standalone_pipeline.py` yang hanya bergantung pada `numpy` dan `tflite_runtime`:
1. Menerima citra file / array mentah.
2. Melakukan resize letterbox ke $640 \times 640$ dan inferensi detector.
3. Eksekusi NMS dan ekstraksi BBox dengan margin adaptif $5\text{--}15\%$.
4. Memanggil shared preprocessor ke grayscale $32 \times 128$.
5. Inferensi OCR TFLite dan decoding CTC greedy.
6. Pemetaan heuristik posisi dan validasi regex plat nomor Indonesia.

### E. Profiling Latensi & Paket Handover ke Flutter
1. **Target Latensi Per-Komponen**:
   - Deteksi ($640 \times 640$): $\le 45\text{ ms}$ (NPU/GPU) / $\le 180\text{ ms}$ (CPU Mobile).
   - Crop & Preprocessing: $\le 5\text{ ms}$.
   - OCR ($32 \times 128$): $\le 15\text{ ms}$ (NPU/GPU) / $\le 40\text{ ms}$ (CPU Mobile).
   - CTC Decoding & Regex: $\le 2\text{ ms}$.
   - **Total Latensi End-to-End**: $\le 70\text{ ms}$ (NPU/GPU) / $\le 240\text{ ms}$ (CPU Mobile).
2. **Daftar Artefak Handover (`deploy_bundle/`)**:
   - `plate_detector_fp16.tflite`
   - `plate_ocr_fp16.tflite`
   - `vocab.json`
   - `ocr_preprocess_config.json`
   - `flutter_integration_guide.md` (dilengkapi pseudocode Dart untuk NMS dan CTC decoding).

---

## 3. Checklist Eksekusi Fase 8
- [ ] Export YOLOv8n ke `plate_detector_fp16.tflite` dan verifikasi ukuran file ($\le 6\text{ MB}$).
- [ ] Export OCR ke `plate_ocr_fp16.tflite` via ONNX dan verifikasi ukuran file ($\le 3\text{ MB}$).
- [ ] Uji kedua file TFLite untuk memastikan ketiadaan FlexDelegate ops.
- [ ] Jalankan script uji paritas numerik PyTorch vs TFLite pada 100 sampel.
- [ ] Bangun modul mandiri `standalone_pipeline.py` (`tflite_runtime` murni).
- [ ] Ukur waktu inferensi per-tahap dan dokumentasikan profil latensi.
- [ ] Kemas seluruh artefak siap deploy ke folder `deploy_bundle/`.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- Total ukuran kedua model $\le 9\text{ MB}$.
- Model dapat dijalankan secara mandiri tanpa dependensi PyTorch atau TensorFlow penuh.
- Penurunan metrik Exact Match akibat kuantisasi FP16 $< 1\%$.
- Seluruh spesifikasi input/output selaras dengan kontrak pipeline pada `README.md`.
