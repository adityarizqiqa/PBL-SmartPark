"""Membuktikan constraint ditegakkan oleh database, bukan hanya oleh aplikasi.

Seluruh pengujian di sini menulis langsung lewat SQL mentah, melewati lapisan
service dan router sepenuhnya. Kalau salah satu lolos, berarti skema memang
tidak menjaga invariannya.

    python tests/check_constraints.py
"""

from __future__ import annotations

import os
import sqlite3
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

_TMP = Path(tempfile.mkdtemp(prefix="smartpark-constraints-"))
os.environ["DATABASE_URL"] = f"sqlite:///{(_TMP / 'check.db').as_posix()}"
os.environ["UPLOAD_DIR"] = str(_TMP / "plates")

from app.database import create_all, engine  # noqa: E402

PASSED: list[str] = []
FAILED: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    (PASSED if condition else FAILED).append(label)
    mark = "OK  " if condition else "FAIL"
    print(f"  {mark} {label}{f'  -> {detail}' if detail and not condition else ''}")


def rejects(conn: sqlite3.Connection, sql: str, params: tuple = ()) -> tuple[bool, str]:
    """True bila pernyataan ditolak database."""
    try:
        conn.execute(sql, params)
        return False, ""
    except sqlite3.IntegrityError as exc:
        return True, str(exc)


def setup(conn: sqlite3.Connection) -> None:
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("INSERT INTO parking_areas (code, name, is_active) VALUES ('A', 'Pos A', 1)")
    conn.execute("INSERT INTO parking_areas (code, name, is_active) VALUES ('B', 'Pos B', 1)")
    conn.execute(
        "INSERT INTO officers (name, password_hash, is_active) VALUES ('Budi', 'x', 1)"
    )
    conn.execute(
        "INSERT INTO officers (name, password_hash, is_active) VALUES ('Sari', 'x', 1)"
    )
    # Shift terbuka di lahan 1, dengan dua penugasan.
    conn.execute(
        "INSERT INTO shifts (parking_area_id, started_at) VALUES (1, '2026-01-01 07:00:00')"
    )
    conn.execute(
        "INSERT INTO shift_officers (shift_id, officer_id, token_hash, joined_at)"
        " VALUES (1, 1, 'tok-1', '2026-01-01 07:00:00')"
    )
    conn.execute(
        "INSERT INTO shift_officers (shift_id, officer_id, token_hash, joined_at)"
        " VALUES (1, 2, 'tok-2', '2026-01-01 07:05:00')"
    )
    conn.commit()


def session_insert(
    *, nim="244107020001", plate="B1234XYZ", status="active", note=None,
    checked_out_at=None, out_assignment=None, area=1, ci_assignment=1,
) -> tuple[str, tuple]:
    return (
        "INSERT INTO parking_sessions"
        " (check_in_shift_officer_id, check_out_shift_officer_id, parking_area_id,"
        "  nim, plate_in, checked_in_at, checked_out_at, status, verification_note)"
        " VALUES (?, ?, ?, ?, ?, '2026-01-01 08:00:00', ?, ?, ?)",
        (ci_assignment, out_assignment, area, nim, plate, checked_out_at, status, note),
    )


def run(conn: sqlite3.Connection) -> None:
    print("\nNilai enum terkunci")
    sql, params = session_insert(nim="244107020099", plate="B9ENUM")
    conn.execute(sql, params)
    session_id = conn.execute("SELECT last_insert_rowid()").fetchone()[0]

    ok, msg = rejects(
        conn,
        "UPDATE parking_sessions SET match_method = 'ngawur' WHERE id = ?",
        (session_id,),
    )
    check("match_method di luar tiga nilai ditolak", ok, msg)
    ok, msg = rejects(
        conn,
        "UPDATE parking_sessions SET match_method = 'plate_exact' WHERE id = ?",
        (session_id,),
    )
    check("match_method plate_exact diterima", not ok, msg)
    ok, msg = rejects(
        conn,
        "UPDATE parking_sessions SET match_method = NULL WHERE id = ?",
        (session_id,),
    )
    check("match_method boleh NULL", not ok, msg)

    for value in (
        "check_in",
        "check_out_closed",
        "check_out_rejected",
        "manual_verification",
        "check_in_voided",
    ):
        ok, msg = rejects(
            conn,
            "INSERT INTO session_events"
            " (parking_session_id, shift_officer_id, event_type, created_at)"
            " VALUES (?, 1, ?, '2026-01-01 07:00:00')",
            (session_id, value),
        )
        check(f"event_type {value} diterima", not ok, msg)

    ok, msg = rejects(
        conn,
        "INSERT INTO session_events"
        " (parking_session_id, shift_officer_id, event_type, created_at)"
        " VALUES (?, 1, 'ngawur', '2026-01-01 07:00:00')",
        (session_id,),
    )
    check("event_type di luar lima nilai ditolak", ok, msg)

    # Baris uji dibersihkan supaya tidak mengunci NIM/plat tes berikutnya.
    conn.execute("DELETE FROM parking_sessions WHERE id = ?", (session_id,))

    print("\nPeran petugas")
    ok, msg = rejects(
        conn,
        "INSERT INTO officers (name, role, is_active) VALUES ('Palsu', 'admin', 1)",
    )
    check("peran di luar officer/spv ditolak", ok, msg)
    check("nama constraint disebut", "chk_officers_role" in msg, msg)

    ok, msg = rejects(
        conn,
        "UPDATE officers SET role = 'superuser' WHERE id = 1",
    )
    check("peran tidak sah juga ditolak saat diubah", ok, msg)

    ok, msg = rejects(conn, "UPDATE officers SET role = 'spv' WHERE id = 1")
    check("peran spv diterima", not ok, msg)

    ok, msg = rejects(conn, "UPDATE officers SET role = 'officer' WHERE id = 1")
    check("peran officer diterima", not ok, msg)

    print("\nFormat NIM dan plat")
    sql, params = session_insert(nim="24410702001X")
    ok, msg = rejects(conn, sql, params)
    check("NIM mengandung huruf ditolak", ok, msg)

    sql, params = session_insert(nim="")
    ok, msg = rejects(conn, sql, params)
    check("NIM kosong ditolak", ok, msg)

    sql, params = session_insert(nim="2441 0702")
    ok, msg = rejects(conn, sql, params)
    check("NIM bertanda baca ditolak", ok, msg)

    sql, params = session_insert(plate="b1234xyz")
    ok, msg = rejects(conn, sql, params)
    check("plat huruf kecil ditolak", ok, msg)

    sql, params = session_insert(plate="B 1234 XYZ")
    ok, msg = rejects(conn, sql, params)
    check("plat bertanda baca ditolak", ok, msg)

    sql, params = session_insert()
    ok, _ = rejects(conn, sql, params)
    check("plat dan NIM sah diterima", not ok)

    print("\nSatu sesi aktif per NIM dan plat")
    sql, params = session_insert(plate="C9999ZZZ")
    ok, msg = rejects(conn, sql, params)
    check("NIM yang sama tidak bisa punya sesi aktif kedua", ok, msg)

    sql, params = session_insert(nim="244107020002")
    ok, msg = rejects(conn, sql, params)
    check("plat yang sama tidak bisa punya sesi aktif kedua", ok, msg)

    conn.execute(
        "UPDATE parking_sessions SET status='matched', checked_out_at='2026-01-01 10:00:00',"
        " check_out_shift_officer_id=2 WHERE id=1"
    )
    sql, params = session_insert(nim="244107020002")
    ok, _ = rejects(conn, sql, params)
    check("NIM bebas lagi setelah sesi ditutup", not ok)

    conn.execute(
        "UPDATE parking_sessions SET status='voided', checked_out_at=NULL,"
        " check_out_shift_officer_id=NULL, verification_note='salah input' WHERE id=2"
    )
    sql, params = session_insert(nim="244107020003", plate="B1234XYZ")
    ok, _ = rejects(conn, sql, params)
    check("plat bebas lagi setelah sesi dibatalkan", not ok)

    print("\nKonsistensi status, waktu, dan petugas penutup")
    sql, params = session_insert(
        nim="244107020004", plate="D1111AAA", status="matched"
    )
    ok, msg = rejects(conn, sql, params)
    check("status tertutup tanpa waktu keluar ditolak", ok, msg)

    sql, params = session_insert(
        nim="244107020004", plate="D1111AAA", status="active",
        checked_out_at="2026-01-01 09:00:00", out_assignment=2,
    )
    ok, msg = rejects(conn, sql, params)
    check("status aktif dengan waktu keluar ditolak", ok, msg)

    sql, params = session_insert(
        nim="244107020004", plate="D1111AAA", status="matched",
        checked_out_at="2026-01-01 07:00:00", out_assignment=2,
    )
    ok, msg = rejects(conn, sql, params)
    check("waktu keluar sebelum waktu masuk ditolak", ok, msg)

    sql, params = session_insert(
        nim="244107020004", plate="D1111AAA", status="manual_verified",
        checked_out_at="2026-01-01 09:00:00", out_assignment=2,
    )
    ok, msg = rejects(conn, sql, params)
    check("verifikasi manual tanpa catatan ditolak", ok, msg)

    sql, params = session_insert(
        nim="244107020004", plate="D1111AAA", status="manual_verified",
        checked_out_at="2026-01-01 09:00:00", out_assignment=2,
        note="plat beda satu karakter",
    )
    ok, _ = rejects(conn, sql, params)
    check("verifikasi manual dengan catatan diterima", not ok)

    sql, params = session_insert(
        nim="244107020005", plate="E2222BBB", status="voided"
    )
    ok, msg = rejects(conn, sql, params)
    check("pembatalan tanpa catatan ditolak", ok, msg)

    print("\nSiklus jaga")
    sql = (
        "INSERT INTO shifts (parking_area_id, started_at) VALUES (1, '2026-01-01 08:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("lahan yang sama tidak bisa punya dua shift terbuka", ok, msg)

    sql = (
        "INSERT INTO shifts (parking_area_id, started_at) VALUES (2, '2026-01-01 08:00:00')"
    )
    ok, _ = rejects(conn, sql)
    check("lahan lain bisa punya shift terbuka sendiri", not ok)

    sql = (
        "INSERT INTO shift_officers (shift_id, officer_id, token_hash, joined_at)"
        " VALUES (2, 1, 'tok-3', '2026-01-01 08:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("petugas tidak bisa bertugas di dua shift", ok, msg)

    sql = (
        "INSERT INTO shift_officers (shift_id, officer_id, token_hash, joined_at)"
        " VALUES (1, 1, 'tok-4', '2026-01-01 09:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("petugas tidak bisa punya dua penugasan terbuka", ok, msg)

    sql = (
        "INSERT INTO shift_officers (shift_id, officer_id, joined_at)"
        " VALUES (2, 2, '2026-01-01 08:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("penugasan terbuka tanpa token ditolak", ok, msg)

    sql = (
        "INSERT INTO shifts (parking_area_id, started_at, ended_at)"
        " VALUES (2, '2026-01-01 10:00:00', '2026-01-01 09:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("shift dengan waktu selesai sebelum mulai ditolak", ok, msg)

    sql = (
        "INSERT INTO shift_officers (shift_id, officer_id, joined_at, left_at)"
        " VALUES (1, 2, '2026-01-01 10:00:00', '2026-01-01 09:00:00')"
    )
    ok, msg = rejects(conn, sql)
    check("penugasan dengan waktu selesai sebelum mulai ditolak", ok, msg)

    conn.execute("UPDATE shifts SET ended_at='2026-01-01 15:00:00' WHERE id=1")
    sql = (
        "INSERT INTO shifts (parking_area_id, started_at) VALUES (1, '2026-01-01 15:00:00')"
    )
    ok, _ = rejects(conn, sql)
    check("lahan bebas lagi setelah shift ditutup", not ok)

    print("\nKunci asing dan penghapusan berantai")
    sql, params = session_insert(
        nim="244107020006", plate="F3333CCC", area=999
    )
    ok, msg = rejects(conn, sql, params)
    check("sesi tanpa lahan yang sah ditolak", ok, msg)

    sql, params = session_insert(
        nim="244107020006", plate="F3333CCC", ci_assignment=999
    )
    ok, msg = rejects(conn, sql, params)
    check("sesi tanpa petugas check-in yang sah ditolak", ok, msg)

    conn.execute("INSERT INTO session_events (parking_session_id, shift_officer_id, event_type, created_at) VALUES (3, 1, 'check_in', '2026-01-01 08:00:00')")
    before = conn.execute("SELECT COUNT(*) FROM session_events WHERE parking_session_id=3").fetchone()[0]
    conn.execute("DELETE FROM parking_sessions WHERE id=3")
    after = conn.execute("SELECT COUNT(*) FROM session_events WHERE parking_session_id=3").fetchone()[0]
    check("menghapus sesi ikut menghapus jejaknya", before == 1 and after == 0, f"{before} -> {after}")

    sql = "DELETE FROM officers WHERE id=1"
    ok, msg = rejects(conn, sql)
    check("petugas yang punya jejak jaga tidak bisa dihapus", ok, msg)

    print("\nPanjang NIM tidak dipatok")
    # Ditaruh di akhir karena setiap baris yang diterima akan menempati satu
    # slot "sesi aktif", sehingga bisa mengganggu pemeriksaan sebelumnya.
    for label, nim in [
        ("satu angka", "9"),
        ("lima angka", "12345"),
        ("delapan angka", "24410702"),
        ("dua belas angka", "244107020008"),
        ("tiga puluh angka", "9" * 30),
    ]:
        sql, params = session_insert(
            nim=nim, plate=f"N{len(nim)}X", ci_assignment=1
        )
        ok, msg = rejects(conn, sql, params)
        check(f"NIM {label} diterima", not ok, msg)


def main() -> int:
    create_all()
    raw = sqlite3.connect(str(_TMP / "check.db"))
    raw.create_function(
        "regexp", 2,
        lambda pattern, value: bool(
            __import__("re").search(pattern, value)
        ) if pattern and value else False,
        deterministic=True,
    )
    try:
        setup(raw)
        run(raw)
    finally:
        raw.close()
        engine.dispose()

    print("\n" + "=" * 62)
    print(f"lulus: {len(PASSED)}   gagal: {len(FAILED)}")
    if FAILED:
        print("\nyang gagal:")
        for item in FAILED:
            print(f"  - {item}")
        return 1
    print("database menegakkan seluruh invarian skema.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
