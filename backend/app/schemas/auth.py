"""Skema masuk/keluar petugas di luar shift."""

from __future__ import annotations

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field


class SignInForm(BaseModel):
    """Petugas memilih namanya dari daftar lalu memasukkan password."""

    officer_id: int
    password: str


class SessionOut(BaseModel):
    """Sesi masuk petugas. ``token_hash`` tidak pernah keluar dari server."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    officer_id: int
    officer_name: str
    role: str
    signed_in_at: dt.datetime
    revoked_at: dt.datetime | None
    is_active: bool


class SignInOut(BaseModel):
    """Token dikirim sekali di sini; server hanya menyimpan hash-nya."""

    token: str
    session: SessionOut
