"""Sesi parkir — tabel inti.

Dua generated column menjadi penegak aturan "satu sesi aktif per NIM/plat":
``active_nim`` dan ``active_plate`` hanya berisi nilai saat status masih
``active``, dan unique index di atasnya otomatis membebaskan nilai itu begitu
sesi ditutup atau dibatalkan.
"""

from __future__ import annotations

import datetime as dt
import enum

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


class SessionStatus(str, enum.Enum):
    ACTIVE = "active"
    MATCHED = "matched"
    MANUAL_VERIFIED = "manual_verified"
    VOIDED = "voided"


class MatchMethod(str, enum.Enum):
    PLATE_EXACT = "plate_exact"
    PLATE_SIMILAR = "plate_similar"
    NIM_FALLBACK = "nim_fallback"


_ACTIVE_NIM = "CASE WHEN status = 'active' THEN nim ELSE NULL END"
_ACTIVE_PLATE = "CASE WHEN status = 'active' THEN plate_in ELSE NULL END"


class ParkingSession(TimestampMixin, Base):
    __tablename__ = "parking_sessions"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    check_in_shift_officer_id: Mapped[int] = mapped_column(
        FK, ForeignKey("shift_officers.id"), nullable=False
    )
    check_out_shift_officer_id: Mapped[int | None] = mapped_column(
        FK, ForeignKey("shift_officers.id"), nullable=True
    )
    parking_area_id: Mapped[int] = mapped_column(
        FK, ForeignKey("parking_areas.id"), nullable=False
    )

    nim: Mapped[str] = mapped_column(String(32), nullable=False)
    plate_in: Mapped[str] = mapped_column(String(12), nullable=False)
    plate_out: Mapped[str | None] = mapped_column(String(12), nullable=True)

    checked_in_at: Mapped[dt.datetime] = mapped_column(DateTime, nullable=False)
    checked_out_at: Mapped[dt.datetime | None] = mapped_column(
        DateTime, nullable=True
    )

    status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=SessionStatus.ACTIVE.value
    )
    match_method: Mapped[str | None] = mapped_column(String(20), nullable=True)
    verification_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    plate_in_photo_path: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    plate_out_photo_path: Mapped[str | None] = mapped_column(
        String(255), nullable=True
    )
    client_request_id: Mapped[str | None] = mapped_column(
        String(36), nullable=True
    )

    active_nim: Mapped[str | None] = mapped_column(
        String(32), Computed(_ACTIVE_NIM, persisted=True), nullable=True
    )
    active_plate: Mapped[str | None] = mapped_column(
        String(12), Computed(_ACTIVE_PLATE, persisted=True), nullable=True
    )

    area: Mapped["ParkingArea"] = relationship(  # noqa: F821
        back_populates="sessions", lazy="joined"
    )
    check_in_assignment: Mapped["ShiftOfficer"] = relationship(  # noqa: F821
        foreign_keys=[check_in_shift_officer_id], lazy="joined"
    )
    check_out_assignment: Mapped["ShiftOfficer | None"] = relationship(  # noqa: F821
        foreign_keys=[check_out_shift_officer_id], lazy="joined"
    )
    events: Mapped[list["SessionEvent"]] = relationship(  # noqa: F821
        back_populates="session",
        lazy="selectin",
        order_by="SessionEvent.created_at",
    )

    __table_args__ = (
        UniqueConstraint("active_nim", name="uq_sessions_active_nim"),
        UniqueConstraint("active_plate", name="uq_sessions_active_plate"),
        UniqueConstraint("client_request_id", name="uq_sessions_client_request"),
        Index("idx_sessions_status_in", "status", "checked_in_at"),
        Index("idx_sessions_nim", "nim", "checked_in_at"),
        Index("idx_sessions_plate_in", "plate_in"),
        Index("idx_sessions_plate_out", "plate_out"),
        Index("idx_sessions_area_in", "parking_area_id", "checked_in_at"),
        Index("idx_sessions_in_assign", "check_in_shift_officer_id"),
        Index("idx_sessions_out_assign", "check_out_shift_officer_id"),
        Index("idx_sessions_out_at", "checked_out_at"),
        Index("idx_sessions_updated", "updated_at"),
        CheckConstraint("nim REGEXP '^[0-9]+$'", name="chk_sessions_nim"),
        CheckConstraint(
            "plate_in REGEXP '^[A-Z0-9]{1,12}$'", name="chk_sessions_plate_in"
        ),
        CheckConstraint(
            "plate_out IS NULL OR plate_out REGEXP '^[A-Z0-9]{1,12}$'",
            name="chk_sessions_plate_out",
        ),
        CheckConstraint(
            "checked_out_at IS NULL OR checked_out_at >= checked_in_at",
            name="chk_sessions_period",
        ),
        CheckConstraint(
            "(status IN ('active','voided') AND checked_out_at IS NULL "
            "AND check_out_shift_officer_id IS NULL) OR "
            "(status IN ('matched','manual_verified') "
            "AND checked_out_at IS NOT NULL "
            "AND check_out_shift_officer_id IS NOT NULL)",
            name="chk_sessions_status_times",
        ),
        CheckConstraint(
            "status NOT IN ('manual_verified','voided') OR "
            "(verification_note IS NOT NULL AND verification_note <> '')",
            name="chk_sessions_manual_note",
        ),
        CheckConstraint(
            "match_method IS NULL OR match_method IN "
            "('plate_exact','plate_similar','nim_fallback')",
            name="chk_sessions_match_method",
        ),
    )

    @property
    def is_active(self) -> bool:
        return self.status == SessionStatus.ACTIVE.value

    @property
    def area_name(self) -> str:
        return self.area.name

    @staticmethod
    def _officer_ref(assignment: "ShiftOfficer | None") -> dict | None:  # noqa: F821
        if assignment is None:
            return None
        return {
            "assignment_id": assignment.id,
            "officer_id": assignment.officer_id,
            "officer_name": assignment.officer_name,
        }

    @property
    def checked_in_by(self) -> dict:
        return self._officer_ref(self.check_in_assignment)

    @property
    def checked_out_by(self) -> dict | None:
        return self._officer_ref(self.check_out_assignment)
