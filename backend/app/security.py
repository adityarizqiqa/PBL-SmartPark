"""Hashing password dan penerbitan token penugasan.

Dua kredensial, dua perlakuan:

* **Password** — rahasia buatan manusia berentropi rendah, jadi di-hash dengan
  algoritma lambat bersalt (bcrypt) agar percobaan offline mahal.
* **Token penugasan** — string acak berentropi tinggi, jadi cukup hash cepat
  (SHA-256). Hash cepat dibutuhkan karena token dicari pada setiap permintaan.
"""

from __future__ import annotations

import hashlib
import secrets
import threading
import time
from collections import defaultdict, deque

import bcrypt

from app.config import settings
from app.errors import RateLimitError, ValidationError


def hash_password(plain: str) -> str:
    """Menghasilkan hash bcrypt dari password."""
    if len(plain) < settings.password_min_length:
        raise ValidationError(
            f"Password minimal {settings.password_min_length} karakter."
        )
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("ascii")


def verify_password(plain: str, hashed: str | None) -> bool:
    """Memeriksa password terhadap hash-nya."""
    if not hashed:
        return False
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("ascii"))
    except ValueError:
        # Hash rusak atau formatnya tidak dikenal.
        return False


def generate_token() -> str:
    """Token acak yang dikirim ke klien sekali saja."""
    return secrets.token_hex(settings.token_bytes)


def hash_token(token: str) -> str:
    """Hash yang disimpan di database."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class AttemptLimiter:
    """Pembatas percobaan masuk per petugas, disimpan di memori proses.

    Cukup untuk satu proses. Bila nanti berjalan di beberapa worker, ganti
    penyimpanannya dengan cache bersama.
    """

    def __init__(self, max_attempts: int, window_seconds: int = 60) -> None:
        self._max = max_attempts
        self._window = window_seconds
        self._hits: dict[int, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: int) -> None:
        """Melempar :class:`RateLimitError` bila kuota sudah habis."""
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > self._window:
                hits.popleft()
            if len(hits) >= self._max:
                raise RateLimitError(
                    "Terlalu banyak percobaan masuk. Coba lagi sebentar lagi."
                )
            hits.append(now)

    def reset(self, key: int) -> None:
        with self._lock:
            self._hits.pop(key, None)


limiter = AttemptLimiter(settings.pin_max_attempts_per_minute)
