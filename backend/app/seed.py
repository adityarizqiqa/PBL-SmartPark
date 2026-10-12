"""Mengisi data awal: lahan, petugas, dan contoh sesi.

Jalankan dengan::

    python -m app.seed            # isi bila masih kosong
    python -m app.seed --reset    # hapus database lalu isi ulang
"""

from __future__ import annotations

import argparse
import sys

from sqlalchemy import select

from app.clock import utcnow
from app.config import settings
from app.database import SessionLocal, create_all, engine
from app.migrations import apply_migrations
from app.models import (
    EventType,
    Officer,
    ParkingArea,
    ParkingSession,
    ROLE_OFFICER,
    ROLE_SPV,
    SessionEvent,
    SessionStatus,
    Shift,
    ShiftOfficer,
)
from app.security import generate_token, hash_password, hash_token

AREAS = [
    ("POS-UTAMA", "Pos Parkir Utama"),
    ("POS-FT", "Pos Parkir Fakultas Teknik"),
]

OFFICERS = [
    ("PK001", "Budi Santoso", "081200000001", "budi1234"),
    ("PK002", "Sari Wulandari", "081200000002", "sari1234"),
    ("PK003", "Agus Prasetyo", "081200000003", "agus1234"),
]

#: Pengawas lapangan: boleh menambah lahan dan mengatur shift jaga.
SPV = ("SPV001", "Dewi Kartika", "081200000010", "dewi1234")


def reset_database() -> None:
    """Menghapus berkas database agar bisa dibuat ulang dari nol."""
    if not settings.is_sqlite:
        raise SystemExit("Reset hanya didukung untuk SQLite.")

    path = settings.database_url.replace("sqlite:///", "", 1)
    from pathlib import Path

    for suffix in ("", "-wal", "-shm"):
        candidate = Path(path + suffix)
        if candidate.exists():
            candidate.unlink()
    print(f"Database lama dihapus: {path}")


def seed() -> None:
    create_all()
    db = SessionLocal()

    try:
        if db.scalar(select(ParkingArea).limit(1)) is not None:
            print("Data sudah ada. Pakai --reset bila ingin mengisi ulang.")
            return

        areas = [
            ParkingArea(code=code, name=name, is_active=True)
            for code, name in AREAS
        ]
        db.add_all(areas)
        db.flush()

        officers = [
            Officer(
                employee_no=employee_no,
                name=name,
                phone=phone,
                password_hash=hash_password(password),
                role=ROLE_OFFICER,
                is_active=True,
            )
            for employee_no, name, phone, password in OFFICERS
        ]
        spv_employee_no, spv_name, spv_phone, spv_password = SPV
        officers.append(
            Officer(
                employee_no=spv_employee_no,
                name=spv_name,
                phone=spv_phone,
                password_hash=hash_password(spv_password),
                role=ROLE_SPV,
                is_active=True,
            )
        )
        db.add_all(officers)
        db.flush()

        # Satu shift di pos utama, dijalani dua petugas sekaligus.
        # Token dibuat sungguhan supaya bisa langsung dipakai saat mencoba API.
        shift = Shift(
            parking_area_id=areas[0].id,
            started_at=utcnow(),
        )
        db.add(shift)
        db.flush()

        tokens: dict[str, str] = {}
        assignments = []
        for officer in officers[:2]:
            token = generate_token()
            tokens[officer.name] = token
            assignments.append(
                ShiftOfficer(
                    shift_id=shift.id,
                    officer_id=officer.id,
                    token_hash=hash_token(token),
                    joined_at=utcnow(),
                )
            )
        db.add_all(assignments)
        db.flush()

        budi, sari = assignments[0], assignments[1]

        # Satu motor masih parkir. Panjang NIM sengaja dibuat berbeda-beda
        # untuk menunjukkan bahwa panjangnya memang tidak dipatok.
        active = ParkingSession(
            check_in_shift_officer_id=budi.id,
            parking_area_id=areas[0].id,
            nim="244107020008",
            plate_in="B1234XYZ",
            checked_in_at=utcnow(),
            status=SessionStatus.ACTIVE.value,
        )
        db.add(active)
        db.flush()
        db.add(
            SessionEvent(
                parking_session_id=active.id,
                shift_officer_id=budi.id,
                event_type=EventType.CHECK_IN.value,
                created_at=utcnow(),
            )
        )

        # Satu motor sudah keluar, ditutup petugas berbeda.
        closed = ParkingSession(
            check_in_shift_officer_id=budi.id,
            check_out_shift_officer_id=sari.id,
            parking_area_id=areas[0].id,
            nim="24410702021",
            plate_in="D5678ABC",
            plate_out="D5678ABC",
            checked_in_at=utcnow(),
            checked_out_at=utcnow(),
            status=SessionStatus.MATCHED.value,
            match_method="plate_exact",
        )
        db.add(closed)
        db.flush()
        db.add_all(
            [
                SessionEvent(
                    parking_session_id=closed.id,
                    shift_officer_id=budi.id,
                    event_type=EventType.CHECK_IN.value,
                    created_at=utcnow(),
                ),
                SessionEvent(
                    parking_session_id=closed.id,
                    shift_officer_id=sari.id,
                    event_type=EventType.CHECK_OUT_CLOSED.value,
                    created_at=utcnow(),
                ),
            ]
        )

        db.commit()
        print("Data awal dibuat:")
        print(f"  lahan    : {', '.join(code for code, _ in AREAS)}")
        print(f"  petugas  : {', '.join(name for _, name, _, _ in OFFICERS)}")
        print(f"  pengawas : {spv_name} (SPV)")
        print("  password : budi1234 / sari1234 / agus1234 / dewi1234 (SPV)")
        print("  sesi     : 1 aktif, 1 sudah ditutup")
        print("\n  Token shift yang sedang terbuka (header X-Shift-Token):")
        for name, token in tokens.items():
            print(f"    {name:18} {token}")
        print(
            "\n  Agus belum bertugas. Untuk mencobanya:\n"
            "    POST /api/shifts/join"
            ' {"officer_id": 3, "password": "agus1234", "parking_area_id": 2}'
        )
    finally:
        db.close()
        engine.dispose()


def ensure_spv() -> None:
    """Menambahkan pengawas bila belum ada.

    Database pengembangan yang sudah terisi tidak lewat jalur :func:`seed`,
    sehingga bisa saja belum punya pengawas sama sekali — dan tanpa pengawas
    tidak ada yang bisa menambah lahan atau mengatur shift.
    """
    create_all()
    apply_migrations()
    db = SessionLocal()
    try:
        existing = db.scalar(select(Officer).where(Officer.role == ROLE_SPV))
        if existing is not None:
            print(f"Pengawas sudah ada: {existing.name} ({existing.employee_no})")
            return

        employee_no, name, phone, password = SPV
        officer = Officer(
            employee_no=employee_no,
            name=name,
            phone=phone,
            password_hash=hash_password(password),
            role=ROLE_SPV,
            is_active=True,
        )
        db.add(officer)
        try:
            db.commit()
        except Exception as exc:  # noqa: BLE001
            db.rollback()
            raise SystemExit(
                f"Gagal menambah pengawas: {exc}"
            ) from exc
        print(f"Pengawas dibuat: {name} ({employee_no}) — password: {password}")
    finally:
        db.close()
        engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Isi data awal SmartPark.")
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Hapus database SQLite lalu buat ulang dari nol.",
    )
    parser.add_argument(
        "--ensure-spv",
        action="store_true",
        help="Tambahkan pengawas (SPV) bila database belum punya.",
    )
    args = parser.parse_args()

    if args.ensure_spv:
        ensure_spv()
        return

    if args.reset:
        reset_database()
    try:
        seed()
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
