"""Skema Pydantic untuk permintaan dan respons API."""

from app.schemas.area import AreaOut
from app.schemas.auth import SessionOut, SignInForm, SignInOut
from app.schemas.common import ErrorOut, PageMeta
from app.schemas.officer import OfficerCreate, OfficerOut, OfficerUpdate
from app.schemas.session import (
    ActiveSessionOut,
    CheckInForm,
    CheckOutForm,
    DashboardOut,
    HistoryItemOut,
    LookupCandidateOut,
    LookupResultOut,
    RejectForm,
    SessionDetailOut,
    VoidForm,
)
from app.schemas.shift import (
    AssignmentOut,
    ShiftCloseForm,
    ShiftJoinForm,
    ShiftLoginOut,
    ShiftOpenForm,
    ShiftOut,
)

__all__ = [
    "AreaOut",
    "ErrorOut",
    "PageMeta",
    "SessionOut",
    "SignInForm",
    "SignInOut",
    "OfficerCreate",
    "OfficerOut",
    "OfficerUpdate",
    "AssignmentOut",
    "ShiftCloseForm",
    "ShiftJoinForm",
    "ShiftLoginOut",
    "ShiftOpenForm",
    "ShiftOut",
    "ActiveSessionOut",
    "CheckInForm",
    "CheckOutForm",
    "DashboardOut",
    "HistoryItemOut",
    "LookupCandidateOut",
    "LookupResultOut",
    "RejectForm",
    "SessionDetailOut",
    "VoidForm",
]
