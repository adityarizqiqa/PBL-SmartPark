"""Masuk dan keluar petugas di luar shift.

Petugas memilih namanya dari daftar dan memasukkan password. Sesi ini yang
menjadi penanggung jawab operasi pengelolaan — menambah lahan dan mengatur
shift jaga — yaitu operasi yang berjalan sebelum ada shift sama sekali.

Sesi parkir tetap memakai token penugasan jaga (§5.5), karena setiap sesi
wajib punya penanggung jawab jaga.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.clock import utcnow
from app.errors import (
    ConflictError,
    InactiveOfficer,
    InvalidCredentials,
    OfficerNotFound,
    PasswordNotSet,
)
from app.models import Officer, OfficerSession
from app.schemas.auth import SignInForm
from app.security import generate_token, hash_token, limiter, verify_password


class AuthService:
    """Siklus sesi masuk petugas."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def sign_in(self, form: SignInForm) -> tuple[str, OfficerSession]:
        """Memeriksa kredensial dan menerbitkan token sesi.

        Mengembalikan token mentah (hanya sekali ini) beserta sesinya.
        """
        limiter.check(form.officer_id)

        officer = self.db.get(Officer, form.officer_id)
        if officer is None:
            raise OfficerNotFound("Petugas tidak ditemukan.")
        if not officer.is_active:
            raise InactiveOfficer("Petugas ini sudah tidak aktif.")
        if not officer.password_hash:
            raise PasswordNotSet("Password petugas ini belum diatur admin.")
        if not verify_password(form.password, officer.password_hash):
            raise InvalidCredentials("Password salah.")

        limiter.reset(form.officer_id)

        token = generate_token()
        session = OfficerSession(
            officer_id=officer.id,
            token_hash=hash_token(token),
            signed_in_at=utcnow(),
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return token, session

    def sign_out(self, session: OfficerSession) -> OfficerSession:
        """Menutup sesi; tokennya langsung mati."""
        if session.revoked_at is not None:
            raise ConflictError("Sesi ini sudah ditutup.")
        session.revoked_at = utcnow()
        self.db.commit()
        self.db.refresh(session)
        return session

    def resolve_token(self, token: str) -> OfficerSession | None:
        """Mencari sesi aktif dari token yang dikirim klien."""
        return self.db.scalar(
            select(OfficerSession).where(
                OfficerSession.token_hash == hash_token(token),
                OfficerSession.revoked_at.is_(None),
            )
        )
