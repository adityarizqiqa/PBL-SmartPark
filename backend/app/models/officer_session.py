"""Sesi masuk petugas di luar shift.

Petugas memilih namanya dari daftar dan memasukkan password. Sebelum perubahan
ini, password hanya dipakai sekali saat bergabung ke shift; akibatnya operasi
yang berjalan **sebelum** ada shift — menambah lahan dan mengatur shift jaga —
tidak punya penanggung jawab.

Tabel ini menutup celah itu: satu baris = satu sesi masuk, dengan token
tersendiri yang berlaku sampai petugas keluar. Sesi parkir tidak memakai token
ini; ia tetap memakai token penugasan jaga (§5.5), karena setiap sesi wajib
punya penanggung jawab jaga.
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, FK
from app.models.mixins import TimestampMixin


class OfficerSession(TimestampMixin, Base):
    __tablename__ = "officer_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    officer_id: Mapped[int] = mapped_column(
        FK, ForeignKey("officers.id"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    signed_in_at: Mapped[dt.datetime] = mapped_column(DateTime, nullable=False)
    revoked_at: Mapped[dt.datetime | None] = mapped_column(DateTime, nullable=True)

    officer: Mapped["Officer"] = relationship(lazy="joined")  # noqa: F821

    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_officer_sessions_token"),
        Index("idx_officer_sessions_officer", "officer_id", "signed_in_at"),
    )

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None

    @property
    def officer_name(self) -> str:
        return self.officer.name

    @property
    def role(self) -> str:
        return self.officer.role
