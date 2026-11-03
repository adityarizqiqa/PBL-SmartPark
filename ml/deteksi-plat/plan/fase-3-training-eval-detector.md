# Fase 3: Training & Evaluasi Model Deteksi (YOLOv8n)

## 1. Tujuan
Melatih model deteksi plat nomor (YOLOv8n) secara terisolasi menggunakan GPU Kaggle, melakukan hyperparameter tuning dengan prioritas utama pada metrik **Recall**, serta mengevaluasi performa deteksi secara komprehensif pada subset uji (*test set*).

---

## 2. Rincian Pekerjaan

### A. Konfigurasi Training & Optimasi Recall
Dalam arsitektur *cascade*, detektor adalah gerbang awal. Jika plat gagal dideteksi (*False Negative*), sistem OCR sama sekali tidak akan dipanggil. Oleh karena itu, target utama detektor adalah meminimalkan miss-rate (memaksimalkan Recall) dengan tetap menjaga False Positive pada batas yang wajar.

1. **Setup Eksperimen**:
   - Model dasar: `yolov8n.pt` (Nano weights, pre-trained COCO).
   - Resolusi input: $640 \times 640$ (fallback $416 \times 416$ jika profiling latensi di Fase 8 memerlukan optimasi lebih ketat).
   - Epochs: 50.
   - Batch size: 16 atau 32.
   - Optimizer: AdamW / SGD (`auto`).
2. **Augmentasi yang Disesuaikan**:
   - `mosaic`: 1.0 (melatih deteksi plat nomor pada berbagai skala citra).
   - `scale`: 0.5 (variasi jarak kamera ke plat nomor).
   - `degrees`: 5.0 (kemiringan sudut kamera).
   - `fliplr`: 0.0 (**dinonaktifkan** agar tidak menghasilkan orientasi teks terbalik yang membingungkan contextual cues).
   - `hsv_v` & `hsv_s`: 0.4 (variasi kondisi pencahayaan malam, terik, atau bayangan).

### B. Monitoring Training & Checkpointing
- Evaluasi metrik validasi di setiap epoch:
  - Box Loss & Cls Loss
  - Precision@0.50
  - **Recall@0.50** (prioritas utama)
  - mAP@50 dan mAP@50-95
- Simpan checkpoint model terbaik: `best_detector.pt`.

### C. Evaluasi Mendalam pada Test Set Independen
1. **Perhitungan Metrik Test Set**:
   - Jalankan `yolo detect val model=best_detector.pt data=data.yaml split=test`.
   - Hitung metrik komparatif pada berbagai ambang batas confidence (0.25, 0.40, 0.50, 0.75).
   - Analisis performa berdasarkan luas bounding box: *small*, *medium*, dan *large*.
2. **Error & Failure Analysis**:
   - Analisis sampel *False Negative*: Identifikasi penyebab plat tidak terdeteksi (sudut miring ekstrem, backlight, resolusi sangat rendah).
   - Analisis sampel *False Positive*: Identifikasi objek pengecoh (grille mobil, stiker bumper, rambu lalu lintas).
   - Simpan visualisasi 20 sampel deteksi gagal ke folder `detector_failure_cases/`.

---

## 3. Checklist & Status Eksekusi Fase 3

| No | Tugas / Checklist | Status | Detail Temuan & Output |
| :---: | :--- | :---: | :--- |
| 1 | Training YOLOv8n (GPU Kaggle) | **REVISI (v5)** | v3 memakai `imgsz=640`, `mosaic=1.0`, `scale=0.5`, 50 epoch, `cache=True` (gagal: `/kaggle/input` read-only). v5 memakai `imgsz=1280`, `mosaic=0.5`, `close_mosaic=20`, `scale=0.3`, `multi_scale=0.25`, `epochs=150`, `patience=30`, `cos_lr=True`, dan menyalin dataset ke `/kaggle/working` agar cache efektif. |
| 2 | Evaluasi resmi pada Test Set | **REVISI (v5)** | Angka v3 (`P@0.50=85,02%`, `R@0.50=86,47%`, `mAP@50=86,88%`, `mAP@50-95=52,86%`) **digantikan** dan hanya disimpan sebagai baseline historis. Angka itu diukur pada `imgsz=640`, di mana **76% bbox CCTV lebih kecil dari 8 px** — jadi sebagian besar mengukur batas fisika, bukan kemampuan model. |
| 3 | Analisis metrik vs acceptance criteria | **REVISI (v5)** | v3 tidak pernah menjalankan analisis yang diminta §2C (sweep ambang confidence, distribusi ukuran plat, agregat FN/FP, 20 sampel kasus gagal). Semuanya kini ada di v5. |
| 4 | Export ringkasan artefak evaluasi | **SELESAI** | `detector_eval_metrics.json` + kurva (`results.png`, `BoxPR_curve.png`). v5 menambahkan `stratified_at_op_conf`, `test_metrics_by_conf`, `failure_aggregate`, dan laporan ukuran model vs budget 6 MB. |
| 5 | **Metrik stratified per sumber** | **BARU (v5)** | `box_recall` + `img_detected_rate` + `mean_fp_per_img` dipecah per sumber (CCTV vs RF) dan per strata tinggi-plat-relatif (0-3%, 3-5%, 5-8%, >8%). Tanpa ini, satu angka agregat mencampur dua rezim skala yang berbeda. |
| 6 | **Verifikasi konvergensi** | **BARU (v5)** | Bukti v3 belum konvergen: `train/box_loss` masih turun di epoch terakhir (1,81 → 0,95) dan `val/box_loss` minimum justru di epoch 49 dari 50. |
| 7 | **Laporan ukuran model** | **BARU (v5)** | Parameter + estimasi FP16 dihitung dan dibandingkan dengan budget `plate_detector_fp16.tflite ≤ 6 MB`. |
| 8 | **Ablasi dengan vs tanpa CCTV** | **OPSIONAL (v5)** | `RUN_ABLATION=True` melatih model kedua tanpa citra CCTV lalu membandingkan keduanya pada test set yang sama. Ini menjawab dengan data apakah CCTV membantu atau menyeret performa. Default `False`. |

> **Tautan Eksekusi Notebook Kaggle:**  
> [detection-indonesian-plate-train-detector (v7)](https://www.kaggle.com/code/singgihwahyupermana/detection-indonesian-plate-train-detector) — **belum dijalankan** (`RUN_TRAINING = False`).
>
> Notebook ini butuh **Fase 2 v3** sebagai `kernel_sources` dan memverifikasi keberadaan `detector_splits.json` sebelum mulai; kalau tidak ada, ia memperingatkan bahwa split yang termuat masih versi lama.

---

## 4. Kriteria Keberhasilan (Acceptance Criteria)
- **Validation Set**: Recall@0.50 $\ge 90\%$, mAP@50 $\ge 0.88$.
- **Test Set**: Recall@0.50 $\ge 92\%$, mAP@50 $\ge 0.88$.
  - **Catatan penting:** angka tunggal ini perlu dibaca bersama strata. Detektor harus dilaporkan per sumber dan per strata ukuran; target $\ge 92\%$ tidak bermakna tanpa menyebut rezim skala mana.
- Tersedia checkpoint model valid `best_detector.pt` yang siap digunakan untuk menjembatani pembuatan dataset OCR di Fase 4.

---

## 5. Catatan Revisi v3 → v5

### Mengapa `imgsz` dinaikkan ke 1280

`imgsz=640` mengecilkan citra CCTV (1280x720) menjadi **separuh**. Plat yang aslinya 13 px
jadi 6,5 px, di bawah jangkauan minimum YOLO (stride P3 = 8 px). Karena citra CCTV
menyumbang ~40% bbox val/test, angka agregat v3 sebagian besar mengukur plat yang
memang mustahil dideteksi.

| imgsz | skala CCTV | CCTV < 8 px | CCTV < 16 px | skala RF | RF < 8 px | ALL < 8 px |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| 640 (v3) | 0,50 | 76,0% | 100% | 1,00 | 1,4% | 32,5% |
| 960 | 0,75 | 18,9% | 98,4% | 1,50 | 0,1% | 7,9% |
| **1280 (v5)** | **1,00** | **3,3%** | 76,0% | 2,00 | 0,1% | **1,4%** |
| 1600 | 1,25 | 1,8% | 37,3% | 2,50 | 0,1% | 0,8% |

`imgsz=1280` adalah titik di mana citra CCTV **tidak lagi dikecilkan** (skala 1:1).

> **Konsekuensi kontrak:** 1280 adalah $4\times$ FLOPs dibanding 640. Ukuran model FP16
> **tidak berubah** (itu arsitektur, bukan resolusi) sehingga budget $\le 6\text{ MB}$ aman,
> tetapi target latensi ($\le 70$ ms GPU / $\le 250$ ms CPU) perlu diukur ulang di Fase 8.
> Lihat catatan di `plan/README.md`.

### Mengapa `USE_P2` default `False`

`yolov8n-p2.yaml` tidak ada di repo Ultralytics; yang ada `yolov8-p2.yaml`, dan loader
Ultralytics menormalkan `yolov8n-p2.yaml` ke file itu dengan `scale='n'` — jadi secara
teknis bisa dipakai (stride minimum 8 → 4). **Tetapi** tidak ada bobot pra-latih COCO
untuk varian P2, artinya training dari scratch. Dengan ~1.000 citra latih, dari scratch
biasanya kalah dari fine-tune `yolov8n.pt`, dan P2 menambah parameter sehingga berisiko
melewati budget 6 MB. Naikkan `imgsz` dulu; pertimbangkan P2 hanya jika 1280 masih kurang.

### Ruang lingkup yang tidak diubah

CCTV **tetap dipakai**. Tidak ada data yang dibuang. Pembersihan bbox dibatasi pada
kandidat yang terdaftar di `suspect_boxes.json` dan hanya setelah audit visual Fase 1
membuktikan adanya salah anotasi.

