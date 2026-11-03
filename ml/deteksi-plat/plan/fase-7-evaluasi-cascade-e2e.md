# Fase 7: Evaluasi Cascade End-to-End & Analisis Bottleneck

## 1. Tujuan
Menggabungkan Model Deteksi (`best_detector.pt`) dan Model OCR (`best_ocr.pt`) ke dalam satu pipeline *cascade* utuh menggunakan PyTorch runtime, mengevaluasi akurasi menyeluruh pada citra penuh (*full frame* test set), menganalisis titik kegagalan (*bottleneck analysis*), serta menguji efektivitas modul post-processing regex dan pemetaan heuristik.

---

## 2. Rincian Pekerjaan

### A. Arsitektur Simulasi Pipeline End-to-End
Pipeline dijalankan dari file gambar utuh hingga menghasilkan teks string terverifikasi:
```text
Citra Utuh (640x640)
  ↓
YOLOv8n Detector (best_detector.pt)
  ↓
Bounding Box BBox [x1, y1, x2, y2]
  ↓
Margin Expansion (+5-15% margin adaptif)
  ↓
Crop & Shared Preprocessor (Grayscale, Resize Aspect-Preserving 32x128)
  ↓
OCR Model (best_ocr.pt)
  ↓
CTC Greedy Decoder
  ↓
Positional Heuristics & Regex Formatter Plat Indonesia
  ↓
Plat Final Tervalidasi + Combined Confidence
```

### B. Formulasi Metrik End-to-End Cascade
Metrik akurasi diukur secara transparan terhadap total populasi citra uji penuh, bukan hanya pada citra yang terdeteksi:

1. **Cascade Success Rate Breakdown**:
   - **Detector Success Rate ($R_{det}$)**:
     $$R_{det} = \frac{\text{Jumlah plat yang berhasil dideteksi dengan IoU} \ge 0.50}{\text{Total plat di ground-truth test set}}$$
   - **Conditional OCR Success Rate ($R_{ocr|det}$)**:
     $$R_{ocr|det} = \frac{\text{Jumlah plat dengan teks 100\% tepat}}{\text{Jumlah plat yang berhasil dideteksi}}$$
   - **Full End-to-End Exact Accuracy ($A_{e2e}$)**:
     $$A_{e2e} = \frac{\text{Jumlah citra dengan deteksi BENAR AND pembacaan teks 100\% TEPAT}}{\text{Total seluruh citra uji full frame}}$$
     $$A_{e2e} = R_{det} \times R_{ocr|det}$$

### C. Analisis Titik Lemah (Bottleneck Analysis)
Melakukan dekomposisi sumber kesalahan untuk menentukan prioritas perbaikan jika akurasi belum memenuhi target:
- Berapa persen kegagalan yang bersumber dari **Detektor** (False Negative atau box terpotong parah)?
- Berapa persen kegagalan yang bersumber dari **Crop Engine** (padding kurang lebar sehingga huruf pertama/terakhir hilang)?
- Berapa persen kegagalan yang bersumber dari **OCR** (karakter tertukar meskipun crop jelas)?
- Berapa persen kegagalan yang berhasil diselamatkan oleh **Post-Processing Heuristics**?

### D. Optimasi Modul Post-Processing
1. **Positional Character Mapping**:
   - Memetakan karakter berdasarkan zona plat Indonesia:
     - Area Huruf Depan (1–2 char): Karakter angka dikoreksi (`0` $\rightarrow$ `O`, `1` $\rightarrow$ `I`, `8` $\rightarrow$ `B`).
     - Area Angka Tengah (1–4 char): Karakter huruf dikoreksi (`O`/`D` $\rightarrow$ `0`, `I` $\rightarrow$ `1`, `B` $\rightarrow$ `8`, `S` $\rightarrow$ `5`).
     - Area Huruf Belakang (1–3 char): Koreksi angka ke huruf.
2. **Regex Validation Fallback**:
   - Regex pola plat nomor Indonesia: `^[A-Z]{1,2}[0-9]{1,4}[A-Z]{1,3}$`.
   - Tetapkan aturan fallback jika string tidak cocok dengan regex: tandai sebagai *unverified prediction* dan sertakan confidence score mentah.

---

## 3. Checklist Eksekusi Fase 7
- [ ] Susun skrip integrasi end-to-end `test_cascade_pipeline.py`.
- [ ] Jalankan simulasi penuh pada seluruh citra test set deteksi.
- [ ] Hitung $R_{det}$, $R_{ocr|det}$, dan $A_{e2e}$.
- [ ] Implementasikan modul positional heuristic mapping dan uji peningkatan akurasi (*accuracy gain*).
- [ ] Buat diagram visual dekomposisi bottleneck kegagalan pipeline.
- [ ] Export laporan metrik integrasi ke `cascade_e2e_metrics.json`.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- **Detector Recall@0.50 ($R_{det}$)**: $\ge 92\%$.
- **Conditional OCR Exact Match ($R_{ocr|det}$)**: $\ge 82\%$.
- **End-to-End Exact Accuracy ($A_{e2e}$)**: $\ge 75\%$ dari seluruh citra uji full frame.
- Skrip integrasi cascade terverifikasi menghasilkan output teks terformat dan siap diabstraksi ke format TFLite di Fase 8.
