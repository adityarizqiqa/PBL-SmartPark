#set document(
  title: "Pelatihan OCR dari Nol — SmartPark",
  author: "Tim SmartPark-OCR",
)
#set page(
  paper: "a4",
  margin: (x: 2.2cm, y: 2.0cm),
  numbering: "1",
  header: [
    #set text(size: 8pt, fill: gray)
    SmartPark-OCR — Pelatihan OCR dari Nol
    #h(1fr)
    #datetime.today().display("[day] [month repr:long] [year]")
  ],
)
#set text(size: 10pt, lang: "id")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.")
#show heading.where(level: 1): it => [
  #v(0.4em)
  #block(it)
  #v(0.1em)
]
#show raw.where(block: true): it => block(
  fill: luma(245), inset: 8pt, radius: 3pt, width: 100%, it
)

// ---------- Title page ----------
#align(center)[
  #v(3.2cm)
  #text(size: 22pt, weight: "bold")[Laporan Pelatihan OCR]
  #v(0.3em)
  #text(size: 17pt, weight: "bold")[Model Dibangun dari Nol (From-Scratch)]
  #v(0.3em)
  #text(size: 13pt)[Proyek SmartPark — Indonesian License Plate Recognition]
  #v(2.2cm)
  #line(length: 60%, stroke: 0.7pt + gray)
  #v(0.8cm)
  #text(size: 11pt)[
    Fokus: pelatihan CRNN + CTC tanpa bobot pretrained\
    beserta akurasi dan kendalanya
  ]
  #v(2.4cm)
  #text(size: 10pt, fill: gray)[
    Dokumen teknis internal\
    #datetime.today().display("[day] [month repr:long] [year]")
  ]
  #v(0.5cm)
]
#pagebreak()

// ---------- Ringkasan ----------
= Ringkasan Eksekutif

Dokumen ini membahas secara khusus *model OCR yang dibangun dan dilatih dari
nol* (tanpa bobot pretrained) untuk proyek SmartPark. Model ini adalah titik
tolak seluruh pekerjaan dan berfungsi sebagai *baseline* pembanding.

Model dibangun dengan arsitektur *CRNN (CNN + BiLSTM + CTC)* dan dilatih hanya
dengan 831 gambar plat yang tersedia. Hasilnya menunjukkan bahwa model dapat
*menghafal* data latih dengan sempurna, tetapi *gagal total* pada data baru.

#v(0.3em)
#align(center)[
  #table(
    columns: (1fr, auto, 1fr),
    inset: 6pt,
    align: (left, center, left),
    table.header([Metrik], [Nilai], [Arti]),
    [Train CER], [0.0000], [hafal sempurna (100% benar)],
    [Best val CER], [0.6510], [≈65% karakter salah],
    [*Test CER*], [*0.6675*], [*≈67% karakter salah*],
    [*Test Exact Match*], [*0/108*], [*tidak ada plat benar penuh*],
  )
]

#v(0.3em)
*Kesimpulan utama.* Akurasi model dari nol rendah karena *overfitting pada
dataset kecil* (831 sampel) ditambah *tidak adanya pengetahuan awal* (bobot
mulai acak). Model menghafal data latih alih-alih mempelajari pola umum plat.
Kendala ini dijelaskan rinci di Bagian 4.

#pagebreak()

// ---------- Konfigurasi ----------
= Konfigurasi Pelatihan

Pelatihan dilakukan dengan script `scripts/phase5_train.py`, seluruhnya dari
nol tanpa bobot pretrained.

#align(center)[
  #table(
    columns: (1fr, 1fr),
    inset: 5pt,
    align: (left, left),
    table.header([Komponen], [Nilai]),
    [Arsitektur], [CRNN: CNN 4 lapis + BiLSTM(256) ×2 + Linear],
    [Titik awal bobot], [acak (from-scratch)],
    [Input], [grayscale 32×160],
    [Jumlah kelas], [37 (A–Z, 0–9, + blank CTC)],
    [Loss], [CTC (blank = 0)],
    [Optimizer], [AdamW, lr 2×10⁻³],
    [Scheduler], [OneCycleLR],
    [Batch size], [64],
    [Epoch maksimum], [400 (early stopping patience 80)],
    [Seed], [42],
    [Data], [train 831 / val 105 / test 108],
  )
]

== Arsitektur ringkas

#align(center)[
  #table(
    columns: (auto, 1fr),
    inset: 5pt,
    align: (left, left),
    table.header([Tahap], [Keterangan]),
    [Input], [grayscale 32×160],
    [CNN], [4 lapis konvolusi + MaxPool + BatchNorm],
    [Sequence], [BiLSTM 256, 2 layer, bidirectional],
    [Output], [Linear → 37 kelas (A–Z, 0–9, + blank CTC)],
    [Loss], [CTC (blank = 0)],
  )
]

#pagebreak()

// ---------- Hasil ----------
= Hasil Pelatihan

== Akurasi akhir

#align(center)[
  #table(
    columns: (1.2fr, auto, 1fr),
    inset: 5pt,
    align: (left, center, left),
    table.header([Metrik], [Nilai], [Keterangan]),
    [Best val CER], [0.6510], [epoch 123],
    [Test CER], [0.6675], [≈67% karakter salah],
    [Test Exact Match], [0/108], [tidak ada plat benar penuh],
    [Prediksi kosong], [0], [model selalu mengeluarkan teks],
    [Durasi], [4,3 menit], [berhenti di epoch 203],
  )
]

*Arti output:* pada data uji, model salah sekitar dua per tiga karakter dan
*tidak satu pun* plat terbaca benar penuh. Angka ini adalah akurasi awal yang
menjadi pembanding seluruh perbaikan berikutnya.

== Uji hafal (kemampuan menyerap data latih)

Sebuah uji khusus dijalankan: model dilatih pada seluruh 831 data latih tanpa
augmentasi, hingga jauh lebih lama.

#align(center)[
  #table(
    columns: (auto, auto, auto),
    inset: 5pt,
    align: (center, center, center),
    table.header([Epoch], [Train CER], [Train EM]),
    [140], [0.0915], [582/831 (70,0%)],
    [180], [0.0002], [830/831 (99,9%)],
    [200], [*0.0000*], [*831/831 (100%)*],
  )
]

*Arti output:* model *mampu* menghafal seluruh data latih dengan sempurna. Ini
membuktikan pipeline tidak rusak dan label konsisten — masalahnya murni
*generalisasi* ke data baru.

#v(0.3em)
#figure(
  image("../artifacts/clean_run_fresh/training_curves.png", width: 100%),
  caption: [Kurva pelatihan model dari nol. Train loss turun terus ke ≈0,2,
  sedangkan validation CER berhenti membaik di ≈0,67 — jurang yang menandakan
  overfitting berat.],
)

#pagebreak()

// ---------- Pengaruh jumlah data ----------
= Pengaruh Jumlah Data

Untuk memastikan penyebabnya, model diuji dengan jumlah data latih berbeda
(semua konfigurasi lain tetap).

#align(center)[
  #table(
    columns: (auto, auto, 1fr),
    inset: 5pt,
    align: (center, center, left),
    table.header([N train], [CER], [Keterangan]),
    [100], [0.7407], [paling buruk],
    [300], [0.6592], [membaik],
    [500], [0.5937], [membaik],
    [831], [0.4141], [terbaik (semua data)],
  )
]

*Arti output:* CER turun konsisten saat data ditambah. Ini bukti kuat bahwa
*jumlah data* adalah faktor penentu — semakin banyak contoh, semakin baik model.
Dengan hanya 831 sampel, model belum cukup belajar pola umum.

== Pengaruh augmentasi

#align(center)[
  #table(
    columns: (1fr, auto),
    inset: 5pt,
    align: (left, center),
    table.header([Kondisi], [CER]),
    [Tanpa augmentasi], [0.4432],
    [Dengan augmentasi], [*0.4009*],
  )
]

*Arti output:* augmentasi (rotasi, skala, kecerahan, blur) sedikit menolong,
tetapi tidak mengubah gambaran besar.

#pagebreak()

// ---------- Kendala ----------
= Kendala Model dari Nol

Model gagal generalisasi karena beberapa kendala yang saling berkaitan:

+ *Dataset terlalu kecil (831 sampel).* Model hanya bisa *menghafal* (train CER
  0,0000) dan gagal pada data baru (test EM 0). Ini kendala utama.
+ *Tanpa pengetahuan awal.* Bobot dimulai dari angka acak, sehingga model harus
  mempelajari *semuanya* dari nol hanya dengan 831 contoh — berbeda dengan model
  pretrained yang sudah "tahu" cara mengenali bentuk karakter.
+ *Plateau di CER ≈0,65.* Validation CER berhenti turun dan tidak bisa
  ditembus, tidak peduli berapa lama dilatih.
+ *Kesalahan didominasi substitusi karakter mirip.* Pada test set: *substitusi
  424, penghapusan 14, sisipan 100*. Panjang prediksi hampir selalu benar →
  model tahu jumlah karakternya, tetapi gagal membedakan karakter yang mirip.
  #v(0.3em)
  #align(center)[
    #table(
      columns: (auto, auto),
      inset: 5pt,
      align: (center, center),
      table.header([Benar → Salah], [Jumlah]),
      [6 → 3], [10],
      [8 → 9], [9],
      [1 → 7], [8],
      [2 → 1], [8],
      [0 → 1], [8],
      [2 → 3], [8],
      [9 → 1], [8],
      [A → B], [7],
    )
  ]
  #v(0.3em)

+ *Domain `rf_detection` kehilangan detail.* Crop persegi 416×416 setelah
  praproses hanya menyisakan *≈4,6 piksel per karakter*, sehingga digit sulit
  dibedakan. Performa val: `datatrain` ≈0,65 vs `rf_detection` ≈0,66 (sama-sama
  rendah pada model ini).
+ *Tuas perbaikan in-scope tidak menembus plafon.* Praproses (pad/squash),
  tinggi input 32/48, augmentasi (mild/strong), learning rate, dan jumlah epoch
  semuanya mentok di CER ≈0,65.

== Contoh prediksi

#align(center)[
  #table(
    columns: (auto, auto),
    inset: 5pt,
    align: (left, left),
    table.header([Ground truth], [Prediksi model]),
    [A7814], [B1074XA],
    [AA1856CJ], [B1718TJZ],
    [B1248PC], [B111IE],
    [B1340UL], [B1031SU],
    [B1454EYF], [B1293TID],
    [A7692KC], [A1923QD],
    [B111HSN], [B171BAM],
    [B1040UN], [B1280UO],
  )
]

*Arti output:* model sering benar di awalan (`B1…`) tetapi salah di digit
tengah/akhir. Pola ini khas model yang *menghafal bentuk global* tanpa
memahami karakter satu per satu.

#pagebreak()

// ---------- Kesimpulan ----------
= Kesimpulan dan Langkah Perbaikan

== Kesimpulan

Model OCR yang dibangun dari nol mencapai *test CER 0,6675* dan *Exact Match
0/108*. Model dapat menghafal data latih sempurna (train CER 0,0000, EM
831/831), tetapi gagal total pada data baru. Akar masalahnya adalah
*kombinasi dataset kecil dan pelatihan dari nol*, bukan bug pipeline, label
salah, atau kesalahan praproses (ketiganya sudah diverifikasi bersih).

== Langkah perbaikan (berdasarkan bukti)

+ *Transfer learning.* Mengganti CNN from-scratch dengan backbone pretrained
  menurunkan test CER dari 0,6675 → 0,5236. Ini tuas paling cepat dan terbukti.
+ *Post-processing format plat.* Memanfaatkan pola `[1–2 huruf][4 digit][1–3
  huruf]` untuk memperbaiki prediksi yang salah satu karakter — murah dan
  menaikkan Exact Match.
+ *Backbone pretrained lebih kuat* (mis. ResNet34/50) — masih CRNN, tetapi
  "mata"-nya lebih tajam.
+ *Pelatihan sintetis.* Membuat ribuan plat buatan (font + variasi latar/sudut)
  sebagai *pretraining versi sendiri*, lalu fine-tune ke data asli. Ini
  menjawab langsung masalah dataset kecil, namun paling memakan waktu.
+ *Pendekatan pretrained penuh (PARSeq).* Terbukti jauh lebih unggul
  (CER ≈0,065) dan menjadi rekomendasi utama — dibahas di laporan terpisah.

== Catatan

- Angka pada laporan ini diambil langsung dari `artifacts/clean_run_fresh/`
  dan `reports/step0*`.
- Model dari nol tetap disimpan sebagai *baseline* dan cadangan ringan.

#v(1.0em)
#line(length: 100%, stroke: 0.5pt + gray)
#v(0.3em)
#text(size: 8.5pt, fill: gray)[
  Laporan ini adalah dokumen pendamping untuk pelatihan OCR from-scratch.
  Laporan utama (perbandingan CRNN vs PARSeq) tersedia di
  `reports/laporan_smartpark_ocr.pdf`.
]
