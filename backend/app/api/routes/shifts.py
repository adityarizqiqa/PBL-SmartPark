"""Endpoint siklus jaga.

Petugas masuk dengan memilih namanya dan memasukkan password. Bila di lahan itu
sudah ada shift terbuka, ia bergabung ke shift tersebut; bila belum, shift baru
dibuat. Token yang dikembalikan berlaku sampai ia berhenti bertugas.
"""

from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import select

from app.api.deps import (
    CurrentAssignment,
    CurrentSession,
    CurrentSpv,
    DbSession,
    ShiftSvc,
)
from app.errors import (
    AreaNotFound,
    AssignmentNotFound,
    ConflictError,
    ShiftNotFound,
)
from app.models import ParkingArea, Shift, ShiftOfficer
from app.schemas.shift import (
    AssignmentLeaveForm,
    AssignmentOut,
    ShiftCloseForm,
    ShiftJoinForm,
    ShiftLoginOut,
    ShiftOpenForm,
    ShiftOut,
)

router = APIRouter(prefix="/shifts", tags=["jaga"])


def _assignment_out(a: ShiftOfficer) -> AssignmentOut:
    return AssignmentOut(
        id=a.id,
        shift_id=a.shift_id,
        officer_id=a.officer_id,
        officer_name=a.officer_name,
        joined_at=a.joined_at,
        left_at=a.left_at,
        left_note=a.left_note,
    )


def _shift_out(shift: Shift) -> ShiftOut:
    return ShiftOut(
        id=shift.id,
        parking_area_id=shift.parking_area_id,
        area_name=shift.area_name,
        started_at=shift.started_at,
        ended_at=shift.ended_at,
        end_note=shift.end_note,
        is_open=shift.is_open,
        assignments=[_assignment_out(a) for a in shift.assignments],
    )


@router.post("/join", response_model=ShiftLoginOut)
def join_shift(payload: ShiftJoinForm, shifts: ShiftSvc) -> ShiftLoginOut:
    """Petugas mulai bertugas dan menerima token."""
    token, assignment = shifts.join(payload)
    return ShiftLoginOut(
        token=token,
        assignment=_assignment_out(assignment),
        shift=_shift_out(assignment.shift),
    )


@router.get("/current", response_model=ShiftOut)
def current_shift(assignment: CurrentAssignment) -> ShiftOut:
    """Shift yang sedang dijalani petugas ini."""
    return _shift_out(assignment.shift)


@router.get("", response_model=list[ShiftOut])
def list_shifts(
    db: DbSession,
    _session: CurrentSession,
    area_id: int | None = None,
    open_only: bool = False,
) -> list[ShiftOut]:
    """Riwayat dan shift terbuka per lahan.

    Butuh sesi masuk: responsnya memuat nama petugas yang bertugas, jadi tidak
    boleh terbuka untuk umum. Daftar lahan dan petugas tetap terbuka karena
    layar masuk membutuhkannya sebelum ada token.
    """
    stmt = select(Shift).order_by(Shift.started_at.desc())
    if area_id is not None:
        stmt = stmt.where(Shift.parking_area_id == area_id)
    if open_only:
        stmt = stmt.where(Shift.ended_at.is_(None))
    return [_shift_out(row) for row in db.scalars(stmt).all()]


@router.post("/leave", response_model=AssignmentOut)
def leave_shift(
    assignment: CurrentAssignment,
    shifts: ShiftSvc,
    payload: AssignmentLeaveForm | None = None,
) -> AssignmentOut:
    """Petugas berhenti bertugas; tokennya langsung mati.

    Bila tidak ada lagi petugas yang bertugas, shiftnya ikut ditutup.
    """
    note = (payload.note if payload else None) or None
    updated = shifts.leave(assignment, note)
    return _assignment_out(updated)


@router.post("/open", response_model=ShiftOut, status_code=201)
def open_shift(
    payload: ShiftOpenForm, shifts: ShiftSvc, db: DbSession, _spv: CurrentSpv
) -> ShiftOut:
    """Pengawas membuka shift jaga lebih dulu.

    Petugas yang datang berikutnya bergabung ke shift ini lewat
    ``POST /api/shifts/join``.
    """
    area = db.get(ParkingArea, payload.parking_area_id)
    if area is None:
        raise AreaNotFound("Lahan parkir tidak ditemukan.")
    return _shift_out(shifts.open_shift(area))


@router.post("/{shift_id}/close", response_model=ShiftOut)
def close_shift(
    shift_id: int,
    shifts: ShiftSvc,
    db: DbSession,
    _spv: CurrentSpv,
    payload: ShiftCloseForm | None = None,
) -> ShiftOut:
    """Menutup shift beserta seluruh penugasan yang masih terbuka.

    Dipakai saat shift lupa ditutup. Baris tidak dihapus, hanya diberi waktu
    selesai.
    """
    shift = db.get(Shift, shift_id)
    if shift is None:
        raise ShiftNotFound("Shift tidak ditemukan.")
    note = (payload.note if payload else None) or None
    return _shift_out(shifts.close_shift(shift, note))


@router.get("/assignments/{assignment_id}", response_model=AssignmentOut)
def get_assignment(
    assignment_id: int, db: DbSession, _session: CurrentSession
) -> AssignmentOut:
    """Satu penugasan jaga. Butuh sesi karena memuat nama petugas."""
    assignment = db.get(ShiftOfficer, assignment_id)
    if assignment is None:
        raise AssignmentNotFound("Penugasan tidak ditemukan.")
    return _assignment_out(assignment)
