"""
models.py — Pydantic request and response models for all API endpoints.

All public-facing identifiers use `employee_id`.
Internal UUIDs are only used as SQLite primary keys.
"""

from __future__ import annotations
from typing import Optional, List
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Person models
# ---------------------------------------------------------------------------

class PersonOut(BaseModel):
    """Serialized person returned by GET /people and related endpoints."""
    id: str                        # internal UUID
    employee_id: str
    name: str
    created_at: str


class PersonListResponse(BaseModel):
    people: List[PersonOut]
    total: int


# ---------------------------------------------------------------------------
# Registration models
# ---------------------------------------------------------------------------

class RegisterResponse(BaseModel):
    """Returned after successful POST /register."""
    success: bool
    employee_id: str
    name: str
    message: str


# ---------------------------------------------------------------------------
# Recognition models
# ---------------------------------------------------------------------------

class RecognizeResponse(BaseModel):
    """Returned by POST /recognize."""
    recognized: bool
    employee_id: Optional[str] = None
    name: Optional[str] = None
    similarity: Optional[float] = None
    message: str


# ---------------------------------------------------------------------------
# Attendance models
# ---------------------------------------------------------------------------

class AttendanceRecord(BaseModel):
    """One attendance record (one row in the attendance table)."""
    id: int
    person_id: str                 # internal UUID
    employee_id: str
    name: str
    date: str
    check_in: Optional[str] = None
    check_out: Optional[str] = None
    status: str


class AttendanceTodayResponse(BaseModel):
    date: str
    records: List[AttendanceRecord]
    total: int


class AttendanceHistoryResponse(BaseModel):
    employee_id: str
    name: str
    records: List[AttendanceRecord]
    total: int


class CheckInResponse(BaseModel):
    success: bool
    employee_id: str
    name: str
    check_in: str                  # ISO-8601 timestamp
    message: str


class CheckOutResponse(BaseModel):
    success: bool
    employee_id: str
    name: str
    check_out: str                 # ISO-8601 timestamp
    message: str


# ---------------------------------------------------------------------------
# Generic error / status models
# ---------------------------------------------------------------------------

class ErrorResponse(BaseModel):
    detail: str


class StatusResponse(BaseModel):
    status: str
    message: str
