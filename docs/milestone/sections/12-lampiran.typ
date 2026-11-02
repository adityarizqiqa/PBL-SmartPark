// ============================ 12. Lampiran ============================
#import "../template.typ": tbl, sec1, sec2, paragraf, url

#sec1(indent: 0pt, above: 23.8pt)[12. Lampiran]

#sec2(indent: 0pt, above: 17.9pt)[Lampiran A. Tangkapan Layar]

#paragraf(above: 3.9pt)[
  Masukkan tangkapan layar fitur yang sudah berjalan, misalnya halaman beranda, scan QR, input NIM
  manual, scan plat, hasil OCR, konfirmasi check-in, check-out, verifikasi manual, daftar sesi
  aktif, riwayat, serta respons API. Beri nomor dan keterangan pada setiap gambar. Jangan
  memasukkan gambar fitur yang belum benar-benar berjalan tanpa keterangan status prototipe.
]

#sec2(indent: 0pt, above: 17.5pt)[Lampiran B. Logbook Lengkap Minggu 1–8]

#paragraf(above: 3.9pt)[
  \[Gabungkan logbook lengkap tim untuk Minggu 1 sampai Minggu 8.\]
]

#sec2(indent: 0pt, above: 16.8pt)[Lampiran C. Dokumen Pendukung (Opsional)]

#paragraf(above: 3.9pt)[
  \[Tambahkan catatan konsultasi, dokumen pengujian, hasil training/evaluasi model, atau bukti
  pendukung lain bila tersedia.\]
]

#sec2(indent: 0pt, above: 17.8pt)[Lampiran D. Dokumen Tambahan Mata Kuliah]

#paragraf(above: 3.9pt)[
  \[Tambahkan dokumen tambahan yang diwajibkan oleh mata kuliah terintegrasi jika ada, dengan
  halaman pemisah sesuai ketentuan.\]
]

#sec2(indent: 0pt, above: 17.8pt)[Lampiran E. Daftar Tautan Eksternal]

#tbl(
  above: 2.57pt,
  (37.5pt, 112.5pt, 68.2pt, 142.6pt, 82.4pt),
  ("No.", "Keterangan", "Bagian", "Tautan", "Jenis Akses"),
  (
    ([1], [Repositori kode], [Bagian 5], [#url], [Publik / siapa saja dengan link]),
    ([2], [Video demonstrasi], [Bagian 5], [\[URL atau belum tersedia\]], [\[Jenis akses\]]),
    ([3], [Dokumen atau bukti eksternal], [\[Bagian terkait\]], [#url], [\[Jenis akses\]]),
  ),
)
