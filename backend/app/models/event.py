"""Jejak audit sesi.

Menampung hal yang tidak terwakili oleh kolom sesi: penolakan check-out,
pembatalan check-in, dan riwayat verifikasi manual.
"""

from __future__ import annotations

import datetime as dt
import enum

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, FK
from app.models.mixins import utcnow


class EventType(str, enum.Enum):
    CHECK_IN = "check_in"
    CHECK_OUT_CLOSED = "check_out_closed"
    CHECK_OUT_REJECTED = "check_out_rejected"
    MANUAL_VERIFICATION = "manual_verification"
    CHECK_IN_VOIDED = "check_in_voided"


class SessionEvent(Base):
    __tablename__ = "session_events"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    parking_session_id: Mapped[int] = mapped_column(
        FK, ForeignKey("parking_sessions.id", ondelete="CASCADE"), nullable=False
    )
    shift_officer_id: Mapped[int] = mapped_column(
        FK, ForeignKey("shift_officers.id"), nullable=False
    )
    event_type: Mapped[str] = mapped_column(String(32), nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(
        "metadata", JSON, nullable=True
    )
    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow
    )

    session: Mapped["ParkingSession"] = relationship(  # noqa: F821
        back_populates="events", lazy="noload"
    )
    actor: Mapped["ShiftOfficer"] = relationship(lazy="joined")  # noqa: F821

    __table_args__ = (
        Index("idx_events_session", "parking_session_id", "created_at"),
        Index("idx_events_shift_officer", "shift_officer_id"),
        CheckConstraint(
            "event_type IN ('check_in','check_out_closed','check_out_rejected',"
            "'manual_verification','check_in_voided')",
            name="chk_events_event_type",
        ),
    )

    @property
    def actor_name(self) -> str:
        return self.actor.officer_name
