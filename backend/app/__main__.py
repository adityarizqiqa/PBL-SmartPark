"""Titik masuk `python -m app`.

Alamat dengar server dibaca dari `HOST`/`PORT` di `.env` (lewat
`app.config`), jadi tidak perlu ditulis ulang sebagai argumen tiap kali
dijalankan — dan nilainya tidak ikut masuk ke repositori.
"""

from __future__ import annotations

import uvicorn

from app.config import settings


def main() -> None:
    uvicorn.run(
        "app.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )


if __name__ == "__main__":
    main()
