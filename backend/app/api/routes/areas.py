"""Endpoint lahan parkir.

Dibuatkan endpoint tulis sederhana karena data lahan perlu diisi admin sebelum
sistem bisa dipakai.
"""

from __future__ import annotations

from fastapi import APIRouter, status
from sqlalchemy import select

from app.api.deps import CurrentSpv, DbSession
from app.errors import AreaNotFound, ConflictError
from app.integrity import matches
from app.models import ParkingArea
from app.schemas.area import AreaCreate, AreaOut, AreaUpdate

router = APIRouter(prefix="/areas", tags=["lahan"])


@router.get("", response_model=list[AreaOut])
def list_areas(db: DbSession, include_inactive: bool = False) -> list[ParkingArea]:
    stmt = select(ParkingArea).order_by(ParkingArea.code)
    if not include_inactive:
        stmt = stmt.where(ParkingArea.is_active.is_(True))
    return list(db.scalars(stmt).all())


@router.post("", response_model=AreaOut, status_code=status.HTTP_201_CREATED)
def create_area(
    payload: AreaCreate, db: DbSession, _spv: CurrentSpv
) -> ParkingArea:
    area = ParkingArea(code=payload.code.strip().upper(), name=payload.name.strip())
    db.add(area)
    try:
        db.commit()
    except Exception as exc:  # noqa: BLE001 - diterjemahkan ke pesan yang jelas
        db.rollback()
        if matches(exc, "uq_parking_areas_code", "parking_areas.code"):
            raise ConflictError("Kode lahan ini sudah dipakai.") from exc
        raise
    db.refresh(area)
    return area


@router.patch("/{area_id}", response_model=AreaOut)
def update_area(
    area_id: int, payload: AreaUpdate, db: DbSession, _spv: CurrentSpv
) -> ParkingArea:
    area = db.get(ParkingArea, area_id)
    if area is None:
        raise AreaNotFound("Lahan parkir tidak ditemukan.")

    if payload.name is not None:
        area.name = payload.name.strip()
    if payload.is_active is not None:
        area.is_active = payload.is_active

    db.commit()
    db.refresh(area)
    return area
