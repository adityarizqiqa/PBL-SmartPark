// ============================== Halaman Judul ==============================
// Geometri mengikuti halaman 1 dokumen acuan (docs/MILESTONE PBL.pdf):
// judul 84,5 pt dari tepi atas, jarak antarbaris 20,7 pt, jarak antarparagraf 32,7 pt.
#import "template.typ": hdr-fill, leading

#let judul(body, above: 0pt) = block(
  above: above,
  below: 0pt,
  {
    text(size: 12pt, weight: "bold")[#body]
    v(leading)
  },
)

#{
  set align(center)
  set par(spacing: 0pt, justify: false)

  v(13.45pt) // margin 72 pt + 13,45 pt agar baris pertama jatuh di 84,5 pt
  judul[LAPORAN KEMAJUAN _PROJECT-BASED LEARNING_ (PBL)]
  judul(above: 11.71pt)[MILESTONE 1]
  judul(above: 11.71pt)[
    SmartPark: Sistem Verifikasi Check-In dan Check-Out Parkir Motor Mahasiswa
    Berbasis QR KTM dan Pengenalan Plat Nomor Kendaraan.
  ]
  judul(above: 11.71pt)[Tim SmartPark | Kelas TI-3E | Semester 5]
  judul(above: 11.71pt)[Tahun Akademik 2026/2027]

  // Kepala daftar anggota dan daftar nama/NIM (tanpa garis tabel).
  block(
    above: 10.51pt,
    inset: (left: 42.8pt),
    table(
      columns: (57pt, 189pt, 96pt),
      inset: (x: 0pt, top: 1.2pt, bottom: 8.89pt),
      stroke: none,
      align: left,
      table.header([*No*], [*Nama*], [*NIM*]),
    ),
  )
  block(
    above: 11.7pt,
    inset: (left: 81.6pt),
    table(
      columns: (18pt, 216pt, 82pt),
      inset: (x: 0pt, top: 1.2pt, bottom: 8.89pt),
      stroke: none,
      align: left,
      [*1.*], [*Aditya Rizqiqa Ramadhan*], [*244107020008*],
      [*2.*], [*Fifa Nuurun Halizah*], [*244107020019*],
      [*3.*], [*Raditya Riefki*], [*244107020204*],
      [*4.*], [*Shafiqa Nabila Maharani Khoirunnisa*], [*244107020221*],
      [*5.*], [*Singgih Wahyu Permana*], [*244107020102*],
    ),
  )

  v(16.63pt)
  block(image("../logo-polinema.png", width: 156.75pt))

  judul(above: 51.9pt)[PRODI D-IV TEKNIK INFORMATIKA]
  judul(above: 11.71pt)[JURUSAN TEKNOLOGI INFORMASI]
  judul(above: 11.71pt)[POLITEKNIK NEGERI MALANG]
  judul(above: 11.71pt)[2026]
}

#pagebreak()
