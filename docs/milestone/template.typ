// =============================================================================
// Template & helper bersama untuk Laporan Kemajuan PBL — Milestone 1
// Tim SmartPark | TI-3E | Politeknik Negeri Malang
//
// Parameter tipografi mengikuti dokumen acuan (docs/MILESTONE PBL.pdf):
//   Times New Roman 12 pt, spasi baris 1,5 (pitch 20,7 pt), margin 72 pt,
//   lebar tabel 443,2 pt, garis tabel 1 pt hitam, header tabel #D9EAF7.
//
// Jarak vertikal tidak memakai par.spacing, melainkan parameter `above`
// eksplisit pada tiap blok agar sama dengan dokumen acuan.
// =============================================================================

#let hdr-fill = rgb("#D9EAF7")
#let leading = 9.89pt // leading antarbaris (jarak antarbaris total 20,8 pt)

// Placeholder teks agar tanda kurung siku tampil apa adanya.
// Pada [Selesai/Sebagian/Belum] disisipkan zero-width space setelah "/" agar
// sel itu tetap boleh terbagi dua baris seperti pada acuan (aturan pemenggalan
// di tbl() menambahkan word joiner setelah "/").
#let isi = "[Isi]"
#let pct = "[%]"
#let statusFitur = "[Selesai/\u{200b}Sebagian/\u{200b}Belum]"
#let cek = "[Centang setelah diverifikasi]"
#let url = "[URL]"
#let uji = "[Uji akses]"

/// `v(leading)` di akhir blok menambahkan leading akhir baris ke tinggi blok
/// sehingga tinggi blok = n × 20,8 pt — sama seperti kotak baris pada acuan.
#let sec1(body, indent: 18pt, above: 0pt) = block(
  above: above,
  below: 0pt,
  inset: (left: indent),
  {
    text(weight: "bold")[#body]
    v(leading)
  },
)

/// Sub-judul bagian (setara Heading2 pada acuan).
#let sec2(body, indent: 36pt, above: 0pt) = block(
  above: above,
  below: 0pt,
  inset: (left: indent),
  {
    text(weight: "bold")[#body]
    v(leading)
  },
)

/// Paragraf isi dengan jarak atas eksplisit.
/// `keep: true` menahan paragraf agar tidak terpotong antar halaman
/// (padanan keepLines/kendali widow pada dokumen acuan).
#let paragraf(body, above: 0pt, justify: false, keep: false) = {
  let inner = {
    par(justify: justify, body)
    v(leading)
  }
  if keep {
    block(above: above, below: 0pt, breakable: false, inner)
  } else {
    block(above: above, below: 0pt, inner)
  }
}

/// Tabel standar laporan.
/// - columns: lebar kolom dalam pt (total 443,2 pt sesuai acuan)
/// - header: baris judul kolom (ditebalkan, latar #D9EAF7)
/// - rows: daftar baris; setiap baris adalah array sel
/// inset atas 1,2 pt + bawah 8,89 pt membuat tinggi baris = 21 pt + (n−1) × 20,8 pt
/// seperti pada acuan.
///
/// Baris judul ditulis sebagai baris biasa (bukan `table.header`) supaya dapat
/// berdiri sendiri di dasar halaman. Pada acuan, kepala Lampiran E berada di
/// dasar halaman 10 sementara isinya di halaman 11; `table.header` Typst selalu
/// menempelkan kepala pada baris isi pertama sehingga susunan itu tak tercapai.
#let tbl(columns, header, rows, above: 0pt, inset-x: 5.2pt, inset-top: 1.2pt, inset-bottom: 8.89pt) = block(
  above: above,
  below: 0pt,
  {
    // Word tidak memenggal baris setelah "/" yang menempel pada kata
    // ("dan/atau", "WBS/logbook"); Typst memenggalnya. Word joiner disisipkan
    // hanya pada pola "/<nonspasi>" agar "Desain / dokumentasi" tetap terbagi
    // pada spasinya seperti pada acuan.
    show regex("/\\S"): m => [#m.text.at(0)#("\u{2060}")#m.text.slice(1)]
    table(
      columns: columns,
      inset: (x: inset-x, top: inset-top, bottom: inset-bottom),
      stroke: 1pt + black,
      fill: (x, y) => if y == 0 { hdr-fill },
      align: left,
      ..header.map(h => strong(h)),
      ..rows.flatten(),
    )
  },
)
