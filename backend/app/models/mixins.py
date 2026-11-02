"""Potongan kolom yang dipakai bersama seluruh tabel."""

from __future__ import annotations

import datetime as dt

from sqlalchemy import DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.clock import utcnow


class TimestampMixin:
    """Kolom jejak waktu standar."""

    created_at: Mapped[dt.datetime] = mapped_column(
        DateTime, nullable=False, default=utcnow, server_default=func.now()
    )
    updated_at: Mapped[dt.datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utcnow,
        onupdate=utcnow,
        server_default=func.now(),
    )
