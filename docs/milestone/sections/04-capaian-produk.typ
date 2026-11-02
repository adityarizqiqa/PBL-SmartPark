// ============================ 4. Capaian Produk ============================
#import "../template.typ": tbl, sec1, sec2, paragraf, isi, statusFitur, cek

#sec1(above: 29.13pt)[4. Capaian Produk]

#sec2(above: 17.9pt)[4.1 Status Fitur]

#tbl(
  above: 2.37pt,
  (167.2pt, 104.3pt, 171.7pt),
  ("Fitur", "Status", "Catatan / Bukti"),
  (
    ([Beranda SmartPark], [#statusFitur], [\[Isi; sertakan bukti demonstrasi\]]),
    ([Pemindaian QR KTM dan input NIM manual], [#statusFitur], [#isi]),
    ([Pemindaian plat dan pembacaan OCR], [#statusFitur], [#isi]),
    ([Konfirmasi check-in dan pembuatan sesi aktif], [#statusFitur], [#isi]),
    ([Check-out berdasarkan plat dan pencarian fallback NIM], [#statusFitur], [#isi]),
    ([Verifikasi manual ketika hasil OCR meragukan/mismatch], [#statusFitur], [#isi]),
    ([Daftar kendaraan yang masih parkir], [#statusFitur], [#isi]),
    ([Riwayat sesi parkir dan pencarian], [#statusFitur], [#isi]),
    ([Penanganan kendala dan gangguan koneksi], [#statusFitur], [#isi]),
  ),
)

#sec2(above: 1.73pt)[4.2 Daftar Periksa Target Milestone 1]

#tbl(
  above: 4.47pt,
  (213pt, 108.8pt, 121.4pt),
  ("Target", "Status", "Catatan"),
  (
    ([Operasi tambah, baca, ubah, dan hapus data pada entitas utama berjalan], [#cek], [\[Jelaskan operasi yang telah berjalan\]]),
    ([Terintegrasi dengan basis data], [#cek], [\[Nama database/tabel dan bukti\]]),
    ([Data uji terisi], [#cek], [\[Jenis dan jumlah data uji\]]),
    ([Kemajuan terlacak terhadap WBS], [#cek], [\[Lokasi WBS/logbook\]]),
  ),
)

#sec2(above: 94.33pt)[4.3 Hasil Model Dasar dan Pengujian Tambahan]

#paragraf(above: 0pt, justify: true, keep: true)[
  Bagian hasil baseline ML dan QA Plan khusus jalur Semester 5 tidak diwajibkan berdasarkan
  identitas tim TI Semester 3 pada proposal. Meski demikian, hasil awal deteksi plat dan status
  skenario pengujian tetap dapat dicatat pada Bagian 4.1, 4.2, serta lampiran apabila sudah tersedia.
]

#sec2(above: 17.6pt)[4.4 Prototipe dan Antarmuka]

#paragraf(above: 3.9pt, justify: true)[
  Status antarmuka aplikasi: \[Isi kondisi aktual\]. Bandingkan layar yang telah dibuat dengan
  rancangan awal, lalu jelaskan perbedaan yang ada beserta alasannya. Sertakan tangkapan layar
  pada Lampiran A.
]
