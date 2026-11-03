# Fase 2: Preprocessing & Splitting Dataset Deteksi (YOLO Format)

## 1. Tujuan
Mempersiapkan dataset deteksi plat nomor kendaraan ke dalam standar Ultralytics YOLOv8, menerapkan pembagian data train/val/test berbasis kelompok identitas citra (*group splitting*) agar bebas dari kebocoran data, dan menyusun konfigurasi `data.yaml`.

---

## 2. Rincian Pekerjaan

### A. Group Splitting Bebas Leakage
1. **Pemisahan Berdasarkan Klaster Sumber**:
   - Split data: **80% Train**, **10% Validation**, **10% Test**.
   - Menggunakan hasil audit Fase 1 (`leakage_group_mapping.json`): file gambar yang berasal dari sumber sama atau augmentasi turunan (misal variasi hash Roboflow dari foto dasar yang sama) wajib dimasukkan ke dalam split yang sama.
2. **Pencatatan Manifest**:
   - Dokumentasikan daftar file per split dalam file manifes `detector_splits.json`.

### B. Konversi Anotasi COCO ke Format YOLO
1. **Normalisasi Koordinat Bounding Box**:
   - Format asli COCO: $[x_{min}, y_{min}, w, h]$ dalam piksel absolut.
   - Format target YOLO: $[\text{class\_id}, x_{center}, y_{center}, w_{norm}, h_{norm}]$ ternormalisasi rentang $[0.0, 1.0]$.
   - Rumus konversi:
     $$x_{center} = \frac{x_{min} + w / 2}{W}, \quad y_{center} = \frac{y_{min} + h / 2}{H}$$
     $$w_{norm} = \frac{w}{W}, \quad h_{norm} = \frac{h}{H}$$
   - Single class ID: `0` (`license_plate`).
2. **Penanganan Citra Negatif (Negative Samples)**:
   - Untuk citra tanpa plat nomor (misal latar belakang jalan raya atau kendaraan yang platnya tidak tampak), buat file `.txt` kosong dengan nama identik di folder label. Hal ini esensial untuk menekan *False Positive* pada model deteksi.
3. **Pembersihan Anotasi Cacat**:
   - Bounding box dengan luas $\le 0$ atau koordinat di luar dimensi citra dibersihkan/diclamp secara otomatis.

### C. Penyusunan Struktur Folder & `data.yaml`
1. **Struktur Direktori**:
   ```text
   yolo_dataset/
   ├── images/
   │   ├── train/
   │   ├── val/
   │   └── test/
   ├── labels/
   │   ├── train/
   │   ├── val/
   │   └── test/
   └── data.yaml
   ```
2. **Spesifikasi `data.yaml`**:
   ```yaml
   path: ./yolo_dataset
   train: images/train
   val: images/val
   test: images/test
   names:
     0: license_plate
   ```

### D. Verifikasi Visual Bounding Box
- Render minimal 20 citra hasil konversi dengan bounding box yang digambar ulang dari file `.txt` untuk memastikan tidak ada pergeseran titik koordinat atau kesalahan normalisasi rasio.

---

## 3. Checklist & Status Eksekusi Fase 2

| No | Tugas / Checklist | Status | Detail Temuan & Output |
| :---: | :--- | :---: | :--- |
| 1 | Pembagian dataset Group Splitting bebas leakage (80/10/10) | **REVISI (v3/v4)** | Skema v2 (`per nama file`) menghasilkan **1.377 grup untuk 1.377 citra** — praktis split per-gambar. **Dua metrik kebocoran, keduanya diukur:** (a) *kedekatan temporal* — 147 dari 420 pasangan frame CCTV bertetangga (indeks $\pm 2$) jatuh di split berbeda; skema v3 `chunk 8 frame` menurunkannya ke **23/420 (5,5%)**; (b) *near-duplicate dHash* — 4.713 pasangan pada Hamming $\le 6$, lintas split **1.647 → 1.592** (34,95% → 33,78%). Setelah ditelusuri (v4), kebocoran (b) **bukan** duplikat augmentasi: distribusi jarak Hamming rata dan pasangan $d=0$ seluruhnya CCTV↔CCTV dari kamera statis yang sama. Ini properti domain, tidak dapat dihilangkan dengan regrouping. Rincian di §6. |
| 2 | Konversi anotasi COCO ke format normalisasi YOLO | **SELESAI** | 2.128 bounding box berhasil dikonversi ke format `.txt` ($0.0 - 1.0$). |
| 3 | Penanganan citra negatif (*negative samples*) | **REVISI (v3)** | 5 citra tanpa plat dibuatkan file label `.txt` kosong. Pada v2 kelimanya jatuh di train sehingga *false positive* tidak terukur di val/test; v3 menyebarnya **3/1/1**. |
| 4 | Pembuatan struktur direktori `images/` dan `labels/` | **SELESAI** | Struktur standar Ultralytics tersusun rapi di `/kaggle/working/yolo_dataset/`. |
| 5 | Konfigurasi file `data.yaml` | **SELESAI** | Jalur dataset dan kelas `0: license_plate` berhasil dibuat. |
| 6 | Verifikasi visual bounding box hasil konversi | **SELESAI** | v3 memvisualisasikan **20 sampel** (sesuai spesifikasi §2D), naik dari 4 sampel di v2. |
| 7 | Manifest split | **BARU (v3)** | `detector_splits.json` — berisi skema, seed, jumlah per split, statistik stratified, dan hasil verifikasi kebocoran. Dikonsumsi oleh Fase 3 v5. |
| 8 | Laporan bbox suspect | **BARU (v3)** | `suspect_boxes.json` mendaftarkan bbox `ar < 1.5` atau tinggi `< 8 px` untuk diputuskan setelah audit visual Fase 1. **Tidak ada bbox yang dihapus** di tahap ini. |

> **Tautan Eksekusi Notebook Kaggle:**  
> [detection-indonesian-plate-prep-detector (v6)](https://www.kaggle.com/code/singgihwahyupermana/detection-indonesian-plate-prep-detector) — skema `chunk8`, seed 42.
---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- Dataset deteksi tersusun rapi sesuai struktur standar Ultralytics YOLO.
- Tidak ada kebocoran citra turunan antar-subset (Train/Val/Test terisolasi penuh).
  - **Diukur dengan dHash**, bukan diasumsikan. Target: pasangan near-duplicate lintas split $= 0$.
- File konfigurasi `data.yaml` valid dan siap dieksekusi oleh perintah `yolo detect train`.

---

## 5. Catatan Revisi v2 → v3
1. **Kenapa CCTV dipertahankan.** 219 citra `Cars*.png` adalah frame berurutan dari 4 segmen video (kamera A/B/C/D). Setelah dikelompokkan per 8 frame, kebocoran temporalnya terkendali. CCTV juga menyumbang ~42% bbox test sehingga tidak bisa diabaikan tanpa mengubah arti metrik.
2. **Kenapa `ar` rendah di CCTV belum dibersihkan.** 60,7% bbox CCTV punya `ar < 2,0` (RF: 0,4%). Belum terbukti apakah ini salah anotasi atau plat miring/plat motor. Keputusan menunggu audit visual (notebook `detection-indonesian-plate-label-audit`).
3. **Angka 633 klaster pada v2 tidak pernah cocok dengan eksekusi** (nyatanya 1.377 grup). Baris checklist v2 sudah diganti dengan angka hasil pengukuran.

---

## 6. Hasil Eksekusi v3 (terukur) & Temuan Terbuka

### Distribusi split

| Split | Citra | Bbox | Negatif | Citra CCTV | Bbox CCTV | Tinggi plat median (native) | Tinggi plat/frame median | `frac_h_native < 8px` |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| train | 1.096 | 1.697 | 3 | 171 | 696 | 15,0 px | 2,22% | 2,47% |
| val | 133 | 228 | 1 | 16 | 103 | 14,5 px | 2,08% | 1,32% |
| test | 148 | 203 | 1 | 32 | 86 | 16,5 px | 2,42% | 0,99% |

Artefak: `detector_splits.json`, `suspect_boxes.json` (199 bbox: 180 CCTV + 19 RF),
`verification_yolo_boxes.png` (20 sampel).

### ⚠️ Temuan terbuka: sifat kebocoran near-duplicate (hipotesis awal TERBANTAH)

Verifikasi dHash mengungkap bahwa hipotesis awal ("kebocoran berasal dari augmentasi
Roboflow di RF") **salah**. Bukti dari eksekusi v4:

**1. Distribusi jarak Hamming hampir rata** — bukan pola duplikat:

| Jarak Hamming | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Pasangan | 241 | 591 | 792 | 864 | 811 | 730 | 684 |
| Porsi | 5,1% | 12,5% | 16,8% | 18,3% | 17,2% | 15,5% | 14,5% |

Duplikat nyata akan menumpuk di $d = 0\text{--}2$. Distribusi yang rata menunjukkan
mayoritas dari 4.713 pasangan adalah **citra berbeda yang kebetulan mirip** (foto mobil
dengan komposisi/latar serupa), bukan duplikat.

**2. Contoh pasangan $d = 0$ seluruhnya CCTV ↔ CCTV**, bukan RF:

```text
d=0  Cars00101.png  <->  Cars00121.png
d=0  Cars00101.png  <->  Cars00131.png
d=0  Cars00101.png  <->  Cars00151.png
d=0  Cars00101.png  <->  Cars00701.png
```

Penjelasan: 219 frame CCTV berasal dari **4 kamera statis**. Latar belakang dan mobil
terparkir tidak berubah, sehingga frame-frame dari kamera yang sama menghasilkan dHash
yang nyaris identik meskipun berbeda waktu.

**3. Grouping berbasis klaster hash bersifat degeneratif** — tidak layak dipakai:

| Skema | Pasangan | Lintas split | Grup | Ukuran grup terbesar |
| :--- | ---: | ---: | ---: | ---: |
| `hash0` (+chunk8+stem) | 241 | 0,0% | 1.170 | **115** |
| `hash2` | 1.624 | 0,0% | 1.160 | **203** |
| `hash4` | 3.299 | 0,0% | 1.158 | **219** |
| `hash6` | 4.713 | 0,0% | 1.156 | **219** |
| `chunk8` (dipakai) | 4.713 | 33,8% | 1.186 | 8 |

Kebocoran 0% pada skema hash adalah **hasil palsu**: union-find melebur seluruh 219 frame
CCTV menjadi satu klaster raksasa, sehingga semua CCTV dipaksa masuk satu split. Split
menjadi kolaps — dan itu berarti test set kehilangan seluruh CCTV (persis masalah yang
muncul pada skema `chunk32`).

### Kesimpulan yang berlaku

Skema **`chunk8` tetap yang terbaik** (grup terbesar = 8, split seimbang). Kebocoran
dHash residual 33,8% **tidak dapat dihilangkan** dengan regrouping apa pun, karena
sumbernya adalah properti domain: frame kamera statis memang near-duplicate sepanjang
video. Pilihan yang tersisa:

- **(dipakai) `chunk8`** — grup kecil, split seimbang, kebocoran temporal 5,5%. Kebocoran
  dHash residual hanya memengaruhi metrik CCTV; metrik RF relatif bersih.
- **(ditolak) grup per kamera A/B/C/D** — hanya 4 grup CCTV; satu kamera jatuh ke satu
  split sehingga cakupan CCTV di test bisa nol.
- **(ditolak) klaster hash** — degeneratif, terbukti di tabel di atas.

**Implikasi untuk pelaporan:** angka Recall Fase 3 v5 pada strata CCTV harus dibaca
dengan catatan bahwa sebagian frame CCTV di test berasal dari kamera yang sama dengan
frame di train. Metrik strata **RF** tidak terpengaruh dan merupakan angka yang paling
dapat dipercaya.


### Artefak yang diproduksi
`detector_splits.json`, `suspect_boxes.json`, `verification_yolo_boxes.png`, dan
`yolo_dataset/` (images + labels + `data.yaml`) yang dikonsumsi Fase 3 v5.


