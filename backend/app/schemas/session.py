"""Skema sesi parkir."""

from __future__ import annotations

import datetime as dt

from pydantic import BaseModel, ConfigDict, Field


class SessionOfficerOut(BaseModel):
    """Ringkasan petugas penanggung jawab sebuah sesi."""

    assignment_id: int
    officer_id: int
    officer_name: str


class ActiveSessionOut(BaseModel):
    """Baris daftar kendaraan yang masih parkir."""

    id: int
    nim: str
    plate_in: str
    checked_in_at: dt.datetime
    duration_minutes: int
    area_id: int
    area_name: str
    checked_in_by: str


class SessionDetailOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nim: str
    plate_in: str
    plate_out: str | None
    checked_in_at: dt.datetime
    checked_out_at: dt.datetime | None
    status: str
    match_method: str | None
    verification_note: str | None
    plate_in_photo_path: str | None
    plate_out_photo_path: str | None
    area_id: int
    area_name: str
    checked_in_by: SessionOfficerOut
    checked_out_by: SessionOfficerOut | None
    events: list["SessionEventOut"] = Field(default_factory=list)


class SessionEventOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    event_type: str
    note: str | None
    actor_name: str
    created_at: dt.datetime | None


class LookupCandidateOut(BaseModel):
    """Kandidat yang ditampilkan ke petugas saat pencarian tidak eksak.

    Sengaja hanya memuat plat dan waktu masuk. Angka kemiripan tidak dikirim —
    petugas membandingkan plat secara visual.
    """

    session_id: int
    plate_in: str
    checked_in_at: dt.datetime
    area_name: str


class LookupResultOut(BaseModel):
    """Hasil pencarian sesi aktif saat check-out."""

    match_method: str | None = Field(
        description="plate_exact, plate_similar, nim_fallback, atau null bila kosong."
    )
    session: SessionDetailOut | None = None
    candidates: list[LookupCandidateOut] = Field(default_factory=list)
    message: str | None = None


class CheckInForm(BaseModel):
    """Data check-in. Foto plat dikirim terpisah sebagai berkas unggahan.

    Panjang NIM tidak dipatok karena berbeda-beda antar institusi; yang
    diperiksa hanya isinya berupa angka.
    """

    nim: str = Field(min_length=1, max_length=32)
    plate: str = Field(min_length=1, max_length=32)
    client_request_id: str | None = Field(default=None, max_length=36)


class CheckOutForm(BaseModel):
    plate: str = Field(min_length=1, max_length=32)
    status: str = Field(
        default="matched",
        description="matched (Sesuai) atau manual_verified (Verifikasi Manual).",
    )
    note: str | None = None
    match_method: str | None = None


class RejectForm(BaseModel):
    """Penolakan check-out. Sesi tetap aktif; hanya dicatat sebagai event."""

    note: str = Field(min_length=1)


class VoidForm(BaseModel):
    """Pembatalan check-in. Wajib beralasan."""

    note: str = Field(min_length=1)


class DashboardOut(BaseModel):
    active_now: int
    checked_in_today: int
    checked_out_today: int
    recent: list[SessionDetailOut] = Field(default_factory=list)


class HistoryItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    nim: str
    plate_in: str
    plate_out: str | None
    checked_in_at: dt.datetime
    checked_out_at: dt.datetime | None
    status: str
    verification_note: str | None


SessionDetailOut.model_rebuild()
