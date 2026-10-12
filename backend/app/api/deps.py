"""Dependency FastAPI: sesi database, service, dan penugasan aktif.

Seluruh operasi tulis mengambil penanggung jawabnya dari sini — dari token yang
dikirim klien — dan tidak pernah dari isi permintaan.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database import get_db
from app.errors import AssignmentNotFound, AuthError, NotSpv
from app.models import Officer, OfficerSession, ShiftOfficer
from app.security import hash_token
from app.services.session import SessionService
from app.services.shift import ShiftService

DbSession = Annotated[Session, Depends(get_db)]


def get_shift_service(db: DbSession) -> ShiftService:
    return ShiftService(db)


def get_session_service(db: DbSession) -> SessionService:
    return SessionService(db)


ShiftSvc = Annotated[ShiftService, Depends(get_shift_service)]
SessionSvc = Annotated[SessionService, Depends(get_session_service)]


def require_assignment(
    shifts: ShiftSvc,
    x_shift_token: Annotated[str | None, Header(alias="X-Shift-Token")] = None,
) -> ShiftOfficer:
    """Memastikan permintaan datang dari petugas yang sedang bertugas."""
    if not x_shift_token:
        raise AuthError(
            "Header X-Shift-Token wajib dikirim.",
            details={"header": "X-Shift-Token"},
        )

    assignment = shifts.resolve_token(x_shift_token)
    if assignment is None:
        raise AssignmentNotFound(
            "Penugasan jaga tidak aktif. Silakan masuk ulang."
        )
    return assignment


CurrentAssignment = Annotated[ShiftOfficer, Depends(require_assignment)]

def require_session(
    db: DbSession,
    x_officer_token: Annotated[str | None, Header(alias="X-Officer-Token")] = None,
) -> OfficerSession:
    """Memastikan permintaan datang dari petugas yang sudah masuk.

    Dipakai operasi yang berjalan **di luar** shift: mengelola lahan dan
    mengatur shift jaga. Sesi parkir tetap memakai :func:`require_assignment`,
    karena setiap sesi wajib punya penanggung jawab jaga.
    """
    if not x_officer_token:
        raise AuthError(
            "Header X-Officer-Token wajib dikirim.",
            details={"header": "X-Officer-Token"},
        )

    session = db.scalar(
        select(OfficerSession).where(
            OfficerSession.token_hash == hash_token(x_officer_token),
            OfficerSession.revoked_at.is_(None),
        )
    )
    if session is None or session.officer is None or not session.officer.is_active:
        raise AuthError("Sesi petugas tidak berlaku. Silakan masuk ulang.")
    return session

def require_officer(
    session: Annotated[OfficerSession, Depends(require_session)],
) -> Officer:
    """Petugas di balik sesi yang sedang aktif."""
    return session.officer

def require_spv(officer: Annotated[Officer, Depends(require_officer)]) -> Officer:
    """Membatasi operasi pengelolaan hanya untuk pengawas (SPV)."""
    if not officer.is_spv:
        raise NotSpv(
            "Hanya pengawas (SPV) yang boleh mengelola lahan dan shift jaga."
        )
    return officer

CurrentSession = Annotated[OfficerSession, Depends(require_session)]
CurrentOfficer = Annotated[Officer, Depends(require_officer)]
CurrentSpv = Annotated[Officer, Depends(require_spv)]
