// ============================ 8. Perubahan Lingkup dan Risiko ============================
#import "../template.typ": tbl, sec1, sec2, paragraf

#sec1(above: 1.83pt)[8. Perubahan Lingkup dan Risiko]

#sec2(above: 17.9pt)[8.1 Perubahan dari Proposal]

#paragraf(above: 3.9pt)[
  Perubahan judul, fitur, teknologi, jadwal, atau pembagian peran sejak proposal:
  \[Nyatakan tidak ada perubahan jika memang tidak ada, atau uraikan perubahan yang terjadi\].
  Alasan perubahan: \[Isi\]. Status konsultasi/persetujuan dosen: \[Isi\].
]

#sec2(above: 17.6pt)[8.2 Risiko Utama]

#tbl(
  above: 2.87pt,
  (162pt, 90.8pt, 190.4pt),
  ("Risiko", "Tingkat", "Tindakan Pencegahan / Mitigasi"),
  (
    ([Akurasi pembacaan plat dipengaruhi cahaya, sudut, blur, dan kualitas gambar.], [Sedang \[validasi tim\]], [Uji dengan variasi kondisi, sediakan koreksi manual dan scan ulang.]),
    ([Integrasi mobile, backend, dan pipeline ML terlambat.], [Sedang \[validasi tim\]], [Tetapkan kontrak API, integrasikan bertahap, dan uji setiap komponen.]),
    ([Dataset lokal atau izin pengambilan data belum memadai.], [Sedang \[validasi tim\]], [Pastikan izin dan privasi, serta evaluasi dataset publik yang sesuai.]),
    ([Skenario mismatch atau gangguan koneksi belum tertangani.], [Sedang \[validasi tim\]], [Prioritaskan test case kritis dan mekanisme retry/verifikasi manual.]),
    ([\[Tambahkan risiko aktual lainnya bila ada\]], [\[Tinggi/Sedang/\u{200b}Rendah\]], [\[Mitigasi\]]),
  ),
)

#paragraf(above: 2.53pt)[
  Tingkat risiko di atas masih berupa usulan awal berdasarkan ruang lingkup proposal dan harus
  dikonfirmasi oleh tim sesuai kondisi aktual.
]
