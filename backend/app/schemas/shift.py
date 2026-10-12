"""Skema shift dan penugasan petugas."""

from __future__ import annotations

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field


class AssignmentOut(BaseModel):
    """Penugasan petugas dalam satu shift — identitas yang dipakai sesi."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    shift_id: int
    officer_id: int
    officer_name: str
    joined_at: dt.datetime
    left_at: dt.datetime | None
    left_note: str | None = None


class ShiftOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    parking_area_id: int
    area_name: str
    started_at: dt.datetime
    ended_at: dt.datetime | None
    end_note: str | None = None
    is_open: bool
    assignments: list[AssignmentOut] = Field(default_factory=list)


class ShiftJoinForm(BaseModel):
    """Petugas masuk: pilih nama, masukkan password, sebutkan lahannya."""

    officer_id: int
    password: str
    parking_area_id: int


class ShiftLoginOut(BaseModel):
    """Token dikirim sekali di sini; server hanya menyimpan hash-nya."""

    token: str
    assignment: AssignmentOut
    shift: ShiftOut


class ShiftCloseForm(BaseModel):
    note: str | None = None


class ShiftOpenForm(BaseModel):
    """Pengawas membuka shift jaga di satu lahan.

    Petugas yang datang berikutnya bergabung ke shift ini, bukan membuka
    shift kedua (``uq_shifts_active_area``).
    """

    parking_area_id: int
    note: str | None = None


class AssignmentLeaveForm(BaseModel):
    note: str | None = None
