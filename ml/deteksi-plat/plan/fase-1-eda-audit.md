# Fase 1: Exploratory Data Analysis & Leakage Prevention Audit

## 1. Tujuan
Membedah integritas geometri anotasi, sebaran resolusi dan aspect ratio, sebaran frekuensi karakter, serta mengidentifikasi potensi kebocoran data (*cross-dataset leakage*) antara `plate_detection_dataset` dan `plate_text_dataset` sebelum dataset masuk ke jalur preprocessing masing-masing.

---

## 2. Rincian Pekerjaan

### A. Audit Dataset Deteksi (`plate_detection_dataset`)
1. **Verifikasi File Anotasi COCO (`annotations.json`)**:
   - Pengecekan konsistensi jumlah gambar fisik vs entri JSON.
   - Pengecekan anotasi tidak sah: $w \le 0$, $h \le 0$, koordinat negatif ($x_{min} < 0$, $y_{min} < 0$), atau melampaui batas citra ($x_{min} + w > W$, $y_{min} + h > H$).
   - Pendataan citra negatif (*background images* tanpa anotasi plat).
2. **Karakteristik Geometri Bounding Box**:
   - Distribusi resolusi citra ($W \times H$).
   - Distribusi rasio luas bounding box terhadap citra ($\frac{w \cdot h}{W \cdot H}$) untuk mengetahui sebaran ukuran objek (*small*, *medium*, *large*).
   - Distribusi aspect ratio ($w / h$) plat kendaraan.
3. **Analisis Asal Citra & Duplikasi**:
   - Identifikasi kelompok penamaan file (misal: Roboflow augmented `*.rf.*.jpg` vs file `Cars*.png`).
   - Hitung perceptual hash (pHash / dHash) untuk mendeteksi gambar duplikat atau variasi augmentasi dari sumber gambar yang sama.

### B. Audit Dataset Teks / OCR (`plate_text_dataset`)
1. **Verifikasi `label.csv`**:
   - Pengecekan nilai `NaN`, baris kosong, dan file gambar yang hilang.
   - Pengecekan karakter liar (spasi ganda, tanda baca, simbol aneh di luar alphanumeric).
2. **Distribusi Karakter & Panjang Plat**:
   - Histogram panjang teks plat (umumnya 5–9 karakter).
   - Distribusi frekuensi kemunculan tiap karakter (`0-9`, `A-Z`) untuk mendeteksi *class imbalance*.
3. **Karakteristik Citra Potongan Plat**:
   - Distribusi aspect ratio gambar crop ($W / H$).
   - Pengecekan resolusi ekstrem (misal citra dengan height $< 16$ px).
   - Identifikasi ragam polaritas kontras (plat hitam huruf putih, plat putih huruf hitam, plat kuning).

### C. Audit Kebocoran Lintas Dataset (Cross-Dataset Leakage Check)
Karena kedua dataset berasal dari koleksi *multi-sources*, ada risiko potongan plat di `plate_text_dataset` sebenarnya dipotong dari citra yang sama di `plate_detection_dataset`.
1. **Visual Matching**:
   - Lakukan image feature/hash comparison antara potongan bounding box `plate_detection_dataset` dengan gambar di `plate_text_dataset`.
2. **Pemetaan Grup Terisolasi**:
   - Catat pasangan duplikat ke dalam `leakage_group_mapping.json` agar pada fase splitting, citra-citra yang berkerabat ini tidak terpisah ke Train dan Test.

---

## 3. Checklist & Status Eksekusi Fase 1

| No | Tugas / Checklist | Status | Detail Temuan & Output |
| :---: | :--- | :---: | :--- |
| 1 | Parse & validasi koordinat di `annotations.json` | **SELESAI** | 1.377 citra terdaftar, 2.128 anotasi bbox. `0` bbox out-of-bounds / cacat. |
| 2 | Hitung statistik rasio geometris bounding box | **SELESAI** | Rata-rata aspect ratio plat: `2.97` (median `3.00`). Rata-rata luas plat terhadap citra mobil: `2.01%` (median `0.13%` — sebaran sangat miring). |
| 3 | Identifikasi citra negatif (*negative samples*) | **SELESAI** | Ditemukan `5` citra tanpa plat nomor (disiapkan file `.txt` kosong pada Fase 2). |
| 4 | Parse & validasi label teks di `label.csv` | **SELESAI** | 1.863 baris data teks diperiksa. `0` data kosong (NaN), `0` karakter liar/ilegal. |
| 5 | Plot sebaran panjang plat & frekuensi karakter | **SELESAI** | Panjang teks: min 4, median 7, max 9 karakter. File grafik disimpan: `char_distribution.png`. |
| 6 | Visualisasi sampel deteksi & potongan plat | **SELESAI** | 4 sampel acak (*random sampling*) berhasil divisualisasikan (`sample_detection_boxes.png`). |
| 7 | Export ringkasan audit data | **SELESAI** | Ringkasan metrik berhasil diekspor ke file `data_audit_summary.json`. |
| 8 | **Statistik geometri stratified per sumber** | **BARU** | Dua sumber punya rezim geometri yang berbeda dan tidak boleh dirata-ratakan: |
|   |   |   | **CCTV** (`Cars*.png`, 219 citra, 885 bbox, 1280x720): ar median `1.83`, 60,7% bbox `ar < 2.0`, tinggi plat median 13 px, tinggi plat/frame median **1,81%**, 95% citra multi-plat. |
|   |   |   | **RF** (`*.rf.*`, 1.158 citra, 1.243 bbox, 640x640): ar median `3.81`, 0,4% bbox `ar < 2.0`, tinggi plat median 19,5 px, tinggi plat/frame median **3,05%**, 6,7% citra multi-plat. |
| 9 | **Audit kualitas anotasi bbox** | **PENDING** | 60,7% bbox CCTV punya `ar < 2.0` padahal plat Indonesia memanjang (~3,8). Tren CCTV juga terbalik dari perilaku perspektif wajar (makin besar bbox makin persegi: ar 2,00 → 1,26), sedangkan RF normal (4,14 → 2,90). **Belum terbukti** apakah salah anotasi atau plat miring/plat motor. Uji duplikat internal sudah dijalankan: `0` dari 2.089 pasangan bbox dalam citra CCTV yang sama punya IoU > 0,3 — jadi bukan anotasi ganda. Keputusan menunggu notebook [`detection-indonesian-plate-label-audit`](https://www.kaggle.com/code/singgihwahyupermana/indonesian-plate-label-audit). |

> **Tautan Eksekusi Notebook Kaggle:**  
> [indonesian-plate-eda-and-audit (v6)](https://www.kaggle.com/code/singgihwahyupermana/indonesian-plate-eda-and-audit) — Status: `KernelWorkerStatus.COMPLETE`
>
> [detection-indonesian-plate-label-audit (v3)](https://www.kaggle.com/code/singgihwahyupermana/detection-indonesian-plate-label-audit) — **belum dijalankan** (`RUN_AUDIT = False`). Melengkapi item 9.
---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- Seluruh bounding box out-of-bounds terdata untuk diperbaiki atau dibersihkan.
- Karakter sah terkunci 36 token alfanumerik (`0-9, A-Z`) + 1 token `CTC Blank`.
- Pemetaan grup identitas citra duplikat/overlap selesai dibuat untuk acuan split di Fase 2 dan Fase 4.
  - **Revisi:** pHash/dHash **tidak** dihitung di notebook EDA v6. Verifikasi duplikat dipindah ke **Fase 2** (`detector_splits.json`), karena di situlah keputusan split diambil. `leakage_group_mapping.json` tidak diproduksi; perannya digantikan skema grouping `chunk8`.

