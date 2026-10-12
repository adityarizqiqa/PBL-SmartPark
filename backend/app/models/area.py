"""Lahan/pos parkir."""

from __future__ import annotations

from sqlalchemy import Boolean, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


class ParkingArea(TimestampMixin, Base):
    __tablename__ = "parking_areas"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    code: Mapped[str] = mapped_column(String(32), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("1")
    )

    shifts: Mapped[list["Shift"]] = relationship(  # noqa: F821
        back_populates="area", lazy="noload"
    )
    sessions: Mapped[list["ParkingSession"]] = relationship(  # noqa: F821
        back_populates="area", lazy="noload"
    )

    __table_args__ = (UniqueConstraint("code", name="uq_parking_areas_code"),)
