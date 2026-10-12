"""Koneksi database, tipe kunci, PRAGMA, dan operator REGEXP.

Catatan penting soal SQLite:

* ``BIGINT PRIMARY KEY`` bukan alias rowid sehingga tidak auto-increment.
  Karena itu tipe kunci memakai ``BigInteger`` dengan varian ``Integer`` untuk
  SQLite — lihat :data:`PK`.
* ``PRAGMA foreign_keys`` mati secara bawaan dan harus dinyalakan per koneksi.
* Operator ``REGEXP`` tidak ada secara bawaan. Dipasang sebagai fungsi Python
  yang dipanggil SQLite saat mengevaluasi CHECK constraint. SQLite memanggilnya
  sebagai ``regexp(pola, nilai)`` — pola lebih dulu.
"""

from __future__ import annotations

import re
from collections.abc import Iterator

from sqlalchemy import BigInteger, Integer, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings

#: Tipe kunci yang benar untuk auto-increment di SQLite maupun MySQL.
PK = BigInteger().with_variant(Integer, "sqlite")
FK = BigInteger().with_variant(Integer, "sqlite")

_connect_args = {"check_same_thread": False} if settings.is_sqlite else {}

engine = create_engine(
    settings.database_url,
    echo=False,
    future=True,
    connect_args=_connect_args,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    """Kelas dasar seluruh model."""


def _regexp(pattern: str | None, value: str | None) -> bool:
    """Implementasi operator ``X REGEXP Y`` untuk SQLite.

    Pencocokan bersifat case-sensitive, sama seperti maksud penulisan pola pada
    skema. Pola yang tidak sah dianggap tidak cocok, bukan memunculkan galat.
    """
    if pattern is None or value is None:
        return False
    try:
        return re.search(pattern, value) is not None
    except re.error:
        return False


if settings.is_sqlite:

    @event.listens_for(engine, "connect")
    def _configure_sqlite(dbapi_connection, _record) -> None:  # pragma: no cover
        dbapi_connection.create_function("regexp", 2, _regexp, deterministic=True)
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys = ON")
        cursor.execute("PRAGMA journal_mode = WAL")
        cursor.execute("PRAGMA busy_timeout = 5000")
        cursor.close()


def get_db() -> Iterator[Session]:
    """Dependency FastAPI: satu sesi database per permintaan."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def create_all() -> None:
    """Membuat tabel yang belum ada beserta direktori penyimpanan berkas."""
    from app import models  # noqa: F401  (memicu registrasi metadata)

    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    Base.metadata.create_all(bind=engine)
