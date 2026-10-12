# SmartPark — Backend

Backend verifikasi check-in/check-out parkir motor mahasiswa. Dibangun dengan
FastAPI dan SQLAlchemy, memakai SQLite untuk tahap pengembangan.

Skema database ada di [`docs/database-schema.md`](docs/database-schema.md),
ringkasan proposal di [`docs/proposal.md`](docs/proposal.md).

---

## Menjalankan

```bash
python -m venv .venv
.venv/Scripts/activate          # Windows
# source .venv/bin/activate     # Linux/macOS

pip install -r requirements.txt
cp .env.example .env

python -m app.seed --reset      # isi data awal
python -m app
```

Dokumentasi interaktif: <http://127.0.0.1:8000/docs>

`python -m app` membaca `HOST`/`PORT` dari `.env` lalu menjalankan uvicorn
(`app/__main__.py`), jadi alamat dengar tidak perlu ditulis sebagai argumen dan
tidak ikut masuk ke repositori — `.env` sudah di-`gitignore`, sedangkan
`.env.example` memuat templatnya. `.env.example` menyetel `HOST=0.0.0.0` agar
aplikasi mobile di **perangkat fisik** bisa terhubung; dengan `127.0.0.1`
server hanya menerima koneksi dari mesin ini sendiri, sehingga perangkat di
Wi-Fi yang sama selalu gagal dengan `connection refused` meskipun alamat IP
komputer sudah benar. Emulator Android (`10.0.2.2`) dan desktop/web
(`localhost`) tetap berjalan pada keduanya.

Perintah lain:

```bash
python tests/smoke_test.py        # uji seluruh alur lewat HTTP (131 pemeriksaan)
python tests/smoke_rules.py       # uji aturan jaga, peran, dan riwayat (35 pemeriksaan)
python tests/check_constraints.py # buktikan constraint ditegakkan database (47 pemeriksaan)
```

---

## Struktur

```
app/
  main.py          perakitan aplikasi, penanganan galat
  config.py        konfigurasi (baca .env)
  database.py      engine, PRAGMA, operator REGEXP, tipe kunci
  clock.py         waktu UTC dan batas hari WIB
  errors.py        galat domain beserta kode HTTP-nya
  security.py      hashing password, token, pembatas percobaan
  integrity.py     penerjemahan galat integritas lintas engine
  migrations.py    penambahan kolom setelah rilis pertama
  seed.py          pengisian data awal
  models/          satu berkas per tabel
  schemas/         bentuk permintaan dan respons
  services/        aturan bisnis
  api/             dependency, router, serialisasi
docs/
  database-schema.md   skema tabel beserta constraint-nya
  proposal.md          ringkasan proposal yang jadi acuan
tests/
  smoke_test.py        uji alur lewat HTTP
  smoke_rules.py       uji aturan jaga, peran, dan riwayat
  check_constraints.py uji penegakan constraint di database
tools/postman/     koleksi Postman dan berkas contoh unggahan
storage/plates/    snapshot plat (dibuat otomatis, tidak masuk git)
```

Lapisan `services/` tidak mengenal HTTP: ia melempar galat domain, dan
`main.py` yang mengubahnya menjadi respons JSON. Karena itu aturan bisnis bisa
diuji tanpa menyalakan server.

---

## Alur pemakaian

### 1. Petugas mulai bertugas

```bash
curl -X POST localhost:8000/api/shifts/join \
  -H 'Content-Type: application/json' \
  -d '{"officer_id": 1, "password": "budi1234", "parking_area_id": 1}'
```

Bila di lahan itu sudah ada shift terbuka, petugas **bergabung ke shift yang
sama** dan menerima tokennya sendiri. Bila belum ada, shift baru dibuat.

Simpan `token` dari respons. Seluruh permintaan berikutnya memakai header:

```
X-Shift-Token: <token>
```

### 2. Check-in

```bash
curl -X POST localhost:8000/api/sessions/check-in \
  -H 'X-Shift-Token: <token>' \
  -F 'nim=244107020008' \
  -F 'plate=b 1234 xyz' \
  -F 'photo=@plat.jpg'
```

Plat dinormalisasi otomatis menjadi `B1234XYZ`. Bila NIM atau plat sudah punya
sesi aktif, permintaan ditolak `409` dan tidak ada data yang dibuat.

**NIM** hanya divalidasi formatnya: berisi angka, panjang bebas. Panjangnya
berbeda-beda antar institusi, jadi tidak dipatok. Batasnya diatur lewat
`NIM_MIN_LENGTH` dan `NIM_MAX_LENGTH` di `.env` (bawaan 1–32).

### 3. Check-out

Cari sesinya lebih dulu:

```bash
curl 'localhost:8000/api/sessions/lookup?plate=B1234XY2' -H 'X-Shift-Token: <token>'
```

Hasilnya salah satu dari:

| `match_method` | Arti |
| --- | --- |
| `plate_exact` | ketemu persis; `session` berisi data check-in |
| `plate_similar` | ada kandidat dekat; `candidates` berisi platnya untuk dibandingkan |
| `nim_fallback` | tidak ketemu lewat plat, ketemu lewat NIM |
| `null` | tidak ketemu sama sekali |

Angka kemiripan tidak dikirim — petugas membandingkan plat dengan mata.

Lalu tutup sesinya:

```bash
curl -X POST localhost:8000/api/sessions/3/check-out \
  -H 'X-Shift-Token: <token>' \
  -F 'plate=B1234XY2' \
  -F 'status=manual_verified' \
  -F 'note=Plat berbeda satu karakter' \
  -F 'photo=@plat-keluar.jpg'
```

`status` berisi `matched` (Sesuai) atau `manual_verified` (Verifikasi Manual).
Verifikasi manual **wajib** disertai `note`.

Menolak check-out tanpa menutup sesi:

```bash
curl -X POST localhost:8000/api/sessions/3/reject \
  -H 'X-Shift-Token: <token>' -H 'Content-Type: application/json' \
  -d '{"note": "KTM tidak cocok dengan motor"}'
```

### 4. Membatalkan check-in yang salah

```bash
curl -X POST localhost:8000/api/sessions/4/void \
  -H 'X-Shift-Token: <token>' -H 'Content-Type: application/json' \
  -d '{"note": "Salah input NIM, QR gagal terbaca"}'
```

Sesi ditandai `voided`, tidak dihapus. NIM dan platnya langsung bebas dipakai
lagi.

### 5. Berhenti bertugas

```bash
curl -X POST localhost:8000/api/shifts/leave \
  -H 'X-Shift-Token: <token>' -H 'Content-Type: application/json' \
  -d '{"note": "serah terima"}'
```

Token langsung mati. Bila tidak ada lagi petugas yang bertugas, shiftnya ikut
tertutup.

---

## Endpoint

| Metode | Jalur | Keterangan |
| --- | --- | --- |
| `GET` | `/health` | status aplikasi |
| `GET` | `/api/areas` | daftar lahan |
| `POST` | `/api/areas` | tambah lahan |
| `PATCH` | `/api/areas/{id}` | ubah lahan |
| `GET` | `/api/officers` | daftar petugas untuk layar pilih-nama |
| `POST` | `/api/officers` | daftar petugas baru |
| `PATCH` | `/api/officers/{id}` | ubah petugas atau atur password |
| `POST` | `/api/shifts/join` | mulai bertugas, terima token |
| `POST` | `/api/shifts/leave` | berhenti bertugas |
| `GET` | `/api/shifts/current` | shift yang sedang dijalani |
| `GET` | `/api/shifts` | daftar shift |
| `POST` | `/api/shifts/{id}/close` | tutup paksa shift yang lupa ditutup |
| `GET` | `/api/sessions/dashboard` | ringkasan beranda |
| `GET` | `/api/sessions/active` | kendaraan yang masih parkir |
| `GET` | `/api/sessions/history` | riwayat, bisa dicari per NIM/plat |
| `GET` | `/api/sessions/lookup` | cari sesi aktif saat check-out |
| `POST` | `/api/sessions/check-in` | buat sesi parkir |
| `POST` | `/api/sessions/{id}/check-out` | tutup sesi |
| `POST` | `/api/sessions/{id}/reject` | tolak check-out, sesi tetap aktif |
| `POST` | `/api/sessions/{id}/void` | batalkan check-in |
| `GET` | `/api/sessions/{id}` | detail sesi beserta jejaknya |
| `GET` | `/api/sessions/{id}/photo/{in\|out}` | snapshot plat |

Seluruh `/api/sessions/*` dan `/api/shifts/leave` memerlukan header
`X-Shift-Token` yang aktif. Petugas yang tidak sedang bertugas tidak bisa
membaca data operasional.

---

## Hal yang perlu diketahui

**Waktu.** Semua kolom waktu menyimpan UTC. Batas hari untuk laporan dihitung
dalam WIB — kalau memakai UTC, "hari ini" akan mulai pukul 07:00 WIB dan angka
beranda salah setiap pagi. Atur zona lewat `REPORT_UTC_OFFSET_HOURS`.

**Dua kredensial berbeda.** Password petugas bersifat permanen dan di-hash
bcrypt (lambat, bersalt). Token penugasan dibuat ulang tiap kali petugas mulai
bertugas dan di-hash SHA-256 (cepat, karena dicari setiap permintaan). Jangan
menukar algoritmanya.

**Pembatas percobaan masuk** disimpan di memori proses. Bila nanti berjalan di
beberapa worker, ganti dengan penyimpanan bersama.

**Foto** disimpan di `storage/plates/<tahun>/<bulan>/<kode-lahan>/` dan hanya
bisa diambil lewat endpoint terautentikasi.

**Ganti ke MySQL.** Ubah `DATABASE_URL`, lalu sesuaikan tipe kolom `status` dan
`event_type` menjadi `ENUM` bila diinginkan. Tipe kunci dan generated column
sudah ditulis netral sehingga berjalan di kedua engine.
