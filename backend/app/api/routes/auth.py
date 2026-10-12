"""Endpoint masuk/keluar petugas.

Sesi ini dipakai operasi pengelolaan (lahan dan shift jaga). Sesi parkir
memakai ``POST /api/shifts/join`` yang menerbitkan token penugasan jaga.
"""

from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentOfficer, CurrentSession, DbSession
from app.schemas.auth import SessionOut, SignInForm, SignInOut
from app.schemas.officer import OfficerOut
from app.services.auth import AuthService

router = APIRouter(prefix="/auth", tags=["masuk"])


def _session_out(session) -> SessionOut:
    return SessionOut(
        id=session.id,
        officer_id=session.officer_id,
        officer_name=session.officer_name,
        role=session.role,
        signed_in_at=session.signed_in_at,
        revoked_at=session.revoked_at,
        is_active=session.is_active,
    )


@router.post("/sign-in", response_model=SignInOut)
def sign_in(payload: SignInForm, db: DbSession) -> SignInOut:
    """Petugas masuk dan menerima token sesi."""
    token, session = AuthService(db).sign_in(payload)
    return SignInOut(token=token, session=_session_out(session))


@router.post("/sign-out", response_model=SessionOut)
def sign_out(db: DbSession, session: CurrentSession) -> SessionOut:
    """Petugas keluar; tokennya langsung mati."""
    return _session_out(AuthService(db).sign_out(session))


@router.get("/me", response_model=OfficerOut)
def me(officer: CurrentOfficer) -> OfficerOut:
    """Petugas yang sedang masuk beserta perannya."""
    return officer
