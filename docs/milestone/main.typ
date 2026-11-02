// =============================================================================
// Laporan Kemajuan Project-Based Learning (PBL) — Milestone 1
// Tim SmartPark | Kelas TI-3E | Politeknik Negeri Malang
//
// Compile:
//   typst compile "docs/milestone/main.typ" "docs/MILESTONE PBL 1.pdf" --root .
//
// Struktur:
//   main.typ                 konfigurasi dokumen + daftar include
//   template.typ             helper tabel/judul/paragraf + konstanta placeholder
//   cover.typ                halaman judul
//   sections/01..12-*.typ    isi tiap bagian laporan
// =============================================================================

#import "template.typ": *

// Margin 72 pt (2,54 cm) di semua sisi; tanpa nomor halaman — sesuai acuan.
#set page(paper: "a4", margin: 72pt, numbering: none)

// Times New Roman 12 pt. Edge ascender–descender dipilih agar tinggi baris
// alami font = 11,1 pt; dengan leading 9,6 pt jarak antarbaris menjadi 20,7 pt
// (setara spasi 1,5 pada dokumen acuan). Rata kiri sesuai acuan — hanya
// paragraf 4.3 dan 4.4 yang rata kanan-kiri.
#set text(
  font: ("Times New Roman",),
  size: 12pt,
  lang: "id",
  top-edge: "ascender",
  bottom-edge: "descender",
)
#set par(justify: false, leading: 9.89pt, spacing: 0pt)

// Judul bagian/sub-bagian serta jarak antarelemen ditangani helper
// sec1()/sec2()/paragraf()/tbl() di template.typ.

#include "cover.typ"

#include "sections/01-peran-tim.typ"
#include "sections/02-ringkasan-kemajuan.typ"
#include "sections/03-rencana-dan-realisasi.typ"
#include "sections/04-capaian-produk.typ"
#include "sections/05-bukti-kemajuan.typ"
#include "sections/06-kontribusi-individu.typ"
#include "sections/07-kendala-dan-solusi.typ"
#include "sections/08-perubahan-lingkup-dan-risiko.typ"
#include "sections/09-rencana-milestone-2.typ"
#include "sections/10-rekap-logbook.typ"
#include "sections/11-deklarasi-ai.typ"
#include "sections/12-lampiran.typ"
