# Fase 4: Penyusunan Dataset OCR Realistis (Clean & Simulated Crops)

## 1. Tujuan
Menyusun dataset karakter plat nomor yang bersih dari ambiguitas label, mengunci fungsi preprocessing bersama (*shared preprocessor*), serta membekali dataset training OCR dengan variasi potongan citra nyata (*clean crop*) dan potongan simulasi ketidaksempurnaan detektor (*simulated detector crop*) agar model OCR tidak rapuh saat diintegrasikan.

---

## 2. Rincian Pekerjaan

### A. Sanitasi Label & Standardisasi Vocabulary
1. **Pembersihan String Label**:
   - Konversi seluruh karakter menjadi huruf kapital (`.upper()`).
   - Buang spasi, titik, strip, garis miring, dan karakter non-alfanumerik.
   - Contoh: `"B 1234 XYZ "` $\rightarrow$ `"B1234XYZ"`.
2. **Definisi Tokenizer & Kamus Karakter (`vocab.json`)**:
   - Total kelas: **37 token**.
   - **Index 0**: `CTC Blank` (`<blank>`).
   - **Index 1–10**: Angka `0` sampai `9`.
   - **Index 11–36**: Huruf `A` sampai `Z`.
   - Simpan mapping karakter $\leftrightarrow$ index ke dalam file acuan tetap `vocab.json`.

### B. Modul Preprocessing Citra Mandiri (Shared Preprocessor)
Untuk menjamin tidak ada perbedaan perlakuan citra (*train-inference skew*) antara lingkungan pelatihan PyTorch dan aplikasi Flutter:
1. **Logika Pemrosesan Citra Tunggal**:
   - Konversi ke Grayscale (1 channel).
   - Resize adaptif dengan mempertahankan aspect ratio asli plat:
     - Skala citra disesuaikan agar tinggi tepat 32 piksel, atau lebar maksimal 128 piksel.
     - Tambahkan padding hitam (nilai 0) pada sisi kanan dan bawah hingga dimensi tepat mencapai **$32 \times 128$**.
   - Normalisasi nilai piksel ke rentang $[0.0, 1.0]$ bertipe Float32.
2. **Artefak Modul**:
   - Tulis dalam skrip independen `preprocess_ocr.py` dan simpan spesifikasi ke `ocr_preprocess_config.json`.

### C. Pembentukan Komposisi Data OCR Realistis
Model OCR yang hanya dilatih pada crop manual yang presisi akan mengalami degradasi akurasi signifikan saat menerima bounding box hasil prediksi detektor yang mungkin sedikit meleset, miring, atau terpotong tepi hurufnya. Oleh karena itu, data training OCR disusun dari kombinasi dua sumber:

1. **Subset A: Clean Crops (Ground-Truth)**
   - Berasal dari citra `plate_text_dataset` dan potongan bounding box ground-truth dari subset training `plate_detection_dataset`.
2. **Subset B: Simulated Detector Crops (Perturbasi Geometri)**
   - Potongan plat yang sengaja diberi gangguan acak sebelum di-crop dari citra deteksi:
     - Pergeseran batas koordinat ($x_{min}, y_{min}, x_{max}, y_{max}$) sebesar $3\text{--}12\%$ dari lebar/tinggi plat.
     - Margin padding tidak simetris (sisi kiri $5\%$, sisi kanan $12\%$).
     - Rotasi ringan ($\pm 3^\circ$) dan sedikit blur untuk meniru getaran kamera mobile.
   - Rasio penggabungan di Train set: $60\%$ Clean Crops + $40\%$ Simulated Crops.

### D. Splitting Data OCR Bebas Leakage
1. Pisahkan dataset OCR dengan rasio: **Train (80%)**, **Validation (10%)**, **Test (10%)**.
2. Pastikan pengelompokan mematuhi `leakage_group_mapping.json` dari Fase 1.
3. Simpan manifest pembagian ke `train_ocr.csv`, `val_ocr.csv`, dan `test_ocr.csv` (berisi kolom: `image_path`, `clean_text`, `char_length`, `subset_type`).

---

## 3. Checklist Eksekusi Fase 4
- [ ] Buat skrip sanitasi teks dan verifikasi tidak ada karakter di luar 36 alfanumerik.
- [ ] Generate file kamus token resmi `vocab.json` (blank pada index 0).
- [ ] Buat dan uji modul shared preprocessor `preprocess_ocr.py` (output konsisten `[1, 32, 128, 1]`).
- [ ] Implementasikan generator simulasi imperfect crop (perturbasi koordinat & rotasi ringan).
- [ ] Buat manifest pembagian dataset bebas leakage (`train_ocr.csv`, `val_ocr.csv`, `test_ocr.csv`).
- [ ] Simpan visualisasi 20 sampel hasil pra-proses grayscale $32 \times 128$ untuk validasi rasio.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- Seluruh label pada manifest CSV hanya memuat karakter `0-9` dan `A-Z`.
- File `vocab.json` terkunci pada 37 kelas dengan blank di index 0.
- Dataset train OCR memuat variasi potongan citra bersih dan simulasi imperfect detector.
- Seluruh citra pra-proses berukuran seragam $32 \times 128$ piksel tanpa distorsi rasio font.
