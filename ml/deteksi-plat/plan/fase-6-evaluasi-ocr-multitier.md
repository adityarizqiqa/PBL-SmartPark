# Fase 6: Evaluasi Mendalam Model OCR (Multi-Tier & Confusion Matrix)

## 1. Tujuan
Mengevaluasi kemampuan model OCR (`best_ocr.pt`) secara terisolasi pada subset uji (*test set*) menggunakan pengujian **Multi-Tier** (Oracle Ground-Truth vs Simulated Crop vs Predicted Detector Crop), memetakan ambiguitas karakter via confusion matrix, dan menganalisis sensitivitas terhadap jenis plat nomor.

---

## 2. Rincian Pekerjaan

### A. Metodologi Evaluasi Multi-Tier
Untuk mengisolasi apakah kegagalan pembacaan disebabkan oleh kelemahan representasi OCR itu sendiri atau akibat distorsi bounding box dari detektor, evaluasi dilakukan pada 3 tingkatan data uji:

1. **Tier 1 — Oracle Crop (Ground-Truth Bounding Box)**:
   - Input: Potongan plat dari test set menggunakan koordinat manual ground-truth anotasi.
   - Mengukur kemampuan optimal (batas atas) model OCR tanpa gangguan kesalahan lokalisasi.
   - Metrik: CER (Character Error Rate) dan Exact Match (EM).
2. **Tier 2 — Simulated Imperfect Crop**:
   - Input: Potongan plat test set yang diberi gangguan acak terukur (pergeseran koordinat $5\text{--}15\%$, sedikit kemiringan, dan margin asimetris).
   - Mengukur ketahanan model OCR terhadap variasi pemotongan yang tidak sempurna.
   - Target: Penurunan EM terhadap Tier 1 tidak melampaui $7\%$.
3. **Tier 3 — Predicted Crop (Output Nyata Detector YOLO)**:
   - Input: Potongan plat yang dihasilkan langsung dari inferensi `best_detector.pt` pada citra test set deteksi.
   - Mengukur performa OCR ketika menerima input nyata dari detektor lapangan.
   - Metrik dihitung khusus pada plat yang berhasil dideteksi (True Positive BBox).

### B. Confusion Matrix Per Karakter
1. **Peta Ambiguitas Visual**:
   - Hitung matriks kontingensi 36 kelas karakter (`0-9, A-Z`) untuk mendeteksi pasangan karakter yang paling sering tertukar:
     - `0` vs `O` vs `D`
     - `8` vs `B`
     - `1` vs `I`
     - `5` vs `S`
     - `2` vs `Z`
2. **Perumusan Aturan Heuristik Posisi**:
   - Manfaatkan hasil matriks kesalahan ini untuk menyusun pemetaan cerdas pada Fase 7 (misalnya: jika token di tengah plat yang harusnya digit terprediksi `O` atau `D`, sistem otomatis mengoreksi ke `0`).

### C. Analisis Kegagalan Berdasarkan Karakteristik Plat
- Evaluasi performa pembacaan pada:
  - Plat hitam tulisan putih vs Plat putih tulisan hitam.
  - Panjang karakter (plat pendek 5–6 digit vs plat panjang 8–9 digit).
  - Simpan visualisasi 20 sampel gagal terburuk ke `ocr_failure_cases/`.

---

## 3. Checklist Eksekusi Fase 6
- [ ] Jalankan evaluasi Tier 1 (Oracle Ground-Truth Crop) pada test set.
- [ ] Jalankan evaluasi Tier 2 (Simulated Imperfect Crop).
- [ ] Jalankan evaluasi Tier 3 (Predicted Detector Crop) menggunakan bobot `best_detector.pt`.
- [ ] Generate confusion matrix per karakter alfanumerik.
- [ ] Analisis perbandingan akurasi plat latar hitam vs latar putih.
- [ ] Dokumentasikan visualisasi sampel gagal dan simpan metrik ke `ocr_multitier_metrics.json`.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- **Tier 1 (Oracle GT Crop)**: Exact Match $\ge 85\%$, CER $\le 0.06$.
- **Tier 2 (Simulated Crop)**: Degradasi Exact Match $\le 7\%$ dibandingkan Tier 1.
- **Tier 3 (Predicted Crop)**: Exact Match $\ge 78\%$, CER $\le 0.08$ pada plat yang terdeteksi.
- Tersedia tabel matriks ambiguitas karakter untuk modul koreksi post-processing.
