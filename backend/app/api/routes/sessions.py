"""Endpoint sesi parkir.

Alur utama: check-in, pencarian sesi saat check-out, penutupan, penolakan, dan
pembatalan. Foto plat diterima sebagai berkas unggahan pada check-in dan
check-out, dan disimpan di luar direktori publik.
"""

from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, File, Form, Query, UploadFile, status

from app.api.deps import CurrentAssignment, DbSession, SessionSvc
from app.api.serializers import active_session, candidate, event
from app.errors import SessionNotFound, ValidationError
from app.schemas.common import PageMeta
from app.schemas.session import (
    ActiveSessionOut,
    CheckInForm,
    CheckOutForm,
    DashboardOut,
    HistoryItemOut,
    LookupResultOut,
    RejectForm,
    SessionDetailOut,
    VoidForm,
)
from app.services.storage import storage

router = APIRouter(prefix="/sessions", tags=["sesi"])

PhotoFile = Annotated[UploadFile | None, File(description="Snapshot plat")]


def _detail(row) -> SessionDetailOut:
    return SessionDetailOut(
        id=row.id,
        nim=row.nim,
        plate_in=row.plate_in,
        plate_out=row.plate_out,
        checked_in_at=row.checked_in_at,
        checked_out_at=row.checked_out_at,
        status=row.status,
        match_method=row.match_method,
        verification_note=row.verification_note,
        plate_in_photo_path=row.plate_in_photo_path,
        plate_out_photo_path=row.plate_out_photo_path,
        area_id=row.parking_area_id,
        area_name=row.area_name,
        checked_in_by=row.checked_in_by,
        checked_out_by=row.checked_out_by,
        events=[event(e) for e in row.events] if row.events else [],
    )


async def _save_photo(
    photo: UploadFile | None, area_code: str, kind: str
) -> str | None:
    if photo is None or not photo.filename:
        return None
    data = await photo.read()
    suffix = "." + photo.filename.rsplit(".", 1)[-1] if "." in photo.filename else ""
    return storage.save(data, suffix=suffix, area_code=area_code, kind=kind)


# --- ringkasan ---------------------------------------------------------------


@router.get("/dashboard", response_model=DashboardOut)
def dashboard(sessions: SessionSvc, assignment: CurrentAssignment) -> DashboardOut:
    """Ringkasan beranda: jumlah sesi dan aktivitas terbaru.

    Batas hari dihitung dalam zona laporan, bukan UTC.
    """
    data = sessions.dashboard()
    return DashboardOut(
        active_now=data["active_now"],
        checked_in_today=data["checked_in_today"],
        checked_out_today=data["checked_out_today"],
        recent=[_detail(row) for row in data["recent"]],
    )


@router.get("/active", response_model=list[ActiveSessionOut])
def list_active(
    sessions: SessionSvc, assignment: CurrentAssignment
) -> list[ActiveSessionOut]:
    """Kendaraan yang masih parkir, terlama lebih dulu.

    Durasi berjalan dihitung saat dibaca, tidak disimpan.
    """
    return [
        active_session(row, sessions.duration_minutes(row))
        for row in sessions.list_active()
    ]


@router.get("/history", response_model=list[HistoryItemOut])
def history(
    sessions: SessionSvc,
    assignment: CurrentAssignment,
    q: Annotated[str | None, Query(description="Cari NIM atau plat")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[HistoryItemOut]:
    """Riwayat sesi yang benar-benar ditutup."""
    rows, _ = sessions.history(q, limit, offset)
    return [HistoryItemOut.model_validate(row) for row in rows]


@router.get("/history/meta", response_model=PageMeta)
def history_meta(
    sessions: SessionSvc,
    assignment: CurrentAssignment,
    q: str | None = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> PageMeta:
    _, total = sessions.history(q, limit, offset)
    return PageMeta(total=total, limit=limit, offset=offset)


# --- pencarian saat check-out ------------------------------------------------


@router.get("/lookup", response_model=LookupResultOut)
def lookup(
    sessions: SessionSvc,
    assignment: CurrentAssignment,
    plate: Annotated[str, Query(description="Hasil scan plat di gerbang keluar")],
    nim: Annotated[str | None, Query(description="Dipakai bila plat tidak ketemu")] = None,
) -> LookupResultOut:
    """Mencari sesi aktif berlapis: plat persis, plat mirip, lalu NIM.

    Plat hasil scan dikirim apa adanya tanpa dikonfirmasi petugas lebih dulu,
    sehingga langkah kemiripan benar-benar terpakai saat OCR salah baca.
    """
    match_method, found, candidates, message = sessions.lookup(plate, nim)

    if found is not None:
        return LookupResultOut(
            match_method=match_method,
            session=_detail(found),
        )
    if candidates:
        return LookupResultOut(
            match_method=match_method,
            candidates=[candidate(row) for row in candidates],
        )
    return LookupResultOut(match_method=None, message=message)


# --- check-in ----------------------------------------------------------------


@router.post(
    "/check-in", response_model=SessionDetailOut, status_code=status.HTTP_201_CREATED
)
async def check_in(
    sessions: SessionSvc,
    assignment: CurrentAssignment,
    nim: Annotated[str, Form()],
    plate: Annotated[str, Form()],
    client_request_id: Annotated[str | None, Form()] = None,
    photo: PhotoFile = None,
) -> SessionDetailOut:
    """Membuat sesi parkir aktif.

    Bila NIM atau plat sudah punya sesi aktif, permintaan ditolak dan tidak ada
    data yang dibuat.
    """
    area_code = assignment.shift.area.code
    photo_path = await _save_photo(photo, area_code, "in")

    row = sessions.check_in(
        assignment,
        CheckInForm(nim=nim, plate=plate, client_request_id=client_request_id),
        photo_path=photo_path,
    )
    return _detail(sessions.get(row.id))


# --- penutupan ---------------------------------------------------------------


@router.post("/{session_id}/check-out", response_model=SessionDetailOut)
async def check_out(
    session_id: int,
    sessions: SessionSvc,
    assignment: CurrentAssignment,
    plate: Annotated[str, Form()],
    checkout_status: Annotated[str, Form(alias="status")] = "matched",
    note: Annotated[str | None, Form()] = None,
    match_method: Annotated[str | None, Form()] = None,
    photo: PhotoFile = None,
) -> SessionDetailOut:
    """Menutup sesi sebagai Sesuai atau Verifikasi Manual.

    Verifikasi manual wajib disertai catatan.
    """
    area_code = assignment.shift.area.code
    photo_path = await _save_photo(photo, area_code, "out")

    sessions.close(
        session_id,
        assignment,
        CheckOutForm(
            plate=plate,
            status=checkout_status,
            note=note,
            match_method=match_method,
        ),
        photo_path=photo_path,
    )
    return _detail(sessions.get(session_id))


@router.post("/{session_id}/reject", response_model=SessionDetailOut)
def reject(
    session_id: int,
    payload: RejectForm,
    sessions: SessionSvc,
    assignment: CurrentAssignment,
) -> SessionDetailOut:
    """Menolak check-out. Sesi tetap aktif; penolakan hanya dicatat."""
    sessions.reject(session_id, assignment, payload.note)
    return _detail(sessions.get(session_id))


@router.post("/{session_id}/void", response_model=SessionDetailOut)
def void(
    session_id: int,
    payload: VoidForm,
    sessions: SessionSvc,
    assignment: CurrentAssignment,
) -> SessionDetailOut:
    """Membatalkan check-in yang salah.

    NIM dan plat langsung bebas dipakai lagi karena keduanya hanya terkunci
    selama sesi berstatus aktif. Baris tidak dihapus.
    """
    sessions.void(session_id, assignment, payload.note)
    return _detail(sessions.get(session_id))


# --- detail ------------------------------------------------------------------


@router.get("/{session_id}", response_model=SessionDetailOut)
def get_session(
    session_id: int, sessions: SessionSvc, assignment: CurrentAssignment
) -> SessionDetailOut:
    return _detail(sessions.get(session_id))


@router.get("/{session_id}/photo/{side}")
def get_photo(
    session_id: int,
    side: str,
    sessions: SessionSvc,
    assignment: CurrentAssignment,
):
    """Menyajikan snapshot plat. Hanya untuk petugas yang sedang bertugas."""
    from fastapi.responses import FileResponse

    if side not in {"in", "out"}:
        raise ValidationError("Sisi foto harus 'in' atau 'out'.")

    row = sessions.get(session_id)
    relative = row.plate_in_photo_path if side == "in" else row.plate_out_photo_path
    if not relative or not storage.exists(relative):
        raise SessionNotFound("Snapshot plat tidak tersedia.")

    return FileResponse(storage.resolve(relative))
