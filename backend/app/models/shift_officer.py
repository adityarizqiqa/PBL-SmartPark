"""Penugasan petugas dalam satu shift.

Satu baris = satu penugasan: seorang petugas ikut serta dalam satu shift dan
memegang token sendiri. Inilah penunjuk identitas yang dipakai sesi dan event,
sehingga penanggung jawab tetap bisa dibedakan meski beberapa petugas memakai
shift dan perangkat yang sama.
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import (
    CheckConstraint,
    Computed,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, FK
from app.models.mixins import TimestampMixin

_ACTIVE_OFFICER = "CASE WHEN left_at IS NULL THEN officer_id ELSE NULL END"


class ShiftOfficer(TimestampMixin, Base):
    __tablename__ = "shift_officers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    shift_id: Mapped[int] = mapped_column(
        FK, ForeignKey("shifts.id"), nullable=False
    )
    officer_id: Mapped[int] = mapped_column(
        FK, ForeignKey("officers.id"), nullable=False
    )
    token_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    joined_at: Mapped[dt.datetime] = mapped_column(DateTime, nullable=False)
    left_at: Mapped[dt.datetime | None] = mapped_column(DateTime, nullable=True)
    left_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    active_officer_id: Mapped[int | None] = mapped_column(
        FK, Computed(_ACTIVE_OFFICER, persisted=True), nullable=True
    )

    shift: Mapped["Shift"] = relationship(  # noqa: F821
        back_populates="assignments", lazy="joined"
    )
    officer: Mapped["Officer"] = relationship(  # noqa: F821
        back_populates="assignments", lazy="joined"
    )

    __table_args__ = (
        UniqueConstraint(
            "active_officer_id", name="uq_shift_officers_active_officer"
        ),
        UniqueConstraint("token_hash", name="uq_shift_officers_token"),
        Index("idx_shift_officers_shift", "shift_id", "joined_at"),
        Index("idx_shift_officers_officer", "officer_id", "joined_at"),
        CheckConstraint(
            "left_at IS NULL OR left_at >= joined_at",
            name="chk_shift_officers_period",
        ),
        CheckConstraint(
            "left_at IS NOT NULL OR token_hash IS NOT NULL",
            name="chk_shift_officers_open_token",
        ),
    )

    @property
    def is_active(self) -> bool:
        return self.left_at is None

    @property
    def officer_name(self) -> str:
        return self.officer.name

    @property
    def area(self) -> "ParkingArea":  # noqa: F821
        return self.shift.area
