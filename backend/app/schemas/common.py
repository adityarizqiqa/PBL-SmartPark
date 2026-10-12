"""Bentuk respons yang dipakai lintas endpoint."""

from __future__ import annotations

from pydantic import BaseModel, Field


class ErrorOut(BaseModel):
    """Bentuk seragam untuk seluruh respons kesalahan."""

    code: str = Field(examples=["duplicate_active_session"])
    message: str = Field(examples=["Plat ini sudah punya sesi aktif."])
    details: dict = Field(default_factory=dict)


class PageMeta(BaseModel):
    total: int
    limit: int
    offset: int
