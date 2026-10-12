"""Uji asap aturan dokumen yang belum tercakup skrip lain.

Memeriksa aturan yang ditegakkan aplikasi (bukan constraint database):
siklus jaga, otorisasi per peran, penutupan shift, dan pencarian riwayat.

    python tests/smoke_rules.py
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_TMP = Path(tempfile.mkdtemp(prefix="smartpark-rules-"))
os.environ["DATABASE_URL"] = f"sqlite:///{(_TMP / 'rules.db').as_posix()}"
os.environ["UPLOAD_DIR"] = str(_TMP / "plates")
os.environ["DEBUG"] = "false"

from fastapi.testclient import TestClient  # noqa: E402

from app.database import SessionLocal, create_all  # noqa: E402
from app.main import app  # noqa: E402
from app.models import Officer, ParkingArea, ROLE_SPV  # noqa: E402
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
    create_all()
    db = SessionLocal()
    try:
        utama = ParkingArea(code="POS-UTAMA", name="Pos Utama")
        ft = ParkingArea(code="POS-FT", name="Pos FT")
        nonaktif = ParkingArea(code="POS-OFF", name="Pos Nonaktif", is_active=False)
        budi = Officer(
            employee_no="PK001", name="Budi", password_hash=hash_password("budi1234")
        )
        sari = Officer(
            employee_no="PK002", name="Sari", password_hash=hash_password("sari1234")
        )
        dewi = Officer(
            employee_no="SPV001",
            name="Dewi",
            password_hash=hash_password("dewi1234"),
            role=ROLE_SPV,
        )
        db.add_all([utama, ft, nonaktif, budi, sari, dewi])
        db.commit()
        return {
            "utama": utama.id,
            "nonaktif": nonaktif.id,
            "budi": budi.id,
            "sari": sari.id,
            "dewi": dewi.id,
        }
    finally:
        db.close()


def sign_in(client: TestClient, officer_id: int, password: str) -> str:
    response = client.post(
        "/api/auth/sign-in", json={"officer_id": officer_id, "password": password}
    )
    assert response.status_code == 200, response.text
    return response.json()["token"]


def join(client: TestClient, officer_id: int, area_id: int, password: str):
    return client.post(
        "/api/shifts/join",
        json={
            "officer_id": officer_id,
            "password": password,
            "parking_area_id": area_id,
        },
    )


def check_in(client: TestClient, token: str, nim: str, plate: str, key: str):
    return client.post(
        "/api/sessions/check-in",
        data={"nim": nim, "plate": plate, "client_request_id": key},
        headers={"X-Shift-Token": token},
    )


def run(client: TestClient, ids: dict) -> None:
    # ---------------------------------------------------------------- 5.6.3
    section("Pengawas tidak otomatis mendapat penugasan jaga (5.6 aturan 3)")
    spv_token = sign_in(client, ids["dewi"], "dewi1234")
    check("pengawas bisa masuk", bool(spv_token))

    response = client.post(
        "/api/sessions/check-in",
        data={"nim": "244107020001", "plate": "B1234XYZ", "client_request_id": "spv-1"},
        headers={"X-Shift-Token": spv_token},
    )
    check(
        "token pengelola tidak bisa dipakai untuk sesi parkir",
        response.status_code == 401,
        f"{response.status_code} {response.text[:70]}",
    )
    current = client.get("/api/shifts/current", headers={"X-Shift-Token": spv_token})
    check(
        "pengawas memang belum punya penugasan jaga",
        current.status_code in (401, 404),
        str(current.status_code),
    )
    own = client.get("/api/auth/me", headers={"X-Officer-Token": spv_token})
    check("token pengelola tetap sah untuk identitas", own.status_code == 200, own.text[:70])

    # ---------------------------------------------------------------- 5.6.6
    section("Daftar lahan dan petugas tetap terbuka (5.6 aturan 6)")
    officers = client.get("/api/officers")
    check("daftar petugas bisa dibaca tanpa token", officers.status_code == 200)
    if officers.status_code == 200:
        keys = set(officers.json()[0]) if officers.json() else set()
        check(
            "daftar petugas tidak membocorkan hash",
            not ({"password_hash", "password", "token"} & keys),
            str(sorted(keys)),
        )
    check(
        "daftar lahan bisa dibaca tanpa token",
        client.get("/api/areas").status_code == 200,
    )

    # ---------------------------------------------------------------- 5.2
    section("Normalisasi plat (5.2)")
    joined = join(client, ids["budi"], ids["utama"], "budi1234")
    check("petugas bergabung ke shift", joined.status_code == 200, joined.text[:80])
    shift_token = joined.json()["token"]
    shift_id = joined.json()["shift"]["id"]

    long_plate = check_in(
        client, shift_token, "244107020002", "b 1234 xyz abcdefg", "long-plate"
    )
    check("plat panjang diterima", long_plate.status_code in (200, 201), long_plate.text[:90])
    if long_plate.status_code in (200, 201):
        stored = long_plate.json()["plate_in"]
        check(f"plat dipotong maks 12 -> {stored!r}", len(stored) <= 12, str(len(stored)))
        check("plat hanya A-Z dan 0-9", stored.isalnum() and stored.isupper(), stored)

    # ---------------------------------------------------------------- 5.4
    section("Sesi batal tidak muncul di riwayat biasa (5.4)")
    before = client.get(
        "/api/sessions/dashboard", headers={"X-Shift-Token": shift_token}
    ).json()
    to_void = check_in(client, shift_token, "244107020003", "B5555XYZ", "to-void")
    check("check-in untuk dibatalkan", to_void.status_code in (200, 201), to_void.text[:80])
    session_id = to_void.json()["id"]

    after_in = client.get(
        "/api/sessions/dashboard", headers={"X-Shift-Token": shift_token}
    ).json()
    check(
        "sesi baru ikut terhitung masuk hari ini",
        after_in["checked_in_today"] == before["checked_in_today"] + 1,
        f"{before['checked_in_today']} -> {after_in['checked_in_today']}",
    )

    voided = client.post(
        f"/api/sessions/{session_id}/void",
        json={"note": "salah input NIM"},
        headers={"X-Shift-Token": shift_token},
    )
    check("pembatalan berhasil", voided.status_code == 200, voided.text[:80])

    after_void = client.get(
        "/api/sessions/dashboard", headers={"X-Shift-Token": shift_token}
    ).json()
    check(
        "sesi batal tidak lagi dihitung masuk hari ini",
        after_void["checked_in_today"] == before["checked_in_today"],
        f"{after_in['checked_in_today']} -> {after_void['checked_in_today']}",
    )

    history = client.get("/api/sessions/history", headers={"X-Shift-Token": shift_token})
    check("riwayat bisa dibaca", history.status_code == 200, history.text[:80])
    if history.status_code == 200:
        ids_in_history = {row["id"] for row in history.json()}
        check("sesi batal tidak ada di riwayat", session_id not in ids_in_history)

    detail = client.get(
        f"/api/sessions/{session_id}", headers={"X-Shift-Token": shift_token}
    )
    check("sesi batal masih bisa dibuka untuk audit", detail.status_code == 200)

    # ---------------------------------------------------------------- 5.5.11
    section("Menutup shift menutup seluruh penugasan (5.5 aturan 11)")
    sari_join = join(client, ids["sari"], ids["utama"], "sari1234")
    check("petugas kedua bergabung ke shift yang sama", sari_join.status_code == 200)
    check(
        "shift-nya memang shift yang sama",
        sari_join.json()["shift"]["id"] == shift_id,
        str(sari_join.json()["shift"]["id"]),
    )
    sari_shift_token = sari_join.json()["token"]
    check(
        "dua penugasan aktif dalam satu shift",
        len(sari_join.json()["shift"]["assignments"]) == 2,
    )

    closed = client.post(
        f"/api/shifts/{shift_id}/close",
        json={"note": "tutup paksa akhir hari"},
        headers={"X-Officer-Token": spv_token},
    )
    check("pengawas bisa menutup shift", closed.status_code == 200, closed.text[:100])
    if closed.status_code == 200:
        body = closed.json()
        check(
            "catatan penutupan bisa dibaca",
            body.get("end_note") == "tutup paksa akhir hari",
            str(body.get("end_note")),
        )
        check(
            "seluruh penugasan ikut ditutup",
            all(a["left_at"] is not None for a in body.get("assignments", [])),
            str(body.get("assignments"))[:90],
        )
        check(
            "alasan penutupan ikut tercatat di tiap penugasan",
            all(
                a.get("left_note") == "tutup paksa akhir hari"
                for a in body.get("assignments", [])
            ),
            str([a.get("left_note") for a in body.get("assignments", [])])[:90],
        )

    reopened = client.get("/api/shifts", headers={"X-Officer-Token": spv_token})
    if reopened.status_code == 200:
        row = next(s for s in reopened.json() if s["id"] == shift_id)
        check(
            "catatan tetap terbaca saat shift dibuka lagi dari riwayat",
            row.get("end_note") == "tutup paksa akhir hari",
            str(row.get("end_note")),
        )

    for label, token in (("Budi", shift_token), ("Sari", sari_shift_token)):
        stale = client.get("/api/shifts/current", headers={"X-Shift-Token": token})
        check(
            f"token penugasan {label} mati setelah shift ditutup",
            stale.status_code in (401, 404),
            str(stale.status_code),
        )
    write_after = check_in(client, sari_shift_token, "244107020004", "B7777XYZ", "after")
    check(
        "penugasan yang sudah ditutup tidak bisa menulis sesi",
        write_after.status_code in (401, 403),
        str(write_after.status_code),
    )

    # ---------------------------------------------------------------- 5.5.8 / 5.6.2
    section("Lahan nonaktif & wewenang pengelolaan (5.5 aturan 8, 5.6 aturan 2)")
    off = client.post(
        "/api/shifts/open",
        json={"parking_area_id": ids["nonaktif"]},
        headers={"X-Officer-Token": spv_token},
    )
    check(
        "lahan nonaktif menolak shift baru",
        off.status_code in (400, 404, 409),
        str(off.status_code),
    )

    not_spv = client.post(
        "/api/areas",
        json={"code": "POS-X", "name": "Pos X"},
        headers={"X-Officer-Token": sign_in(client, ids["budi"], "budi1234")},
    )
    check("petugas biasa ditolak saat menambah lahan", not_spv.status_code == 403, str(not_spv.status_code))
    if not_spv.status_code == 403:
        check(
            "kode galat wewenang",
            not_spv.json().get("code") == "not_spv",
            not_spv.text[:80],
        )

    # ---------------------------------------------------------------- 5.1
    section("Batas panjang NIM (5.1)")
    from app.config import settings

    check(
        f"nim_max_length ({settings.nim_max_length}) tidak melebihi lebar kolom 32",
        settings.nim_max_length <= 32,
        str(settings.nim_max_length),
    )
    check(
        f"nim_min_length ({settings.nim_min_length}) wajar",
        1 <= settings.nim_min_length <= settings.nim_max_length,
        str(settings.nim_min_length),
    )
    check(
        f"plate_max_length ({settings.plate_max_length}) = 12 sesuai 5.2",
        settings.plate_max_length == 12,
        str(settings.plate_max_length),
    )


def main() -> int:
    ids = bootstrap()
    with TestClient(app) as client:
        run(client, ids)
    print("\n" + "=" * 62)
    print(f"lulus: {len(PASSED)}   gagal: {len(FAILED)}")
    if FAILED:
        print("\nyang gagal:")
        for label in FAILED:
            print(f"  - {label}")
        return 1
    print("aturan dokumen yang belum tercakup berjalan sesuai skema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
