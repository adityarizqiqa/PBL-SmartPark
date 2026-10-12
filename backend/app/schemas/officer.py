"""Skema petugas."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.models.officer import ROLE_OFFICER


class OfficerOut(BaseModel):
    """Data petugas untuk daftar pilih-nama dan laporan.

    ``password_hash`` tidak pernah ikut keluar dari server.
    """

    model_config = ConfigDict(from_attributes=True)

    id: int
    employee_no: str | None
    name: str
    phone: str | None
    role: str
    is_active: bool
    has_password: bool = Field(
        description="True bila admin sudah mengatur password petugas ini."
    )


class OfficerCreate(BaseModel):
    employee_no: str | None = Field(default=None, max_length=32)
    name: str = Field(min_length=1, max_length=100)
    phone: str | None = Field(default=None, max_length=20)
    role: str = Field(default=ROLE_OFFICER, pattern="^(officer|spv)$")
    password: str = Field(min_length=6)


class OfficerUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    phone: str | None = Field(default=None, max_length=20)
    role: str | None = Field(default=None, pattern="^(officer|spv)$")
    is_active: bool | None = None
    password: str | None = Field(default=None, min_length=6)
