"""Periode jaga di satu lahan.

Shift tidak memuat identitas petugas. Siapa saja yang bertugas dicatat di
``shift_officers``, sehingga beberapa petugas bisa menjalani satu shift yang
sama. Satu lahan hanya boleh punya satu shift terbuka, dijaga oleh generated
column ``active_area_id`` dan unique index di atasnya.
"""

from __future__ import annotations

import datetime as dt

from sqlalchemy import (
    CheckConstraint,
    Computed,
    DateTime,
    ForeignKey,
    Index,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, FK
from app.models.mixins import TimestampMixin

_ACTIVE_AREA = "CASE WHEN ended_at IS NULL THEN parking_area_id ELSE NULL END"


class Shift(TimestampMixin, Base):
    __tablename__ = "shifts"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    parking_area_id: Mapped[int] = mapped_column(
        FK, ForeignKey("parking_areas.id"), nullable=False
    )
    started_at: Mapped[dt.datetime] = mapped_column(DateTime, nullable=False)
    ended_at: Mapped[dt.datetime | None] = mapped_column(DateTime, nullable=True)
    end_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    active_area_id: Mapped[int | None] = mapped_column(
        FK, Computed(_ACTIVE_AREA, persisted=True), nullable=True
    )

    area: Mapped["ParkingArea"] = relationship(  # noqa: F821
        back_populates="shifts", lazy="joined"
    )
    assignments: Mapped[list["ShiftOfficer"]] = relationship(  # noqa: F821
        back_populates="shift", lazy="selectin"
    )

    __table_args__ = (
        UniqueConstraint("active_area_id", name="uq_shifts_active_area"),
        Index("idx_shifts_area_period", "parking_area_id", "started_at", "ended_at"),
        CheckConstraint(
            "ended_at IS NULL OR ended_at >= started_at", name="chk_shifts_period"
        ),
    )

    @property
    def is_open(self) -> bool:
        return self.ended_at is None

    @property
    def area_name(self) -> str:
        return self.area.name
