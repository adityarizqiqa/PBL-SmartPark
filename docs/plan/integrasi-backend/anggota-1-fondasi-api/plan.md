# Anggota 1 — Fondasi API

> **Blocker untuk semua anggota lain.** Selesaikan ini lebih dulu.
> Baca `../master-plan.md` bagian 3 (Konvensi bersama).

## Tujuan
Menyediakan lapisan komunikasi ke backend dan model data yang dipakai seluruh
layar. Setelah selesai, anggota lain cukup `import` tanpa menyentuh HTTP lagi.

## Berkas yang disentuh
- `mobile/pubspec.yaml` (tambah dependency)
- `mobile/android/app/src/main/AndroidManifest.xml` (izin internet)
- `mobile/lib/api/api_exception.dart` (baru)
- `mobile/lib/api/api_client.dart` (baru)
- `mobile/lib/api/session_store.dart` (baru)
- `mobile/lib/models/*.dart` (baru)

## Tugas

### 1. Dependency & izin
- Tambah `http` ke `dependencies` di `pubspec.yaml`, jalankan `flutter pub get`.
- Tambah `<uses-permission android:name="android.permission.INTERNET"/>` di
  `AndroidManifest.xml` **utama** (release build gagal konek tanpa ini).

### 2. `api_exception.dart`
- `ApiException` dengan `statusCode`, `code`, `message`, `details`.
- Parser dari body JSON `{code, message, details}` dan dari galat jaringan
  (pesan ramah, mis. "Tidak bisa menghubungi server").

### 3. `api_client.dart`
- Base URL dari `String.fromEnvironment('API_BASE_URL')`, default
  `http://10.0.2.2:8000`.
- Method: `get`, `post`, `patch`, `postMultipart` (untuk unggah foto).
- Suntik header token otomatis dari `SessionStore`.
- Semua respons non-2xx → `ApiException`. JSON body → `Map<String, dynamic>`.

### 4. `session_store.dart`
- Singleton menyimpan: `shiftToken`, `officerToken`, `officerId`,
  `officerName`, `role`/`isSupervisor`, `areaId`, `areaName`, `shiftId`,
  `assignmentId`.
- Method: `setShiftSession(...)`, `setOfficerSession(...)`, `clear()`.

### 5. `models/`
DTO yang memetakan skema backend (`fromJson`):
- `Officer` — `id, employee_no, name, phone, role, is_active, has_password`
- `Area` — `id, code, name, is_active`
- `Assignment` — `id, shift_id, officer_id, officer_name, joined_at, left_at`
- `Shift` — `id, parking_area_id, area_name, started_at, ended_at, is_open, assignments`
- `Dashboard` — `active_now, checked_in_today, checked_out_today, recent[]`
- `SessionDetail` — `id, nim, plate_in, plate_out, checked_in_at,
  checked_out_at, status, match_method, verification_note, area_id, area_name,
  checked_in_by, checked_out_by, events[]`
- `ActiveSession` — `id, nim, plate_in, checked_in_at, duration_minutes,
  area_id, area_name, checked_in_by`
- `HistoryItem` — `id, nim, plate_in, plate_out, checked_in_at,
  checked_out_at, status, verification_note`
- `LookupResult` — `match_method, session, candidates[], message`
- `LookupCandidate` — `session_id, plate_in, checked_in_at, area_name`
- `PageMeta` — `total, limit, offset`

## Kriteria selesai
- `flutter analyze` bersih.
- Sebuah smoke manual: panggil `GET /api/officers` lewat `ApiClient` dan
  berhasil memetakan ke `List<Officer>`.
- Anggota lain bisa langsung memakai tanpa menulis ulang HTTP.
