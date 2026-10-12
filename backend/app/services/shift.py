"""Siklus jaga: masuk, berhenti bertugas, dan menutup shift.

Satu lahan hanya punya satu shift terbuka. Petugas yang datang berikutnya
bergabung ke shift itu dan mendapat token sendiri, sehingga penanggung jawab
tiap sesi tetap bisa dibedakan meski shiftnya sama.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.clock import utcnow
from app.errors import (
    AreaInactive,
    AreaNotFound,
    ConflictError,
    DuplicateActiveAssignment,
    InactiveOfficer,
    InvalidCredentials,
    OfficerNotFound,
    PasswordNotSet,
)
from app.integrity import matches
from app.models import Officer, ParkingArea, Shift, ShiftOfficer
from app.schemas.shift import ShiftJoinForm
from app.security import (
    generate_token,
    hash_token,
    limiter,
    verify_password,
)


class ShiftService:
    """Operasi yang membentuk dan menutup periode jaga."""

    def __init__(self, db: Session) -> None:
        self.db = db

    # --- masuk ---------------------------------------------------------------

    def join(self, form: ShiftJoinForm) -> tuple[str, ShiftOfficer]:
        """Petugas masuk dan mulai bertugas.

        Mengembalikan token mentah (hanya sekali ini) beserta penugasannya.
        """
        limiter.check(form.officer_id)

        officer = self.db.get(Officer, form.officer_id)
        if officer is None:
            raise OfficerNotFound("Petugas tidak ditemukan.")
        if not officer.is_active:
            raise InactiveOfficer("Petugas ini sudah tidak aktif.")
        if not officer.password_hash:
            raise PasswordNotSet(
                "Password petugas ini belum diatur admin."
            )
        if not verify_password(form.password, officer.password_hash):
            raise InvalidCredentials("Password salah.")

        limiter.reset(form.officer_id)

        area = self.db.get(ParkingArea, form.parking_area_id)
        if area is None:
            raise AreaNotFound("Lahan parkir tidak ditemukan.")
        if not area.is_active:
            raise AreaInactive("Lahan parkir ini sedang tidak aktif.")

        open_assignment = self.db.scalar(
            select(ShiftOfficer).where(
                ShiftOfficer.officer_id == officer.id,
                ShiftOfficer.left_at.is_(None),
            )
        )
        if open_assignment is not None:
            raise DuplicateActiveAssignment(
                "Petugas ini masih bertugas di shift lain.",
                details={"assignment_id": open_assignment.id},
            )

        shift = self._open_shift_for_area(area.id)
        if shift is None:
            shift = Shift(
                parking_area_id=area.id,
                started_at=utcnow(),
            )
            self.db.add(shift)
            self._flush()

        token = generate_token()
        assignment = ShiftOfficer(
            shift_id=shift.id,
            officer_id=officer.id,
            token_hash=hash_token(token),
            joined_at=utcnow(),
        )
        self.db.add(assignment)
        self._flush()

        self.db.commit()
        self.db.refresh(assignment)
        # Koleksi penugasan pada shift di-cache sebelum baris ini dibuat, jadi
        # perlu dikedaluwarsakan agar isinya ikut terbaru saat dibaca klien.
        self.db.expire(shift, ["assignments"])
        return token, assignment

    # --- buka shift oleh pengawas -------------------------------------------

    def open_shift(self, area: ParkingArea) -> Shift:
        """Pengawas membuka shift jaga di satu lahan.

        Berbeda dari :meth:`join` yang membuat shift secara implisit saat
        petugas pertama datang, di sini shift dibuka lebih dulu supaya pengawas
        bisa menyiapkan periode jaga sebelum ada petugas.
        """
        if not area.is_active:
            raise AreaInactive("Lahan parkir ini sedang tidak aktif.")
        if self._open_shift_for_area(area.id) is not None:
            raise ConflictError("Lahan ini sudah punya shift terbuka.")

        shift = Shift(
            parking_area_id=area.id,
            started_at=utcnow(),
        )
        self.db.add(shift)
        self._flush()
        self.db.commit()
        self.db.refresh(shift)
        return shift

    # --- berhenti bertugas ---------------------------------------------------

    def leave(
        self, assignment: ShiftOfficer, note: str | None = None
    ) -> ShiftOfficer:
        """Petugas berhenti bertugas; tokennya langsung mati."""
        if assignment.left_at is not None:
            raise ConflictError("Petugas ini sudah berhenti bertugas.")

        assignment.left_at = utcnow()
        assignment.left_note = note
        assignment.token_hash = None

        # Shift ikut ditutup bila tidak ada lagi petugas yang bertugas.
        remaining = self.db.scalar(
            select(ShiftOfficer.id).where(
                ShiftOfficer.shift_id == assignment.shift_id,
                ShiftOfficer.left_at.is_(None),
                ShiftOfficer.id != assignment.id,
            )
        )
        if remaining is None:
            shift = assignment.shift
            if shift.ended_at is None:
                shift.ended_at = utcnow()
                shift.end_note = note

        self.db.commit()
        self.db.refresh(assignment)
        return assignment

    # --- tutup paksa ---------------------------------------------------------

    def close_shift(self, shift: Shift, note: str | None = None) -> Shift:
        """Menutup shift beserta seluruh penugasan yang masih terbuka.

        Dipakai saat shift lupa ditutup. Baris tidak dihapus, hanya diberi
        waktu selesai.
        """
        if shift.ended_at is not None:
            raise ConflictError("Shift ini sudah ditutup.")

        moment = utcnow()
        shift.ended_at = moment
        shift.end_note = note

        for assignment in shift.assignments:
            if assignment.left_at is None:
                assignment.left_at = moment
                assignment.left_note = note
                assignment.token_hash = None

        self.db.commit()
        self.db.refresh(shift)
        return shift

    # --- pencarian -----------------------------------------------------------

    def _open_shift_for_area(self, area_id: int) -> Shift | None:
        return self.db.scalar(
            select(Shift).where(
                Shift.parking_area_id == area_id,
                Shift.ended_at.is_(None),
            )
        )

    def resolve_token(self, token: str) -> ShiftOfficer | None:
        """Mencari penugasan aktif dari token yang dikirim klien."""
        return self.db.scalar(
            select(ShiftOfficer).where(
                ShiftOfficer.token_hash == hash_token(token),
                ShiftOfficer.left_at.is_(None),
            )
        )

    # --- bantu ---------------------------------------------------------------

    def _flush(self) -> None:
        """Menulis ke database sambil menerjemahkan pelanggaran unique."""
        try:
            self.db.flush()
        except IntegrityError as exc:  # pragma: no cover - jalur balapan
            self.db.rollback()
            raise self._translate(exc) from exc

    @staticmethod
    def _translate(exc: IntegrityError) -> ConflictError:
        if matches(exc, "uq_shifts_active_area", "shifts.active_area_id"):
            return ConflictError(
                "Lahan ini sudah punya shift terbuka. Coba masuk sekali lagi."
            )
        if matches(
            exc,
            "uq_shift_officers_active_officer",
            "shift_officers.active_officer_id",
        ):
            return DuplicateActiveAssignment(
                "Petugas ini masih bertugas di shift lain."
            )
        if matches(exc, "uq_shift_officers_token", "shift_officers.token_hash"):
            return ConflictError("Token bertabrakan. Coba masuk sekali lagi.")
        return ConflictError("Data jaga bentrok dengan data yang sudah ada.")
