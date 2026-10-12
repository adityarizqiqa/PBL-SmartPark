"""Penyimpanan berkas snapshot plat.

Berkas disimpan di luar direktori publik dan hanya diakses lewat endpoint
terautentikasi, sehingga path mentah tidak pernah bisa ditebak dari luar.
"""

from __future__ import annotations

import secrets
from pathlib import Path

from app.clock import to_report_local, utcnow
from app.config import settings
from app.errors import ValidationError

ALLOWED_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


class PhotoStorage:
    def __init__(self, root: Path | None = None) -> None:
        self.root = Path(root or settings.upload_dir)

    def save(self, data: bytes, *, suffix: str, area_code: str, kind: str) -> str:
        """Menyimpan berkas dan mengembalikan path relatifnya."""
        suffix = suffix.lower()
        if suffix not in ALLOWED_SUFFIXES:
            raise ValidationError(
                "Format berkas tidak didukung.", details={"suffix": suffix}
            )
        if not data:
            raise ValidationError("Berkas kosong.")
        if len(data) > settings.upload_max_bytes:
            raise ValidationError(
                "Ukuran berkas melebihi batas.",
                details={"max_bytes": settings.upload_max_bytes},
            )

        moment = to_report_local(utcnow())
        folder = self.root / f"{moment:%Y}" / f"{moment:%m}" / area_code
        folder.mkdir(parents=True, exist_ok=True)

        name = f"{kind}-{moment:%Y%m%d-%H%M%S}-{secrets.token_hex(4)}{suffix}"
        target = folder / name
        target.write_bytes(data)

        return str(target.relative_to(self.root)).replace("\\", "/")

    def resolve(self, relative_path: str) -> Path:
        """Mengubah path relatif menjadi path absolut, menolak keluar dari root."""
        candidate = (self.root / relative_path).resolve()
        root = self.root.resolve()
        if not str(candidate).startswith(str(root)):
            raise ValidationError("Path berkas tidak sah.")
        return candidate

    def exists(self, relative_path: str) -> bool:
        try:
            return self.resolve(relative_path).is_file()
        except ValidationError:
            return False


storage = PhotoStorage()
