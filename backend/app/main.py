"""Perakitan aplikasi FastAPI."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import ValidationError as PydanticValidationError

from app import __version__
from app.api.routes import areas, auth, officers, sessions, shifts
from app.config import settings
from app.database import create_all
from app.errors import AppError
from app.migrations import apply_migrations


@asynccontextmanager
async def lifespan(_app: FastAPI):
    """Menyiapkan tabel, kolom baru, dan direktori penyimpanan."""
    create_all()
    apply_migrations()
    yield


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=__version__,
        description=(
            "Backend verifikasi check-in/check-out parkir motor mahasiswa.\n\n"
            "Seluruh waktu disimpan UTC. Batas hari untuk laporan dihitung "
            f"dalam {settings.report_timezone}.\n\n"
            "Dua kredensial, dua lingkup:\n"
            "- `X-Shift-Token` dari `POST /api/shifts/join` — operasi sesi "
            "parkir (check-in, check-out, penolakan, pembatalan).\n"
            "- `X-Officer-Token` dari `POST /api/auth/sign-in` — operasi "
            "pengelolaan di luar shift (lahan, shift jaga). Hanya peran "
            "`spv` yang diizinkan menulis."
        ),
        lifespan=lifespan,
        debug=settings.debug,
    )

    @app.exception_handler(AppError)
    async def _app_error(_request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={
                "code": exc.code,
                "message": exc.message,
                "details": exc.details,
            },
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_error(
        _request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content={
                "code": "validation_error",
                "message": "Data permintaan tidak valid.",
                "details": {"errors": exc.errors()},
            },
        )

    @app.exception_handler(PydanticValidationError)
    async def _schema_error(
        _request: Request, exc: PydanticValidationError
    ) -> JSONResponse:
        """Menangkap skema yang dibangun manual di dalam route.

        Sebagian route menyusun model permintaan sendiri dari data formulir,
        sehingga validasinya tidak lewat jalur FastAPI. Tanpa penangkap ini,
        pelanggaran seperti NIM terlalu panjang akan muncul sebagai galat 500.
        """
        return JSONResponse(
            status_code=422,
            content={
                "code": "validation_error",
                "message": "Data permintaan tidak valid.",
                "details": {"errors": exc.errors(include_url=False)},
            },
        )

    @app.get("/health", tags=["sistem"])
    def health() -> dict:
        return {"status": "ok", "version": __version__}

    app.include_router(auth.router, prefix="/api")
    app.include_router(areas.router, prefix="/api")
    app.include_router(officers.router, prefix="/api")
    app.include_router(shifts.router, prefix="/api")
    app.include_router(sessions.router, prefix="/api")

    return app


app = create_app()
