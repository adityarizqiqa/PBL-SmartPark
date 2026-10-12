"""Penyesuaian skema untuk database yang sudah berisi data.

``Base.metadata.create_all`` hanya membuat tabel yang belum ada; ia tidak
menambah kolom maupun constraint pada tabel yang sudah terisi. Karena database
pengembangan sudah berjalan, perubahan skema diterapkan di sini secara
eksplisit dan idempoten.

**Kenapa membangun ulang tabel.** SQLite tidak mendukung
``ALTER TABLE ... ADD CONSTRAINT``. Satu-satunya cara menambahkan ``CHECK``
adalah prosedur bangun-ulang: matikan foreign key, buat tabel baru, salin
seluruh baris, ganti tabel lama, lalu buat ulang indeksnya — semuanya dalam
satu transaksi. DDL tabel tujuan **dihasilkan dari metadata model**, bukan
ditulis tangan, supaya tidak bisa menyimpang dari model.

MySQL dan sejenisnya mendukung penambahan ``CHECK`` langsung, jadi cukup
``ALTER TABLE``.
"""

from __future__ import annotations

from sqlalchemy import inspect, text
from sqlalchemy.schema import CreateIndex, CreateTable

from app import models  # noqa: F401  (mengisi Base.metadata)
from app.database import Base, engine
from app.models.officer import ROLE_OFFICER

#: Kolom yang ditambahkan setelah rilis pertama.
_ADDED_COLUMNS = {
    "officers": {
        "role": f"VARCHAR(16) NOT NULL DEFAULT '{ROLE_OFFICER}'",
    },
}

#: Constraint yang ditambahkan setelah rilis pertama, per tabel.
_ADDED_CHECKS = {
    "officers": ("chk_officers_role",),
    "parking_sessions": ("chk_sessions_match_method",),
    "session_events": ("chk_events_event_type",),
}

#: Kolom yang dibuang setelah rilis pertama, per tabel.
#:
#: ``shifts.device_code`` dan ``device_label`` mencatat perangkat pos, dengan
#: premis satu perangkat dipakai bergantian dan karenanya hanya melayani satu
#: shift terbuka. Premis itu tidak lagi berlaku: setiap petugas memakai
#: perangkatnya sendiri, sehingga satu shift bisa punya beberapa perangkat dan
#: satu kolom tidak bisa memuatnya. Aturan ``device_busy`` ikut dibuang.
_DROPPED_COLUMNS = {
    "shifts": ("device_code", "device_label"),
}


def apply_migrations() -> list[str]:
    """Menyelaraskan tabel yang sudah ada dengan model.

    Menambahkan kolom dan constraint yang belum ada, serta membuang kolom yang
    sudah tidak ada di model. Mengembalikan daftar perubahan yang benar-benar
    dijalankan, sehingga pemanggil bisa mencatatnya dan pemanggilan ulang tidak
    melakukan apa-apa.
    """
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())
    applied: list[str] = []

    with engine.begin() as conn:
        for table, columns in _ADDED_COLUMNS.items():
            if table not in existing_tables:
                continue
            present = {col["name"] for col in inspector.get_columns(table)}
            for column, ddl in columns.items():
                if column in present:
                    continue
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {ddl}"))
                applied.append(f"{table}.{column}")

        # Baris lama yang sempat bernilai NULL (mis. ditambah tanpa DEFAULT).
        if "officers" in existing_tables and "role" in {
            col["name"] for col in inspector.get_columns("officers")
        }:
            conn.execute(
                text(
                    "UPDATE officers SET role = :officer "
                    "WHERE role IS NULL OR role = ''"
                ),
                {"officer": ROLE_OFFICER},
            )

    applied.extend(_sync_tables(existing_tables))
    return applied


def _sync_tables(existing_tables: set[str]) -> list[str]:
    """Menyelaraskan constraint dan kolom pada tabel yang sudah ada.

    Satu tabel dibangun ulang paling banyak sekali, karena
    :func:`_rebuild_table` menghasilkan DDL dari metadata model — sekaligus
    memasang ``CHECK`` yang belum ada dan membuang kolom yang sudah tidak ada.
    """
    applied: list[str] = []

    for table in sorted(set(_ADDED_CHECKS) | set(_DROPPED_COLUMNS)):
        if table not in existing_tables:
            continue

        names = _ADDED_CHECKS.get(table, ())
        current = _table_ddl(table) if names else ""
        missing = [name for name in names if name not in current]

        dropped = [
            column
            for column in _DROPPED_COLUMNS.get(table, ())
            if column in {col["name"] for col in inspect(engine).get_columns(table)}
        ]

        if not missing and not dropped:
            continue

        if engine.dialect.name == "sqlite":
            _rebuild_table(table)
        else:
            if missing:
                _add_checks_alter(table, missing)
            if dropped:
                _drop_columns_alter(table, dropped)

        applied.extend(f"{table}.{name}" for name in missing)
        applied.extend(f"{table}.{column} (dibuang)" for column in dropped)

    return applied


def _drop_columns_alter(table: str, columns: list[str]) -> None:
    """Membuang kolom lewat ``ALTER TABLE`` (MySQL dan sejenisnya)."""
    with engine.begin() as conn:
        for column in columns:
            conn.execute(text(f"ALTER TABLE {table} DROP COLUMN {column}"))


def _add_checks_alter(table: str, names: list[str]) -> None:
    """Menambah constraint lewat ``ALTER TABLE`` (MySQL dan sejenisnya)."""
    model = Base.metadata.tables[table]
    wanted = {c.name: c for c in model.constraints if c.name in names}

    for name in names:
        constraint = wanted.get(name)
        if constraint is None:
            continue
        expression = str(constraint.sqltext)
        with engine.begin() as conn:
            conn.execute(
                text(
                    f"ALTER TABLE {table} "
                    f"ADD CONSTRAINT {name} CHECK ({expression})"
                )
            )


def _table_ddl(table: str) -> str:
    """SQL asli pembuatan tabel, untuk memeriksa constraint yang sudah ada."""
    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT sql FROM sqlite_master WHERE type='table' AND name=:t"),
            {"t": table},
        ).first()
    return row[0] if row and row[0] else ""


def _rebuild_table(table: str) -> None:
    """Membangun ulang satu tabel beserta seluruh indeksnya.

    DDL tujuan diambil dari metadata model sehingga hasilnya identik dengan
    tabel yang dibuat dari nol — termasuk seluruh ``CHECK`` dan ``UNIQUE``.
    """
    model = Base.metadata.tables[table]
    temporary = f"{table}_rebuild"
    # Kolom GENERATED STORED tidak boleh ditulis; nilainya dihitung engine.
    columns = ", ".join(
        column.name for column in model.columns if column.computed is None
    )

    ddl = str(CreateTable(model).compile(engine)).strip()
    prefix = f"CREATE TABLE {table}"
    if not ddl.startswith(prefix):  # pragma: no cover - jaga-jaga
        raise RuntimeError(f"DDL tak terduga untuk {table}: {ddl[:60]}")
    ddl = f"CREATE TABLE {temporary}" + ddl[len(prefix):]

    raw = engine.raw_connection()
    try:
        cursor = raw.cursor()
        cursor.execute("PRAGMA foreign_keys = OFF")
        cursor.execute("BEGIN")
        cursor.execute(f"DROP TABLE IF EXISTS {temporary}")
        cursor.execute(ddl)
        cursor.execute(
            f"INSERT INTO {temporary} ({columns}) SELECT {columns} FROM {table}"
        )
        cursor.execute(f"DROP TABLE {table}")
        cursor.execute(f"ALTER TABLE {temporary} RENAME TO {table}")
        for index in model.indexes:
            cursor.execute(str(CreateIndex(index).compile(engine)))
        cursor.execute("COMMIT")
        cursor.execute("PRAGMA foreign_keys = ON")
    except Exception:
        try:
            raw.rollback()
        finally:
            cursor.execute("PRAGMA foreign_keys = ON")
        raise
    finally:
        raw.close()


def ensure_spv_exists() -> bool:
    """True bila sudah ada minimal satu pengawas.

    Tanpa pengawas, tidak ada yang bisa menambah lahan atau mengatur shift.
    """
    inspector = inspect(engine)
    if "officers" not in set(inspector.get_table_names()):
        return False

    with engine.begin() as conn:
        found = conn.execute(
            text("SELECT id FROM officers WHERE role = 'spv' LIMIT 1")
        ).first()
    return found is not None
