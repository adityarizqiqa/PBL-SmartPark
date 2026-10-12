"""Normalisasi plat dan pengukuran kemiripan.

Normalisasi dilakukan sebelum menyimpan maupun mencari, sehingga bentuk yang
tersimpan selalu konsisten. Pencocokan kemiripan dipakai saat check-out untuk
menyaring kandidat ketika pencarian persis gagal.
"""

from __future__ import annotations

import re

from app.config import settings
from app.errors import InvalidNim, InvalidPlate

_NON_ALNUM = re.compile(r"[^A-Z0-9]")
_PLATE_RE = re.compile(r"^[A-Z0-9]{1,12}$")
_NIM_RE = re.compile(r"^[0-9]+$")


def normalize_plate(raw: str) -> str:
    """Ubah hasil OCR menjadi bentuk kanonik.

    ``"  b 1234  xyz "`` → ``"B1234XYZ"``

    Huruf dijadikan kapital, semua karakter selain ``A-Z`` dan ``0-9`` dibuang,
    lalu dipotong sesuai batas panjang.
    """
    return _NON_ALNUM.sub("", raw.upper())[: settings.plate_max_length]


def is_valid_plate(plate: str) -> bool:
    """Plat yang sudah dinormalisasi harus alfanumerik dan tidak kosong."""
    return bool(_PLATE_RE.fullmatch(plate))


def require_valid_plate(raw: str) -> str:
    """Normalisasi sekaligus menolak plat yang tidak masuk akal."""
    plate = normalize_plate(raw)
    if not is_valid_plate(plate):
        raise InvalidPlate(
            "Plat nomor tidak valid setelah dinormalisasi.", details={"plate": plate}
        )
    return plate


def validate_nim(raw: str) -> str:
    """NIM hanya divalidasi formatnya, bukan keaslian atau keaktifan.

    Panjangnya tidak dipatok karena berbeda-beda antar institusi. Yang dijaga:
    isinya hanya angka, dan panjangnya berada dalam rentang yang bisa
    ditampung kolom database.
    """
    nim = raw.strip()
    if not nim:
        raise InvalidNim("NIM tidak boleh kosong.")
    if not _NIM_RE.fullmatch(nim):
        raise InvalidNim("NIM hanya boleh berisi angka.")
    if not (settings.nim_min_length <= len(nim) <= settings.nim_max_length):
        raise InvalidNim(
            f"Panjang NIM harus antara {settings.nim_min_length} dan "
            f"{settings.nim_max_length} angka.",
            details={"length": len(nim)},
        )
    return nim


def levenshtein(a: str, b: str) -> int:
    """Jarak edit antara dua teks.

    Diimplementasi dengan dua baris memori agar tidak membengkak pada input
    panjang. Ada pemangkasan cepat untuk kasus batas.
    """
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)

    if len(a) > len(b):
        a, b = b, a

    previous = list(range(len(a) + 1))
    for i, char_b in enumerate(b, start=1):
        current = [i]
        for j, char_a in enumerate(a, start=1):
            cost = 0 if char_a == char_b else 1
            current.append(
                min(
                    previous[j] + 1,        # hapus
                    current[j - 1] + 1,     # sisip
                    previous[j - 1] + cost,  # ganti
                )
            )
        previous = current
    return previous[-1]
