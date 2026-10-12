"""Waktu: penyimpanan UTC, perhitungan batas hari dalam WIB."""

from __future__ import annotations

import datetime as dt

from app.config import settings

_UTC = dt.timezone.utc
_REPORT_TZ = dt.timezone(dt.timedelta(hours=settings.report_utc_offset_hours))


def utcnow() -> dt.datetime:
    """Waktu sekarang sebagai UTC tanpa informasi zona.

    Seluruh kolom waktu menyimpan UTC polos, jadi nilai ini bisa langsung
    disimpan dan dibandingkan tanpa konversi.
    """
    return dt.datetime.now(_UTC).replace(tzinfo=None)


def to_report_local(moment: dt.datetime) -> dt.datetime:
    """Mengubah waktu tersimpan (UTC polos) menjadi waktu lokal laporan."""
    return moment.replace(tzinfo=_UTC).astimezone(_REPORT_TZ)


def report_day_start_utc(moment: dt.datetime | None = None) -> dt.datetime:
    """Awal hari ini menurut zona laporan, dinyatakan kembali dalam UTC.

    Tanpa ini, "hari ini" akan mulai pukul 07:00 WIB karena UTC+7, sehingga
    angka beranda salah setiap pagi.
    """
    local = to_report_local(moment or utcnow())
    start_local = local.replace(hour=0, minute=0, second=0, microsecond=0)
    return start_local.astimezone(_UTC).replace(tzinfo=None)


def minutes_between(start: dt.datetime, end: dt.datetime | None = None) -> int:
    """Selisih menit, tidak pernah negatif."""
    end = end or utcnow()
    return max(0, int((end - start).total_seconds() // 60))
