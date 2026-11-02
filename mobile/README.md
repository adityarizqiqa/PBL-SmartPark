# SmartPark Kampus — aplikasi mobile

Flutter client untuk backend SmartPark (`../backend`). Aplikasi dipakai petugas
gerbang dan pengawas (SPV) di pos parkir kampus.

## Menjalankan

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # emulator Android
```

Tanpa `API_BASE_URL`, aplikasi memakai alamat backend bawaan di
`lib/core/network/api_client.dart`.

## Struktur

Arsitektur fitur (bounded context). Arah dependensi hanya satu:
`presentation → domain ← data`, dan semua lapisan boleh memakai `core`.

```
lib/
├─ main.dart                    # entry point + shell navigasi per peran
├─ core/                        # dipakai lintas fitur, tanpa pengetahuan fitur
│  ├─ di/                       # composition root (provider Riverpod)
│  ├─ entities/                 # entity lintas fitur (Officer, Area, Shift, sesi)
│  ├─ failures/                 # sealed Failure, dipetakan dari kode backend
│  ├─ network/                  # ApiClient, ApiException, konstanta endpoint
│  ├─ session/                  # SessionStore + identitas petugas
│  ├─ theme/                    # token warna, jarak, radius, ThemeData
│  ├─ utils/                    # formatter tanggal/durasi, validator masukan
│  └─ widgets/                  # bottom nav, app bar, status pill, info tile, ...
└─ features/
   ├─ auth/                     # masuk/keluar petugas & pengawas
   ├─ dashboard/                # beranda petugas (statistik + aksi cepat)
   ├─ vehicles/                 # daftar kendaraan yang masih parkir
   ├─ history/                  # riwayat sesi + paginasi
   ├─ session_ops/              # check-in, check-out, void, tolak
   └─ supervisor/               # konsol pengawas: lahan, shift, petugas
```

Setiap fitur memakai tiga lapisan:

| Lapisan | Isi | Aturan |
|---|---|---|
| `domain/` | entity, kontrak `*Repository`, usecase | murni Dart, tanpa Flutter/HTTP |
| `data/` | implementasi repository | satu-satunya yang menyentuh `ApiClient`; memetakan `ApiException → Failure` |
| `presentation/` | halaman, provider/controller, widget | tidak pernah memanggil HTTP |

## Konvensi

- **Layar tidak menyentuh `ApiClient`.** Semua I/O lewat repository; galat
  sampai ke UI sebagai `Failure` (bukan kode HTTP).
- **State per layar.** `Notifier` Riverpod memegang state; halaman membaca
  lewat `ref.watch` dan memanggil aksi pada notifier.
- **Dependensi di-inject.** `ApiClient`, `SessionStore`, dan repository dibuat
  di `core/di/providers.dart`; pengujian menimpanya lewat
  `ProviderScope(overrides: [...])`.
- **Navigasi di shell.** `main.dart` memegang `OfficerShell` dan
  `SupervisorShell`; halaman tab tidak menyalin bottom navigation.
- **String UI berbahasa Indonesia, identifier berbahasa Inggris.**
- Halaman check-in dan check-out memakai `part` file per langkah
  (`check_in_step_*.dart`) karena berbagi satu state alur.

## Pengujian

```bash
flutter test
```

| Berkas | Cakupan |
|---|---|
| `test/core/**` | pemetaan `Failure`, validator, formatter, header token |
| `test/features/auth` | pilihan petugas/lahan, jalur petugas & SPV, galat |
| `test/features/dashboard` | statistik, banner galat, aksi cepat |
| `test/features/vehicles` | daftar, saring, kosong, galat, detail |
| `test/features/history` | paginasi, saring status, pencarian, galat |
| `test/features/session_ops` | check-in sukses, galat jaringan, bentrok 409 |
| `test/features/supervisor` | ringkasan konsol, tambah lahan, buka shift, tambah petugas |
| `test/widget_test.dart` | alur penuh masuk → beranda → kendaraan → riwayat, check-in, check-out |
