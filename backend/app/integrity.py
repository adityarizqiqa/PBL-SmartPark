"""Penerjemahan pelanggaran integritas database.

Setiap engine melaporkan pelanggaran unique dengan cara berbeda: SQLite
menyebut nama kolom, MySQL menyebut nama constraint. Helper di sini menerima
keduanya supaya pesan galat tetap tepat di kedua engine.
"""

from __future__ import annotations

from sqlalchemy.exc import IntegrityError


def matches(exc: IntegrityError, *needles: str) -> bool:
    """True bila pesan galat memuat salah satu penanda."""
    text = str(getattr(exc, "orig", exc))
    return any(needle in text for needle in needles)


def detail(exc: IntegrityError) -> str:
    """Pesan asli dari driver, untuk dicatat di log."""
    return str(getattr(exc, "orig", exc))
