// ============================ 5. Bukti Kemajuan ============================
#import "../template.typ": tbl, sec1, paragraf, uji

#sec1(above: 5.7pt)[5. Bukti Kemajuan]

#tbl(
  above: 4.77pt,
  (130.5pt, 216pt, 96.7pt),
  ("Jenis Bukti", "Tautan/Keterangan", "Status Akses"),
  (
    ([Repositori Git], [\[Masukkan URL GitHub/GitLab\]], [\[Uji akses publik\]]),
    ([Video demonstrasi (maks. 3 menit)], [\[Masukkan URL jika tersedia\]], [\[Uji akses\]]),
    ([Aplikasi yang di-deploy], [\[Masukkan URL jika tersedia; tulis belum tersedia bila belum deploy\]], [\[Uji akses\]]),
    ([Tangkapan layar fitur], [Lampiran A], [Dilampirkan dalam PDF]),
    ([Dokumen test case / QA], [\[Masukkan tautan atau nama berkas\]], [#uji]),
    ([Dataset/model ML dan hasil evaluasi], [\[Masukkan tautan atau nama berkas jika tersedia\]], [#uji]),
  ),
)

#paragraf(above: 28.53pt)[
  Pastikan semua tautan dapat dibuka oleh dosen tanpa meminta akses. Semua tautan eksternal juga
  dicatat kembali pada Lampiran E.
]
