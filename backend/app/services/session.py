"""Sesi parkir: check-in, pencarian, penutupan, penolakan, pembatalan.

Aturan yang ditegakkan di sini:

* satu NIM dan satu plat tidak boleh punya lebih dari satu sesi aktif —
  dijaga unique index di database, bukan hanya oleh pemeriksaan di aplikasi;
* penolakan check-out tidak mengubah status sesi, hanya menambah event;
* pembatalan mengosongkan ``active_nim``/``active_plate`` lewat generated
  column sehingga NIM dan plat langsung bebas dipakai lagi.
"""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.clock import minutes_between, report_day_start_utc, utcnow
from app.config import settings
from app.errors import (
    ConflictError,
    DuplicateActiveSession,
    NoteRequired,
    SessionNotFound,
    SessionNotActive,
    ValidationError,
)
from app.integrity import matches
from app.models import (
    EventType,
    MatchMethod,
    ParkingSession,
    SessionEvent,
    SessionStatus,
    ShiftOfficer,
)
from app.schemas.session import CheckInForm, CheckOutForm
from app.services.plate import (
    levenshtein,
    normalize_plate,
    require_valid_plate,
    validate_nim,
)

CLOSED_STATUSES = (
    SessionStatus.MATCHED.value,
    SessionStatus.MANUAL_VERIFIED.value,
)
HISTORY_STATUSES = CLOSED_STATUSES


class SessionService:
    def __init__(self, db: Session) -> None:
        self.db = db

    # --- check-in ------------------------------------------------------------

    def check_in(
        self,
        assignment: ShiftOfficer,
        form: CheckInForm,
        photo_path: str | None = None,
    ) -> ParkingSession:
        """Membuat sesi parkir aktif."""
        nim = validate_nim(form.nim)
        plate = require_valid_plate(form.plate)

        # Retry dari klien tidak boleh membuat sesi kedua.
        if form.client_request_id:
            existing = self.db.scalar(
                select(ParkingSession).where(
                    ParkingSession.client_request_id == form.client_request_id
                )
            )
            if existing is not None:
                return existing

        session = ParkingSession(
            check_in_shift_officer_id=assignment.id,
            parking_area_id=assignment.shift.parking_area_id,
            nim=nim,
            plate_in=plate,
            checked_in_at=utcnow(),
            status=SessionStatus.ACTIVE.value,
            plate_in_photo_path=photo_path,
            client_request_id=form.client_request_id,
        )
        self.db.add(session)

        try:
            self.db.flush()
        except IntegrityError as exc:
            self.db.rollback()
            raise self._translate(exc) from exc

        self._add_event(session, assignment, EventType.CHECK_IN.value)
        self.db.commit()
        self.db.refresh(session)
        return session

    # --- pencarian saat check-out -------------------------------------------

    def lookup(
        self, plate_raw: str, nim_raw: str | None = None
    ) -> tuple[str | None, ParkingSession | None, list[ParkingSession], str | None]:
        """Mencari sesi aktif berlapis.

        Urutannya: plat persis → plat mirip → NIM. Mengembalikan
        ``(match_method, session, candidates, message)``.
        """
        plate = normalize_plate(plate_raw)

        exact = self.db.scalar(
            select(ParkingSession).where(
                ParkingSession.status == SessionStatus.ACTIVE.value,
                ParkingSession.plate_in == plate,
            )
        )
        if exact is not None:
            return MatchMethod.PLATE_EXACT.value, exact, [], None

        candidates = self._similar_candidates(plate)
        if candidates:
            return MatchMethod.PLATE_SIMILAR.value, None, candidates, None

        if nim_raw:
            nim = validate_nim(nim_raw)
            by_nim = self.db.scalar(
                select(ParkingSession).where(
                    ParkingSession.status == SessionStatus.ACTIVE.value,
                    ParkingSession.nim == nim,
                )
            )
            if by_nim is not None:
                return MatchMethod.NIM_FALLBACK.value, by_nim, [], None

        return None, None, [], "Sesi tidak ditemukan."

    def _similar_candidates(self, plate: str) -> list[ParkingSession]:
        """Sesi aktif yang platnya berjarak edit tidak lebih dari ambang.

        Kandidat disaring dengan menghitung jarak edit di sisi aplikasi. Untuk
        satu pos parkir jumlah sesi aktif kecil, jadi pendekatan ini memadai.
        """
        rows = self.db.scalars(
            select(ParkingSession)
            .where(ParkingSession.status == SessionStatus.ACTIVE.value)
            .order_by(ParkingSession.checked_in_at)
        ).all()

        scored = [
            (levenshtein(plate, row.plate_in), row.checked_in_at, row)
            for row in rows
            if abs(len(plate) - len(row.plate_in)) <= settings.plate_similar_max_distance
        ]
        hits = [
            row
            for distance, _, row in sorted(scored, key=lambda item: (item[0], item[1]))
            if distance <= settings.plate_similar_max_distance
        ]
        return hits

    # --- penutupan -----------------------------------------------------------

    def close(
        self,
        session_id: int,
        assignment: ShiftOfficer,
        form: CheckOutForm,
        photo_path: str | None = None,
    ) -> ParkingSession:
        """Menutup sesi sebagai Sesuai atau Verifikasi Manual."""
        session = self._require_active(session_id)

        if form.status not in CLOSED_STATUSES:
            raise ValidationError(
                "Status penutupan harus matched atau manual_verified.",
                details={"status": form.status},
            )

        note = (form.note or "").strip()
        if form.status == SessionStatus.MANUAL_VERIFIED.value and not note:
            raise NoteRequired("Verifikasi manual wajib disertai catatan.")

        session.plate_out = require_valid_plate(form.plate) if form.plate else None
        session.checked_out_at = utcnow()
        session.check_out_shift_officer_id = assignment.id
        session.status = form.status
        session.match_method = form.match_method or MatchMethod.PLATE_EXACT.value
        session.verification_note = note or None
        if photo_path:
            session.plate_out_photo_path = photo_path

        self._add_event(
            session,
            assignment,
            EventType.CHECK_OUT_CLOSED.value,
            note=note or None,
            metadata={"status": form.status, "match_method": session.match_method},
        )
        if form.status == SessionStatus.MANUAL_VERIFIED.value:
            self._add_event(
                session,
                assignment,
                EventType.MANUAL_VERIFICATION.value,
                note=note,
            )

        self.db.commit()
        self.db.refresh(session)
        return session

    # --- penolakan -----------------------------------------------------------

    def reject(
        self, session_id: int, assignment: ShiftOfficer, note: str
    ) -> SessionEvent:
        """Mencatat penolakan check-out. Sesi tetap aktif."""
        session = self._require_active(session_id)

        clean_note = (note or "").strip()
        if not clean_note:
            raise NoteRequired("Penolakan check-out wajib disertai catatan.")

        event = self._add_event(
            session, assignment, EventType.CHECK_OUT_REJECTED.value, note=clean_note
        )
        self.db.commit()
        self.db.refresh(event)
        return event

    # --- pembatalan ----------------------------------------------------------

    def void(
        self, session_id: int, assignment: ShiftOfficer, note: str
    ) -> ParkingSession:
        """Membatalkan check-in yang salah.

        Karena ``active_nim`` dan ``active_plate`` hanya berisi nilai saat status
        ``active``, mengubah status ke ``voided`` otomatis membebaskan NIM dan
        plat itu untuk dipakai lagi. Baris tidak dihapus.
        """
        session = self.db.get(ParkingSession, session_id)
        if session is None:
            raise SessionNotFound("Sesi tidak ditemukan.")

        # Sudah dibatalkan: tidak mengubah apa pun dan tidak menambah event.
        if session.status == SessionStatus.VOIDED.value:
            return session

        if session.status != SessionStatus.ACTIVE.value:
            raise SessionNotActive(
                "Sesi yang sudah ditutup tidak bisa dibatalkan.",
                details={"status": session.status},
            )

        clean_note = (note or "").strip()
        if not clean_note:
            raise NoteRequired("Pembatalan check-in wajib disertai alasan.")

        session.status = SessionStatus.VOIDED.value
        session.verification_note = clean_note

        self._add_event(
            session, assignment, EventType.CHECK_IN_VOIDED.value, note=clean_note
        )
        self.db.commit()
        self.db.refresh(session)
        return session

    # --- daftar dan riwayat --------------------------------------------------

    def list_active(self) -> list[ParkingSession]:
        """Kendaraan yang masih parkir, terlama lebih dulu."""
        return list(
            self.db.scalars(
                select(ParkingSession)
                .where(ParkingSession.status == SessionStatus.ACTIVE.value)
                .order_by(ParkingSession.checked_in_at)
            ).all()
        )

    def history(
        self, query: str | None, limit: int, offset: int
    ) -> tuple[list[ParkingSession], int]:
        """Riwayat sesi yang benar-benar ditutup, dapat dicari per NIM/plat."""
        conditions = [ParkingSession.status.in_(HISTORY_STATUSES)]

        if query:
            needle = query.strip().upper()
            conditions.append(
                func.upper(ParkingSession.nim).like(f"%{needle}%")
                | func.upper(ParkingSession.plate_in).like(f"%{needle}%")
                | func.upper(func.coalesce(ParkingSession.plate_out, "")).like(
                    f"%{needle}%"
                )
            )

        total = self.db.scalar(
            select(func.count()).select_from(ParkingSession).where(*conditions)
        )
        rows = self.db.scalars(
            select(ParkingSession)
            .where(*conditions)
            .order_by(ParkingSession.checked_in_at.desc())
            .limit(limit)
            .offset(offset)
        ).all()
        return list(rows), int(total or 0)

    def dashboard(self) -> dict:
        """Ringkasan beranda. Batas hari dihitung dalam zona laporan."""
        day_start = report_day_start_utc()

        active_now = self.db.scalar(
            select(func.count())
            .select_from(ParkingSession)
            .where(ParkingSession.status == SessionStatus.ACTIVE.value)
        )
        checked_in_today = self.db.scalar(
            select(func.count())
            .select_from(ParkingSession)
            .where(
                ParkingSession.checked_in_at >= day_start,
                ParkingSession.status != SessionStatus.VOIDED.value,
            )
        )
        checked_out_today = self.db.scalar(
            select(func.count())
            .select_from(ParkingSession)
            .where(ParkingSession.checked_out_at >= day_start)
        )
        recent = self.db.scalars(
            select(ParkingSession)
            .order_by(ParkingSession.updated_at.desc())
            .limit(10)
        ).all()

        return {
            "active_now": int(active_now or 0),
            "checked_in_today": int(checked_in_today or 0),
            "checked_out_today": int(checked_out_today or 0),
            "recent": list(recent),
        }

    def get(self, session_id: int) -> ParkingSession:
        session = self.db.scalar(
            select(ParkingSession)
            .where(ParkingSession.id == session_id)
            .options(selectinload(ParkingSession.events))
        )
        if session is None:
            raise SessionNotFound("Sesi tidak ditemukan.")
        return session

    def duration_minutes(self, session: ParkingSession) -> int:
        return minutes_between(
            session.checked_in_at, session.checked_out_at or utcnow()
        )

    # --- bantu ---------------------------------------------------------------

    def _require_active(self, session_id: int) -> ParkingSession:
        session = self.db.get(ParkingSession, session_id)
        if session is None:
            raise SessionNotFound("Sesi tidak ditemukan.")
        if session.status != SessionStatus.ACTIVE.value:
            raise SessionNotActive(
                "Sesi ini sudah tidak aktif.",
                details={"status": session.status},
            )
        return session

    def _add_event(
        self,
        session: ParkingSession,
        assignment: ShiftOfficer,
        event_type: str,
        note: str | None = None,
        metadata: dict | None = None,
    ) -> SessionEvent:
        event = SessionEvent(
            parking_session_id=session.id,
            shift_officer_id=assignment.id,
            event_type=event_type,
            note=note,
            metadata_json=metadata,
            created_at=utcnow(),
        )
        self.db.add(event)
        return event

    @staticmethod
    def _translate(exc: IntegrityError) -> ConflictError:
        if matches(exc, "uq_sessions_active_nim", "parking_sessions.active_nim"):
            return DuplicateActiveSession(
                "NIM ini sudah punya sesi parkir aktif.",
                details={"field": "nim"},
            )
        if matches(exc, "uq_sessions_active_plate", "parking_sessions.active_plate"):
            return DuplicateActiveSession(
                "Plat ini sudah punya sesi parkir aktif.",
                details={"field": "plate"},
            )
        if matches(
            exc, "uq_sessions_client_request", "parking_sessions.client_request_id"
        ):
            return ConflictError(
                "Permintaan ini sudah pernah diproses.",
                details={"field": "client_request_id"},
            )
        return ConflictError("Data sesi bentrok dengan data yang sudah ada.")
