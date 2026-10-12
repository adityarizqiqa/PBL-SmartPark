"""Petugas parkir perorangan."""

from __future__ import annotations

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Index,
    String,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base
from app.models.mixins import TimestampMixin


#: Petugas lapangan — hanya boleh mengoperasikan sesi parkir.
ROLE_OFFICER = "officer"
#: Pengawas lapangan — boleh mengelola lahan dan mengatur shift jaga.
ROLE_SPV = "spv"
ROLES = (ROLE_OFFICER, ROLE_SPV)


class Officer(TimestampMixin, Base):
    __tablename__ = "officers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    employee_no: Mapped[str | None] = mapped_column(String(32), nullable=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    role: Mapped[str] = mapped_column(
        String(16),
        nullable=False,
        default=ROLE_OFFICER,
        server_default=text(f"'{ROLE_OFFICER}'"),
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default=text("1")
    )

    assignments: Mapped[list["ShiftOfficer"]] = relationship(  # noqa: F821
        back_populates="officer", lazy="noload"
    )

    __table_args__ = (
        UniqueConstraint("employee_no", name="uq_officers_employee_no"),
        Index("idx_officers_name", "name"),
        CheckConstraint(
            "role IN ('officer', 'spv')", name="chk_officers_role"
        ),
    )

    @property
    def has_password(self) -> bool:
        return bool(self.password_hash)

    @property
    def is_spv(self) -> bool:
        return self.role == ROLE_SPV
