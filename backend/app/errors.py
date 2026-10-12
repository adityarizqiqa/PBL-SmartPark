"""Kesalahan domain beserta padanan kode HTTP-nya.

Service melempar exception ini; handler di ``main.py`` yang mengubahnya menjadi
respons JSON. Dengan begitu lapisan service tidak perlu tahu soal HTTP.
"""

from __future__ import annotations


class AppError(Exception):
    """Kesalahan yang sudah dipahami aplikasi."""

    status_code = 400
    code = "bad_request"

    def __init__(self, message: str, *, details: dict | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or {}


class NotFoundError(AppError):
    status_code = 404
    code = "not_found"


class ConflictError(AppError):
    status_code = 409
    code = "conflict"


class ValidationError(AppError):
    status_code = 422
    code = "validation_error"


class AuthError(AppError):
    status_code = 401
    code = "unauthorized"


class ForbiddenError(AppError):
    """Terautentikasi, tetapi perannya tidak berwenang."""

    status_code = 403
    code = "forbidden"


class RateLimitError(AppError):
    status_code = 429
    code = "too_many_requests"


# --- kesalahan spesifik domain ------------------------------------------------


class AreaNotFound(NotFoundError):
    code = "area_not_found"


class OfficerNotFound(NotFoundError):
    code = "officer_not_found"


class SessionNotFound(NotFoundError):
    code = "session_not_found"


class ShiftNotFound(NotFoundError):
    code = "shift_not_found"


class AssignmentNotFound(AuthError):
    code = "assignment_not_active"

class NotSpv(ForbiddenError):
    """Operasi pengelolaan lahan/shift hanya untuk pengawas (SPV)."""

    code = "not_spv"


class InvalidCredentials(AuthError):
    code = "invalid_credentials"


class InactiveOfficer(AuthError):
    code = "officer_inactive"


class PasswordNotSet(AuthError):
    code = "password_not_set"


class AreaInactive(ConflictError):
    code = "area_inactive"


class DuplicateActiveSession(ConflictError):
    code = "duplicate_active_session"


class DuplicateActiveAssignment(ConflictError):
    code = "duplicate_active_assignment"


class ShiftAlreadyOpen(ConflictError):
    code = "shift_already_open"


class SessionNotActive(ConflictError):
    code = "session_not_active"


class NoteRequired(ValidationError):
    code = "note_required"


class InvalidPlate(ValidationError):
    code = "invalid_plate"


class InvalidNim(ValidationError):
    code = "invalid_nim"
