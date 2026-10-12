"""Pengubahan model menjadi bentuk respons.

Dibuat eksplisit agar bentuk keluaran API tidak bergantung pada nama atribut
model, dan agar kolom sensitif tidak pernah ikut terkirim.
"""

from __future__ import annotations

from app.models import ParkingSession
from app.schemas.session import (
    ActiveSessionOut,
    LookupCandidateOut,
    SessionEventOut,
)

EVENT_LABELS = {
    "check_in": "Check-in",
    "check_out_closed": "Sesi ditutup",
    "check_out_rejected": "Check-out ditolak",
    "manual_verification": "Verifikasi manual",
    "check_in_voided": "Check-in dibatalkan",
}


def active_session(row: ParkingSession, duration_minutes: int) -> ActiveSessionOut:
    return ActiveSessionOut(
        id=row.id,
        nim=row.nim,
        plate_in=row.plate_in,
        checked_in_at=row.checked_in_at,
        duration_minutes=duration_minutes,
        area_id=row.parking_area_id,
        area_name=row.area_name,
        checked_in_by=row.check_in_assignment.officer_name,
    )


def candidate(row: ParkingSession) -> LookupCandidateOut:
    """Kandidat hanya memuat plat dan waktu.

    Angka kemiripan sengaja tidak dikirim: petugas membandingkan plat secara
    visual, bukan lewat skor.
    """
    return LookupCandidateOut(
        session_id=row.id,
        plate_in=row.plate_in,
        checked_in_at=row.checked_in_at,
        area_name=row.area_name,
    )


def event(row) -> SessionEventOut:
    return SessionEventOut(
        id=row.id,
        event_type=row.event_type,
        note=row.note,
        actor_name=row.actor_name,
        created_at=row.created_at,
    )
