"""Konfigurasi aplikasi.

Semua nilai dapat ditimpa lewat variabel lingkungan atau berkas `.env`.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "SmartPark API"
    app_env: str = "development"
    debug: bool = True

    # Alamat dengar server. Bawaannya hanya mesin ini sendiri; `.env` memakai
    # `0.0.0.0` supaya perangkat di jaringan yang sama bisa terhubung.
    host: str = "127.0.0.1"
    port: int = 8000

    database_url: str = "sqlite:///./smartpark.db"

    # Batas hari laporan dihitung memakai offset ini, bukan UTC.
    report_timezone: str = "Asia/Jakarta"
    report_utc_offset_hours: int = 7

    # Pencocokan plat.
    plate_similar_max_distance: int = 1
    plate_max_length: int = 12

    # NIM hanya divalidasi formatnya: angka, panjang bebas dalam rentang ini.
    nim_min_length: int = 1
    nim_max_length: int = 32

    # Autentikasi petugas.
    password_min_length: int = 6
    token_bytes: int = 32
    pin_max_attempts_per_minute: int = 5

    # Penyimpanan snapshot plat.
    upload_dir: Path = Path("./storage/plates")
    upload_max_bytes: int = 5 * 1024 * 1024

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
