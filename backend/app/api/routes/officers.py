"""Endpoint petugas.

Daftar petugas aktif dipakai aplikasi untuk layar pilih-nama saat mulai
bertugas. Pengelolaan akun (buat, ubah, atur password) juga ada di sini karena
tidak ada antarmuka admin terpisah pada tahap ini.
"""

from __future__ import annotations

from fastapi import APIRouter, status
from sqlalchemy import select

from app.api.deps import CurrentSpv, DbSession
from app.errors import ConflictError, OfficerNotFound
from app.integrity import matches
from app.models import Officer
from app.schemas.officer import OfficerCreate, OfficerOut, OfficerUpdate
from app.security import hash_password

router = APIRouter(prefix="/officers", tags=["petugas"])


@router.get("", response_model=list[OfficerOut])
def list_officers(db: DbSession, include_inactive: bool = False) -> list[Officer]:
    """Daftar petugas untuk layar pilih-nama."""
    stmt = select(Officer).order_by(Officer.name)
    if not include_inactive:
        stmt = stmt.where(Officer.is_active.is_(True))
    return list(db.scalars(stmt).all())


@router.get("/{officer_id}", response_model=OfficerOut)
def get_officer(officer_id: int, db: DbSession) -> Officer:
    officer = db.get(Officer, officer_id)
    if officer is None:
        raise OfficerNotFound("Petugas tidak ditemukan.")
    return officer


@router.post("", response_model=OfficerOut, status_code=status.HTTP_201_CREATED)
def create_officer(
    payload: OfficerCreate, db: DbSession, _spv: CurrentSpv
) -> Officer:
    """Membuat akun petugas. Hanya pengawas yang boleh.

    Tanpa penjagaan ini, siapa pun bisa membuat akun ber-``role = 'spv'`` dan
    menaikkan perannya sendiri — seluruh pemisahan wewenang jadi sia-sia.
    """
    officer = Officer(
        employee_no=(payload.employee_no or "").strip() or None,
        name=payload.name.strip(),
        phone=(payload.phone or "").strip() or None,
        role=payload.role,
        password_hash=hash_password(payload.password),
        is_active=True,
    )
    db.add(officer)
    try:
        db.commit()
    except Exception as exc:  # noqa: BLE001
        db.rollback()
        if matches(exc, "uq_officers_employee_no", "officers.employee_no"):
            raise ConflictError("NIP petugas ini sudah dipakai.") from exc
        raise
    db.refresh(officer)
    return officer


@router.patch("/{officer_id}", response_model=OfficerOut)
def update_officer(
    officer_id: int, payload: OfficerUpdate, db: DbSession, _spv: CurrentSpv
) -> Officer:
    """Mengubah data atau peran petugas. Hanya pengawas yang boleh."""
    officer = db.get(Officer, officer_id)
    if officer is None:
        raise OfficerNotFound("Petugas tidak ditemukan.")

    if payload.name is not None:
        officer.name = payload.name.strip()
    if payload.phone is not None:
        officer.phone = payload.phone.strip() or None
    if payload.role is not None:
        officer.role = payload.role
    if payload.is_active is not None:
        officer.is_active = payload.is_active
    if payload.password is not None:
        officer.password_hash = hash_password(payload.password)

    db.commit()
    db.refresh(officer)
    return officer
