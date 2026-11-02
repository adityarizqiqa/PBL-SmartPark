// ============================ 3. Rencana dan Realisasi ============================
#import "../template.typ": tbl, sec1, sec2, paragraf, isi, pct

#sec1(above: 5.9pt)[3. Rencana dan Realisasi]

#sec2(above: 5.9pt)[3.1 Kemajuan Rincian Pekerjaan]

#tbl(
  above: 4.97pt,
  (82.5pt, 172pt, 78pt, 59pt, 51.7pt),
  ("Bagian Besar", "Tugas Rinci", "Penanggung Jawab", "Status", "Selesai"),
  (
    ([Manajemen proyek], [Koordinasi tim, pembagian tugas, dan pemantauan jadwal], [Aditya], [#isi], [#pct]),
    ([Mobile], [Setup proyek Flutter dan struktur navigasi/UI], [Shafiqa], [#isi], [#pct]),
    ([Mobile], [Implementasi scan QR KTM dan input NIM manual], [Shafiqa], [#isi], [#pct]),
    ([Backend], [Rancangan skema basis data sesi parkir], [Raditya], [#isi], [#pct]),
    ([Backend], [Endpoint API dasar untuk data plat dan riwayat scan], [Raditya], [#isi], [#pct]),
    ([Machine Learning], [EDA dan preprocessing dataset deteksi plat], [Singgih], [#isi], [#pct]),
    ([Machine Learning], [Split dataset dan training awal YOLOv8n], [Singgih], [#isi], [#pct]),
    ([QA], [Penyusunan skenario dan test case awal], [Fifa], [#isi], [#pct]),
    ([Integrasi], [Integrasi awal aplikasi, API, dan/atau model ML], [Tim terkait], [#isi], [#pct]),
  ),
)

#paragraf(above: 28.43pt)[
  Persentase penyelesaian dan status pada tabel ini harus diisi berdasarkan pekerjaan yang
  benar-benar selesai dan bukti yang tersedia, bukan hanya target dalam proposal.
]

#sec2(above: 17.8pt)[3.2 Jadwal Rencana dan Aktual]

#tbl(
  above: 2.37pt,
  (60pt, 183pt, 89.2pt, 111pt),
  ("Minggu", "Rencana dalam Proposal", "Aktual Tim", "Deviasi dan Alasan"),
  (
    ([3 (7–10 Sept)], [Penyusunan outline dan draf bagian proposal sesuai peran.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
    ([4 (11–17 Sept)], [Kompilasi, review, dan finalisasi proposal.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
    ([5 (18–24 Sept)], [Breakdown tugas, setup tools, environment ML, skema database, proyek Flutter, dan QA plan.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
    ([6 (25 Sept–1 Okt)], [EDA/preprocessing awal, desain database dan UI/UX, skenario pengujian.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
    ([7 (2–8 Okt)], [Split dataset/training awal YOLOv8n, endpoint API dasar, navigasi/UI, dokumentasi test case.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
    ([8 (9–15 Okt)], [Evaluasi model deteksi, endpoint data plat/riwayat scan, integrasi API awal, uji endpoint.], [\[Isi aktual\]], [\[Isi jika ada deviasi\]]),
  ),
)
