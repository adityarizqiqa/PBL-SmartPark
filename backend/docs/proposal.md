# SmartPark: Ringkasan Proposal untuk Pengerjaan Backend

Versi ringkas dari Proposal PBL Kelompok 4 (SmartPark: Sistem Verifikasi Check-In dan Check-Out Parkir Motor Mahasiswa Berbasis QR KTM dan Pengenalan Plat Nomor Kendaraan). Hanya memuat bagian yang dibutuhkan untuk memulai backend. Peran backend: Raditya Riefki.

## 1. Gambaran Singkat Sistem

SmartPark adalah aplikasi mobile Flutter berbasis shared-device yang dipakai petugas pos parkir untuk mencatat dan memverifikasi sesi parkir sepeda motor mahasiswa. NIM diambil dari QR KTM, plat nomor dibaca dengan YOLO + OCR. NIM dan plat hanya terikat pada satu sesi parkir, bukan relasi permanen.

Backend bertugas menyimpan sesi parkir, menjalankan aturan bisnis (validasi, duplikasi, pencocokan plat), dan menyediakan REST API untuk aplikasi mobile.

## 2. Stack dan Batasan Teknis Backend

- Laravel REST API dengan MySQL.
- Seluruh komunikasi memakai HTTPS.
- Tidak ada akun/login petugas; identifikasi cukup berdasarkan perangkat atau area parkir.
- Data yang disimpan terbatas pada NIM, plat, waktu, dan snapshot foto plat.
- Validasi duplikasi sesi aktif dilakukan di sisi server.
- Mode offline penuh tidak masuk MVP; hanya retry dan antrian sederhana.
- Tidak terhubung SIAKAD, tidak ada database nama/foto/prodi/kendaraan permanen, tidak ada CCTV, palang otomatis, sensor slot, RFID/NFC, pembayaran, reservasi, maupun validasi STNK.
- Khusus sepeda motor.

## 3. Aturan Bisnis

- NIM hanya divalidasi formatnya (bukan keaslian atau keaktifan mahasiswa). Keaslian KTM diperiksa visual oleh petugas.
- Satu NIM dan satu plat tidak boleh memiliki lebih dari satu sesi parkir aktif pada waktu yang sama (ditolak server).
- Plat dinormalisasi sebelum disimpan dan dicari.
- Check-out memakai plat sebagai pencarian utama. Jika exact match gagal, gunakan pencocokan kemiripan (skor kemiripan dan perbedaan karakter), lalu fallback pencarian berdasarkan NIM.
- Mismatch tidak menutup sesi otomatis.
- Approval manual wajib disertai catatan verifikasi.
- Penolakan check-out membuat sesi tetap aktif.

## 4. Alur Data

### 4.1 Check-In

1. Petugas memverifikasi KTM secara visual.
2. QR dipindai untuk mendapat NIM (atau NIM diinput manual jika QR gagal). Format NIM divalidasi.
3. Plat dipindai, hasil deteksi/OCR ditampilkan dan dapat dikoreksi atau dipindai ulang.
4. Petugas konfirmasi, lalu server membuat sesi parkir aktif berisi NIM, plat, waktu masuk, dan snapshot foto plat.

### 4.2 Check-Out

1. Plat kendaraan dipindai.
2. Server mencari sesi aktif berdasarkan plat. Exact match: tampilkan NIM dan data check-in. Mirip: tampilkan skor kemiripan dan karakter berbeda untuk verifikasi manual. Tidak ditemukan: fallback pencarian berdasarkan NIM. Tetap tidak ada: "Sesi Tidak Ditemukan".
3. Petugas mencocokkan KTM secara visual.
4. Hasil akhir: ditutup dengan status Sesuai atau Verifikasi Manual (dengan catatan), atau ditolak sehingga sesi tetap aktif.

## 5. Fitur yang Membutuhkan Dukungan Backend

- Beranda: ringkasan jumlah sesi parkir dan aktivitas terbaru.
- Pembuatan sesi check-in (NIM, plat, waktu masuk, snapshot plat).
- Pencarian sesi aktif berdasarkan plat atau NIM, termasuk pencocokan kemiripan.
- Penutupan sesi check-out (menyimpan snapshot plat check-out, status, dan catatan verifikasi manual).
- Penolakan check-out (sesi tetap aktif).
- Daftar kendaraan yang masih parkir: NIM, plat, waktu masuk, durasi berjalan.
- Riwayat sesi dengan status Sesuai, Verifikasi Manual, Tidak Sesuai; dapat dicari berdasarkan NIM atau plat.
- Penanganan kendala di sisi server: sesi aktif ganda, sesi tidak ditemukan, format NIM tidak sesuai, dan gangguan koneksi (mendukung retry dari klien).

## 6. Data yang Disimpan (per Sesi Parkir)

- NIM
- Plat check-in dan plat check-out
- Waktu check-in dan waktu check-out
- Snapshot foto plat check-in dan check-out
- Status sesi: aktif, Sesuai, Verifikasi Manual, Tidak Sesuai
- Skor kemiripan dan catatan verifikasi manual
- Identitas perangkat atau area parkir

## 7. Skenario Pengujian yang Relevan untuk Backend

| No | Skenario | Hasil yang Diharapkan |
| --- | --- | --- |
| 1 | Check-in dengan NIM dan plat valid | Sesi aktif berhasil dibuat |
| 4 | Check-out dengan plat sesuai sesi aktif | Data check-in ditampilkan dan sesi dapat ditutup |
| 5 | Plat check-out berbeda atau meragukan | Sistem mengembalikan data pembanding untuk keputusan manual |
| 6 | Plat tidak punya sesi aktif | Opsi scan ulang atau pencarian berdasarkan NIM |
| 7 | NIM atau plat sudah punya sesi aktif | Pembuatan sesi ganda ditolak |
| 8 | Koneksi server terputus | Pesan kendala dan percobaan ulang |
| 9 | Pencarian riwayat berdasarkan NIM atau plat | Riwayat tampil sesuai data tersimpan |

Target awal: seluruh test case kritis (check-in, check-out, verifikasi manual, penanganan mismatch) lulus. Waktu pengenalan plat sekitar 5 detik atau kurang pada kondisi normal.

## 8. Jadwal Backend

| Minggu | Tanggal | Pekerjaan Backend |
| --- | --- | --- |
| 5 | 18-24 Sept | Rancang skema database; setup tools kolaborasi (Trello/Jira, GitHub) |
| 6 | 25 Sept-1 Okt | Desain skema database |
| 7 | 2-8 Okt | Endpoint API dasar |
| 8 | 9-15 Okt | Endpoint data plat dan histori scan; uji fungsional endpoint |
| 9 | 16-22 Okt | Logika bisnis pencocokan plat |
| 10 | 23-29 Okt | Finalisasi API; uji integrasi API-database |
| 11 | 30 Okt-5 Nov | Integrasi backend dengan pipeline ML |
| 12 | 6-12 Nov | Optimasi dan perbaikan bug backend |
| 13 | 13-19 Nov | Uji beban dan stabilitas API |
| 14 | 20-26 Nov | Perbaikan bug backend |

Tanggung jawab utama peran Backend: merancang dan mengembangkan API, mengelola database, menangani logika bisnis, dan memastikan komunikasi aplikasi dengan server berjalan baik.
