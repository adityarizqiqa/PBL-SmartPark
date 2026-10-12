"""Uji asap seluruh alur lewat HTTP.

Dijalankan terhadap database sementara, bukan database pengembangan::

    python tests/smoke_test.py

Skrip ini menyalakan aplikasi FastAPI sungguhan (lewat TestClient) dan
menjalankan urutan kejadian yang akan dialami petugas di lapangan, termasuk
kasus-kasus yang harus ditolak.
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

# Database dan penyimpanan sementara — harus diset sebelum app diimpor.
_TMP = Path(tempfile.mkdtemp(prefix="smartpark-smoke-"))
os.environ["DATABASE_URL"] = f"sqlite:///{(_TMP / 'smoke.db').as_posix()}"
os.environ["UPLOAD_DIR"] = str(_TMP / "plates")
os.environ["DEBUG"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

from app.database import SessionLocal, create_all  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Officer, ParkingArea, ROLE_SPV, Shift, ShiftOfficer  # noqa: E402
from app.security import hash_password  # noqa: E402

PASSED: list[str] = []
FAILED: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    (PASSED if condition else FAILED).append(label)
    mark = "OK  " if condition else "FAIL"
    suffix = f"  -> {detail}" if detail and not condition else ""
    print(f"  {mark} {label}{suffix}")


def section(title: str) -> None:
    print(f"\n{title}")


def bootstrap() -> dict:
    """Menyiapkan lahan, petugas, dan shift awal."""
    create_all()
    db = SessionLocal()
    try:
        utama = ParkingArea(code="POS-UTAMA", name="Pos Utama")
        ft = ParkingArea(code="POS-FT", name="Pos FT")
        budi = Officer(
            employee_no="PK001",
            name="Budi",
            password_hash=hash_password("budi1234"),
        )
        sari = Officer(
            employee_no="PK002",
            name="Sari",
            password_hash=hash_password("sari1234"),
        )
        agus = Officer(
            employee_no="PK003",
            name="Agus",
            password_hash=hash_password("agus1234"),
        )
        tanpa_password = Officer(employee_no="PK004", name="Tanpa Password")
        nonaktif = Officer(
            employee_no="PK005",
            name="Nonaktif",
            password_hash=hash_password("nonaktif123"),
            is_active=False,
        )
        dewi = Officer(
            employee_no="SPV001",
            name="Dewi",
            password_hash=hash_password("dewi1234"),
            role=ROLE_SPV,
        )
        db.add_all(
            [utama, ft, budi, sari, agus, tanpa_password, nonaktif, dewi]
        )
        db.commit()
        return {
            "utama": utama.id,
            "ft": ft.id,
            "budi": budi.id,
            "sari": sari.id,
            "agus": agus.id,
            "tanpa_password": tanpa_password.id,
            "nonaktif": nonaktif.id,
            "dewi": dewi.id,
        }
    finally:
        db.close()


def join(client: TestClient, officer_id: int, area_id: int, password: str) -> dict:
    return client.post(
        "/api/shifts/join",
        json={"officer_id": officer_id, "password": password, "parking_area_id": area_id},
    )


def auth(token: str) -> dict:
    return {"X-Shift-Token": token}


def run(client: TestClient, ids: dict) -> None:
    # --- akses dasar ---------------------------------------------------------
    section("Akses dasar")
    r = client.get("/health")
    check("health mengembalikan ok", r.status_code == 200 and r.json()["status"] == "ok")

    r = client.get("/api/areas")
    check("daftar lahan", r.status_code == 200 and len(r.json()) == 2, r.text)

    r = client.get("/api/officers")
    names = [o["name"] for o in r.json()]
    check(
        "daftar petugas hanya yang aktif",
        r.status_code == 200 and "Nonaktif" not in names and len(names) == 5,
        str(names),
    )
    check(
        "pengawas ikut terdaftar sebagai petugas",
        "Dewi" in names,
        str(names),
    )
    check(
        "hash password tidak pernah ikut terkirim",
        all("password_hash" not in key for o in r.json() for key in o),
    )
    check(
        "penanda password diatur",
        any(o["has_password"] is False for o in r.json()),
    )

    # --- masuk bertugas ------------------------------------------------------
    section("Masuk bertugas")
    r = client.post(
        "/api/shifts/join",
        json={
            "officer_id": ids["budi"],
            "password": "salah-sekali",
            "parking_area_id": ids["utama"],
        },
    )
    check("password salah ditolak", r.status_code == 401, r.text)
    check("kode galat jelas", r.json().get("code") == "invalid_credentials", r.text)

    r = join(client, ids["tanpa_password"], ids["utama"], "apa-saja")
    check("petugas tanpa password tidak bisa masuk", r.status_code == 401, r.text)

    r = join(client, ids["nonaktif"], ids["utama"], "nonaktif123")
    check("petugas nonaktif ditolak", r.status_code == 401, r.text)

    r = join(client, ids["budi"], ids["utama"], "budi1234")
    check("Budi berhasil masuk", r.status_code == 200, r.text)
    budi_token = r.json()["token"]
    shift_id = r.json()["shift"]["id"]
    check("shift baru terbuka", r.json()["shift"]["is_open"] is True)
    check("penugasan mencatat petugas", r.json()["assignment"]["officer_id"] == ids["budi"])

    r = join(client, ids["sari"], ids["utama"], "sari1234")
    check("Sari bergabung ke shift yang sama", r.json()["shift"]["id"] == shift_id, r.text)
    sari_token = r.json()["token"]
    check("token Sari berbeda dari Budi", sari_token != budi_token)
    check("shift kini berisi dua petugas", len(r.json()["shift"]["assignments"]) == 2)

    r = join(client, ids["budi"], ids["utama"], "budi1234")
    check("Budi tidak bisa bertugas dua kali", r.status_code == 409, r.text)
    check("kode galat penugasan ganda", r.json().get("code") == "duplicate_active_assignment")

    r = join(client, ids["agus"], ids["ft"], "agus1234")
    check("lahan lain membuat shift baru", r.status_code == 200 and r.json()["shift"]["id"] != shift_id)

    # --- penjagaan akses -----------------------------------------------------
    section("Penjagaan akses")
    r = client.post("/api/sessions/check-in", data={"nim": "244107020001", "plate": "B1A"})
    check("tanpa token ditolak", r.status_code == 401, r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020001", "plate": "B1A"},
        headers=auth("token-palsu"),
    )
    check("token palsu ditolak", r.status_code == 401, r.text)

    # --- check-in ------------------------------------------------------------
    section("Check-in")
    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020001", "plate": "b 1234 xyz"},
        headers=auth(budi_token),
        files={"photo": ("plat.jpg", b"\xff\xd8\xff-foto-palsu", "image/jpeg")},
    )
    check("check-in berhasil", r.status_code == 201, r.text)
    sesi = r.json()
    sesi_id = sesi["id"]
    check("plat dinormalisasi", sesi["plate_in"] == "B1234XYZ", sesi["plate_in"])
    check("status aktif", sesi["status"] == "active")
    check("foto tersimpan", sesi["plate_in_photo_path"] is not None)
    check("petugas tercatat", sesi["checked_in_by"]["officer_name"] == "Budi")
    check("belum ada penutup", sesi["checked_out_by"] is None)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020001", "plate": "D9999ZZ"},
        headers=auth(sari_token),
    )
    check("NIM ganda ditolak", r.status_code == 409, r.text)
    check("kode galat NIM ganda", r.json().get("code") == "duplicate_active_session", r.text)
    check("menyebut kolom yang bentrok", r.json()["details"].get("field") == "nim", r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020002", "plate": "B1234XYZ"},
        headers=auth(sari_token),
    )
    check("plat ganda ditolak", r.status_code == 409, r.text)
    check("menyebut kolom yang bentrok", r.json()["details"].get("field") == "plate", r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "1234X", "plate": "B1A"},
        headers=auth(sari_token),
    )
    check("NIM mengandung huruf ditolak", r.status_code == 422, r.text)
    check("kode galat NIM", r.json().get("code") == "invalid_nim", r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "9" * 33, "plate": "B1A"},
        headers=auth(sari_token),
    )
    check("NIM melebihi batas panjang ditolak", r.status_code == 422, r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "12345", "plate": "B1A"},
        headers=auth(sari_token),
    )
    check("NIM pendek diterima", r.status_code == 201, r.text)
    check("NIM pendek tersimpan apa adanya", r.json()["nim"] == "12345", r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020002", "plate": "---"},
        headers=auth(sari_token),
    )
    check("plat kosong setelah normalisasi ditolak", r.status_code == 422, r.text)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020003", "plate": "E1111AA", "client_request_id": "req-1"},
        headers=auth(sari_token),
    )
    check("check-in kedua berhasil", r.status_code == 201, r.text)
    sesi_dua = r.json()["id"]

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020003", "plate": "E1111AA", "client_request_id": "req-1"},
        headers=auth(sari_token),
    )
    check("retry dengan kunci sama tidak menggandakan", r.status_code == 201 and r.json()["id"] == sesi_dua, r.text)

    # --- daftar dan beranda --------------------------------------------------
    section("Daftar dan beranda")
    r = client.get("/api/sessions/active", headers=auth(sari_token))
    check("tiga kendaraan masih parkir", r.status_code == 200 and len(r.json()) == 3, r.text)
    check("durasi dihitung", all(item["duration_minutes"] >= 0 for item in r.json()))

    r = client.get("/api/sessions/dashboard", headers=auth(sari_token))
    data = r.json()
    check("beranda menghitung sesi aktif", data["active_now"] == 3, str(data["active_now"]))
    check("beranda menghitung masuk hari ini", data["checked_in_today"] == 3, str(data["checked_in_today"]))

    r = client.get("/api/sessions/active")
    check("data operasional tanpa token ditolak", r.status_code == 401, r.text)

    # --- pencarian check-out -------------------------------------------------
    section("Pencarian saat check-out")
    r = client.get("/api/sessions/lookup", params={"plate": "B1234XYZ"}, headers=auth(sari_token))
    check("plat persis ketemu", r.status_code == 200 and r.json()["match_method"] == "plate_exact", r.text)
    check("data check-in ikut ditampilkan", r.json()["session"]["nim"] == "244107020001")

    r = client.get("/api/sessions/lookup", params={"plate": "B1234XY2"}, headers=auth(sari_token))
    body = r.json()
    check("plat mirip mengembalikan kandidat", body["match_method"] == "plate_similar", r.text)
    check("kandidat tidak memuat skor", body["candidates"] and "score" not in body["candidates"][0], r.text)
    check("kandidat hanya plat dan waktu", set(body["candidates"][0]) == {"session_id", "plate_in", "checked_in_at", "area_name"}, str(body["candidates"][0]))

    r = client.get(
        "/api/sessions/lookup",
        params={"plate": "ZZZZZZZ", "nim": "244107020003"},
        headers=auth(sari_token),
    )
    check("jatuh ke pencarian NIM", r.json()["match_method"] == "nim_fallback", r.text)

    r = client.get(
        "/api/sessions/lookup",
        params={"plate": "ZZZZZZZ", "nim": "244107029999"},
        headers=auth(sari_token),
    )
    check("tidak ditemukan memberi pesan", r.json()["session"] is None and r.json()["message"], r.text)

    # --- penolakan check-out -------------------------------------------------
    section("Penolakan check-out")
    r = client.post(f"/api/sessions/{sesi_id}/reject", json={"note": "KTM tidak cocok"}, headers=auth(sari_token))
    check("penolakan tercatat", r.status_code == 200, r.text)
    check("sesi tetap aktif setelah ditolak", r.json()["status"] == "active", r.text)
    check("belum ada waktu keluar", r.json()["checked_out_at"] is None)
    check("penolakan muncul di jejak", any(e["event_type"] == "check_out_rejected" for e in r.json()["events"]))

    r = client.post(f"/api/sessions/{sesi_id}/reject", json={"note": ""}, headers=auth(sari_token))
    check("penolakan tanpa catatan ditolak", r.status_code == 422, r.text)

    # --- penutupan -----------------------------------------------------------
    section("Penutupan sesi")
    r = client.post(
        f"/api/sessions/{sesi_id}/check-out",
        data={"plate": "B1234XYZ", "status": "manual_verified"},
        headers=auth(sari_token),
    )
    check("verifikasi manual tanpa catatan ditolak", r.status_code == 422, r.text)
    check("kode galat catatan wajib", r.json().get("code") == "note_required", r.text)

    r = client.post(
        f"/api/sessions/{sesi_id}/check-out",
        data={"plate": "B1234XYZ", "status": "matched", "match_method": "plate_exact"},
        headers=auth(sari_token),
        files={"photo": ("keluar.jpg", b"\xff\xd8\xff-foto-keluar", "image/jpeg")},
    )
    check("sesi ditutup sebagai Sesuai", r.status_code == 200 and r.json()["status"] == "matched", r.text)
    check("waktu keluar terisi", r.json()["checked_out_at"] is not None)
    check("petugas penutup berbeda dari petugas check-in", r.json()["checked_out_by"]["officer_name"] == "Sari", r.text)
    check("foto keluar tersimpan", r.json()["plate_out_photo_path"] is not None)

    r = client.post(
        f"/api/sessions/{sesi_id}/check-out",
        data={"plate": "B1234XYZ", "status": "matched"},
        headers=auth(sari_token),
    )
    check("sesi tertutup tidak bisa ditutup lagi", r.status_code == 409, r.text)

    # --- pembatalan ----------------------------------------------------------
    section("Pembatalan check-in")
    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020004", "plate": "F2222BB"},
        headers=auth(budi_token),
    )
    check("check-in untuk dibatalkan", r.status_code == 201, r.text)
    salah = r.json()["id"]

    r = client.post(f"/api/sessions/{salah}/void", json={"note": ""}, headers=auth(budi_token))
    check("pembatalan tanpa alasan ditolak", r.status_code == 422, r.text)

    r = client.post(f"/api/sessions/{salah}/void", json={"note": "Salah input NIM"}, headers=auth(budi_token))
    check("pembatalan berhasil", r.status_code == 200 and r.json()["status"] == "voided", r.text)
    check("alasan tersimpan", r.json()["verification_note"] == "Salah input NIM")
    check("jejak pembatalan tercatat", any(e["event_type"] == "check_in_voided" for e in r.json()["events"]))

    r = client.post(f"/api/sessions/{salah}/void", json={"note": "lagi"}, headers=auth(budi_token))
    check("pembatalan ulang tidak mengubah apa pun", r.status_code == 200 and r.json()["status"] == "voided", r.text)
    check("tidak menambah event baru", sum(1 for e in r.json()["events"] if e["event_type"] == "check_in_voided") == 1)

    r = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020004", "plate": "F2222BB"},
        headers=auth(budi_token),
    )
    check("NIM dan plat bebas dipakai lagi setelah dibatalkan", r.status_code == 201, r.text)
    sesi_baru = r.json()["id"]

    r = client.post(f"/api/sessions/{sesi_id}/void", json={"note": "coba"}, headers=auth(budi_token))
    check("sesi tertutup tidak bisa dibatalkan", r.status_code == 409, r.text)

    # --- beranda setelah semua kejadian --------------------------------------
    section("Beranda dan riwayat")
    r = client.get("/api/sessions/dashboard", headers=auth(sari_token))
    data = r.json()
    check("sesi aktif terhitung benar", data["active_now"] == 3, str(data["active_now"]))
    check("sesi batal tidak dihitung masuk hari ini", data["checked_in_today"] == 4, str(data["checked_in_today"]))
    check("sesi keluar terhitung", data["checked_out_today"] == 1, str(data["checked_out_today"]))

    r = client.get("/api/sessions/history", headers=auth(sari_token))
    riwayat = r.json()
    check("riwayat hanya sesi tertutup", len(riwayat) == 1 and riwayat[0]["id"] == sesi_id, r.text)

    r = client.get("/api/sessions/history", params={"q": "B1234"}, headers=auth(sari_token))
    check("riwayat bisa dicari per plat", len(r.json()) == 1, r.text)

    r = client.get("/api/sessions/history", params={"q": "244107020001"}, headers=auth(sari_token))
    check("riwayat bisa dicari per NIM", len(r.json()) == 1, r.text)

    r = client.get("/api/sessions/history", params={"q": "999999999999"}, headers=auth(sari_token))
    check("riwayat kosong bila tidak cocok", r.json() == [], r.text)

    r = client.get("/api/sessions/history/meta", headers=auth(sari_token))
    check("metadata riwayat", r.json()["total"] == 1, r.text)

    r = client.get(f"/api/sessions/{sesi_id}", headers=auth(sari_token))
    check("detail sesi bisa dibuka petugas", r.status_code == 200, r.text)

    r = client.get(f"/api/sessions/{sesi_id}")
    check("detail sesi tanpa token ditolak", r.status_code == 401, r.text)

    # --- foto ----------------------------------------------------------------
    section("Snapshot plat")
    r = client.get(f"/api/sessions/{sesi_id}/photo/in", headers=auth(sari_token))
    check("foto check-in bisa diambil", r.status_code == 200 and r.content.startswith(b"\xff\xd8\xff"), r.text)

    r = client.get(f"/api/sessions/{sesi_id}/photo/in")
    check("foto tanpa token ditolak", r.status_code == 401, r.text)

    r = client.get(f"/api/sessions/{sesi_baru}/photo/out", headers=auth(budi_token))
    check("foto yang belum ada memberi 404", r.status_code == 404, r.text)

    r = client.get(f"/api/sessions/{sesi_id}/photo/aneh", headers=auth(sari_token))
    check("sisi foto tidak sah ditolak", r.status_code == 422, r.text)

    # --- berhenti bertugas ---------------------------------------------------
    section("Berhenti bertugas")
    r = client.post("/api/shifts/leave", json={"note": "serah terima"}, headers=auth(budi_token))
    check("Budi berhenti bertugas", r.status_code == 200 and r.json()["left_at"] is not None, r.text)

    r = client.get("/api/sessions/active", headers=auth(budi_token))
    check("token lama langsung mati", r.status_code == 401, r.text)

    r = client.get("/api/shifts/current", headers=auth(sari_token))
    check("shift masih terbuka karena Sari masih bertugas", r.json()["is_open"] is True, r.text)

    r = client.post("/api/shifts/leave", json={}, headers=auth(sari_token))
    check("Sari berhenti bertugas", r.status_code == 200, r.text)

    r = client.get(
        "/api/shifts",
        params={"area_id": ids["utama"], "open_only": "true"},
        headers=session_auth(sign_in(client, ids["budi"], "budi1234").json()["token"]),
    )
    check("shift ikut tertutup saat petugas terakhir pulang", r.json() == [], r.text)

    r = join(client, ids["budi"], ids["utama"], "budi1234")
    check("Budi bisa membuka shift baru setelah bebas", r.status_code == 200, r.text)
    token_baru = r.json()["token"]

    r = client.post("/api/shifts/leave", json={}, headers=auth(token_baru))
    check("bersih-bersih penutup", r.status_code == 200, r.text)


def session_auth(token: str) -> dict:
    """Header sesi masuk petugas (bukan penugasan jaga)."""
    return {"X-Officer-Token": token}


def sign_in(client: TestClient, officer_id: int, password: str) -> dict:
    return client.post(
        "/api/auth/sign-in",
        json={"officer_id": officer_id, "password": password},
    )


def run_spv(client: TestClient, ids: dict) -> None:
    section("Masuk petugas (sesi pengelolaan)")
    r = sign_in(client, ids["dewi"], "dewi1234")
    check("pengawas bisa masuk", r.status_code == 200, r.text)
    spv_token = r.json()["token"]
    check("peran pengawas dilaporkan", r.json()["session"]["role"] == "spv")

    r = sign_in(client, ids["budi"], "budi1234")
    check("petugas biasa bisa masuk", r.status_code == 200, r.text)
    officer_token = r.json()["token"]
    check("peran petugas dilaporkan", r.json()["session"]["role"] == "officer")

    r = sign_in(client, ids["budi"], "salah-sekali")
    check("password salah ditolak", r.status_code == 401)
    r = sign_in(client, ids["tanpa_password"], "apa-saja")
    check("petugas tanpa password ditolak", r.status_code == 401)
    r = sign_in(client, ids["nonaktif"], "nonaktif123")
    check("petugas nonaktif ditolak", r.status_code == 401)

    r = client.get("/api/auth/me", headers=session_auth(spv_token))
    check("identitas sesi bisa dibaca", r.status_code == 200 and r.json()["name"] == "Dewi")

    section("Wewenang pengelolaan")
    r = client.post(
        "/api/areas",
        json={"code": "POS-BARU", "name": "Pos Baru"},
    )
    check("tambah lahan tanpa token ditolak", r.status_code == 401)

    r = client.post(
        "/api/officers",
        json={"name": "Penyusup", "password": "susup123", "role": "spv"},
        headers=session_auth(officer_token),
    )
    check("petugas biasa tidak boleh membuat akun", r.status_code == 403, r.text)

    r = client.post(
        "/api/officers",
        json={"name": "Penyusup", "password": "susup123", "role": "spv"},
    )
    check("membuat akun tanpa token ditolak", r.status_code == 401)

    r = client.patch(
        f"/api/officers/{ids['budi']}",
        json={"role": "spv"},
        headers=session_auth(officer_token),
    )
    check("petugas biasa tidak boleh menaikkan perannya", r.status_code == 403)

    r = client.patch(
        f"/api/officers/{ids['budi']}",
        json={"role": "spv"},
    )
    check("menaikkan peran tanpa token ditolak", r.status_code == 401)

    r = client.get("/api/shifts", params={"area_id": ids["utama"]})
    check("daftar shift tanpa token ditolak", r.status_code == 401)

    r = client.get("/api/shifts", headers=session_auth(officer_token))
    check("daftar shift dengan sesi boleh dibaca", r.status_code == 200, r.text)

    r = client.post(
        "/api/areas",
        json={"code": "POS-BARU", "name": "Pos Baru"},
        headers=session_auth(officer_token),
    )
    check("petugas biasa tidak boleh menambah lahan", r.status_code == 403)
    check("kode galat wewenang", r.json()["code"] == "not_spv")

    r = client.post(
        "/api/areas",
        json={"code": "POS-BARU", "name": "Pos Baru"},
        headers=session_auth(spv_token),
    )
    check("pengawas boleh menambah lahan", r.status_code == 201, r.text)
    new_area = r.json()["id"]

    r = client.patch(
        f"/api/areas/{new_area}",
        json={"is_active": False},
        headers=session_auth(spv_token),
    )
    check("pengawas boleh menonaktifkan lahan", r.status_code == 200)
    check("lahan jadi nonaktif", r.json()["is_active"] is False)

    section("Pengaturan shift jaga")
    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": new_area},
        headers=session_auth(officer_token),
    )
    check("petugas biasa tidak boleh membuka shift", r.status_code == 403)

    # Lahan nonaktif tidak boleh membuka shift.
    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": new_area},
        headers=session_auth(spv_token),
    )
    check("lahan nonaktif menolak shift baru", r.status_code == 409)

    # Lahan khusus uji shift, supaya tidak bentrok dengan shift pada alur utama.
    r = client.post(
        "/api/areas",
        json={"code": "POS-JAGA", "name": "Pos Jaga"},
        headers=session_auth(spv_token),
    )
    check("lahan uji shift dibuat", r.status_code == 201, r.text)
    shift_area = r.json()["id"]

    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": shift_area},
        headers=session_auth(spv_token),
    )
    check("pengawas boleh membuka shift", r.status_code == 201, r.text)
    opened = r.json()
    check("shift terbuka", opened["ended_at"] is None and opened["is_open"])

    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": shift_area},
        headers=session_auth(spv_token),
    )
    check("shift kedua di lahan sama ditolak", r.status_code == 409)

    # Perangkat tidak lagi dimodelkan. Setiap petugas memakai perangkatnya
    # sendiri, jadi satu shift bisa dilayani beberapa perangkat sekaligus dan
    # batasan "satu perangkat satu shift terbuka" tidak berlaku lagi.
    r = client.post(
        "/api/areas",
        json={"code": "POS-DEV-A", "name": "Pos Uji Buka A"},
        headers=session_auth(spv_token),
    )
    check("lahan uji buka A dibuat", r.status_code == 201, r.text)
    area_a = r.json()["id"]

    r = client.post(
        "/api/areas",
        json={"code": "POS-DEV-B", "name": "Pos Uji Buka B"},
        headers=session_auth(spv_token),
    )
    check("lahan uji buka B dibuat", r.status_code == 201, r.text)
    area_b = r.json()["id"]

    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": area_a, "device_code": "hp-pos-dev-01"},
        headers=session_auth(spv_token),
    )
    check("field perangkat diabaikan saat membuka shift", r.status_code == 201, r.text)
    check("respons shift tidak memuat perangkat", "device_code" not in r.json())

    r = client.post(
        "/api/shifts/open",
        json={"parking_area_id": area_b, "device_code": "hp-pos-dev-01"},
        headers=session_auth(spv_token),
    )
    check(
        "perangkat yang sama boleh dipakai shift lain",
        r.status_code == 201,
        r.text,
    )

    r = client.post(
        f"/api/shifts/{opened['id']}/close",
        json={"note": "pos tutup lebih awal"},
        headers=session_auth(officer_token),
    )
    check("petugas biasa tidak boleh menutup shift", r.status_code == 403)

    r = client.post(
        f"/api/shifts/{opened['id']}/close",
        json={"note": "pos tutup lebih awal"},
        headers=session_auth(spv_token),
    )
    check("pengawas boleh menutup shift", r.status_code == 200, r.text)
    check("catatan penutupan tersimpan", r.json()["ended_at"] is not None)

    r = client.get(
        f"/api/shifts?area_id={ids['ft']}",
        headers=session_auth(spv_token),
    )
    check("riwayat shift per lahan terbaca", r.status_code == 200 and len(r.json()) >= 1)

    section("Keluar dari sesi")
    r = client.post("/api/auth/sign-out", headers=session_auth(spv_token))
    check("pengawas bisa keluar", r.status_code == 200)
    r = client.get("/api/auth/me", headers=session_auth(spv_token))
    check("token sesi mati setelah keluar", r.status_code == 401)


def main() -> int:
    ids = bootstrap()
    with TestClient(app) as client:
        run(client, ids)
        run_spv(client, ids)

    print("\n" + "=" * 62)
    print(f"lulus: {len(PASSED)}   gagal: {len(FAILED)}")
    if FAILED:
        print("\nyang gagal:")
        for item in FAILED:
            print(f"  - {item}")
        return 1
    print("seluruh alur berjalan sesuai skema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
