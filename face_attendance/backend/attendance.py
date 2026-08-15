"""
attendance.py — Business logic for attendance check-in / check-out.

Rules enforced here (not in the API layer):
  1. One check-in per person per day.
  2. One check-out per person per day.
  3. Check-out requires a prior check-in.
  4. Duplicate check-in is rejected with a clear error.
  5. Duplicate check-out is rejected with a clear error.
  6. No attendance is marked for unrecognized persons.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone, date as date_type
from typing import Optional

from database import get_connection

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _now_iso() -> str:
    """Return the current UTC time as an ISO-8601 string."""
    return datetime.now(timezone.utc).isoformat()


def _today_str() -> str:
    """Return today's date as YYYY-MM-DD in UTC."""
    return date_type.today().isoformat()


# ---------------------------------------------------------------------------
# Read operations
# ---------------------------------------------------------------------------

def get_today_attendance() -> list[dict]:
    """
    Return all attendance records for today, enriched with person info.
    Returns a list of dicts suitable for AttendanceRecord Pydantic model.
    """
    today = _today_str()
    with get_connection() as conn:
        rows = conn.execute(
            """
            SELECT
                a.id,
                a.person_id,
                p.employee_id,
                p.name,
                a.date,
                a.check_in,
                a.check_out,
                a.status
            FROM attendance a
            JOIN people p ON p.id = a.person_id
            WHERE a.date = ?
            ORDER BY a.check_in ASC
            """,
            (today,),
        ).fetchall()
    return [dict(r) for r in rows]


def get_attendance_history(employee_id: str) -> tuple[Optional[dict], list[dict]]:
    """
    Return (person_dict, [attendance_records]) for a given employee_id.
    Returns (None, []) if the person is not found.
    """
    with get_connection() as conn:
        person_row = conn.execute(
            "SELECT id, employee_id, name, created_at FROM people WHERE employee_id = ?",
            (employee_id,),
        ).fetchone()

        if not person_row:
            return None, []

        person = dict(person_row)

        rows = conn.execute(
            """
            SELECT
                a.id,
                a.person_id,
                p.employee_id,
                p.name,
                a.date,
                a.check_in,
                a.check_out,
                a.status
            FROM attendance a
            JOIN people p ON p.id = a.person_id
            WHERE a.person_id = ?
            ORDER BY a.date DESC
            """,
            (person["id"],),
        ).fetchall()

    return person, [dict(r) for r in rows]


def get_today_record_for_person(person_id: str) -> Optional[dict]:
    """Return today's attendance row for a given internal person UUID, or None."""
    today = _today_str()
    with get_connection() as conn:
        row = conn.execute(
            """
            SELECT a.id, a.person_id, p.employee_id, p.name,
                   a.date, a.check_in, a.check_out, a.status
            FROM attendance a
            JOIN people p ON p.id = a.person_id
            WHERE a.person_id = ? AND a.date = ?
            """,
            (person_id, today),
        ).fetchone()
    return dict(row) if row else None


# ---------------------------------------------------------------------------
# Write operations
# ---------------------------------------------------------------------------

def do_check_in(person_id: str) -> dict:
    """
    Mark check-in for a person today.

    Returns
    -------
    dict with keys: success, employee_id, name, check_in, message

    Raises
    ------
    ValueError — if already checked in today.
    LookupError — if person_id is not found.
    """
    today = _today_str()
    now = _now_iso()

    with get_connection() as conn:
        # Verify person exists
        person_row = conn.execute(
            "SELECT id, employee_id, name FROM people WHERE id = ?",
            (person_id,),
        ).fetchone()
        if not person_row:
            raise LookupError(f"Person with id={person_id!r} not found.")
        person = dict(person_row)

        # Check for existing record today
        existing = conn.execute(
            "SELECT check_in FROM attendance WHERE person_id = ? AND date = ?",
            (person_id, today),
        ).fetchone()

        if existing:
            raise ValueError(
                f"{person['name']} has already checked in today at "
                f"{existing['check_in']}. Duplicate check-in rejected."
            )

        # Insert new check-in record
        conn.execute(
            """
            INSERT INTO attendance (person_id, date, check_in, status)
            VALUES (?, ?, ?, 'present')
            """,
            (person_id, today, now),
        )
        conn.commit()

    logger.info("[Attendance] CHECK-IN: %s (%s) @ %s", person["name"], person["employee_id"], now)
    return {
        "success": True,
        "employee_id": person["employee_id"],
        "name": person["name"],
        "check_in": now,
        "message": f"Check-in successful for {person['name']}.",
    }


def do_check_out(person_id: str) -> dict:
    """
    Mark check-out for a person today.

    Returns
    -------
    dict with keys: success, employee_id, name, check_out, message

    Raises
    ------
    ValueError — if already checked out, or no check-in exists.
    LookupError — if person_id is not found.
    """
    today = _today_str()
    now = _now_iso()

    with get_connection() as conn:
        # Verify person exists
        person_row = conn.execute(
            "SELECT id, employee_id, name FROM people WHERE id = ?",
            (person_id,),
        ).fetchone()
        if not person_row:
            raise LookupError(f"Person with id={person_id!r} not found.")
        person = dict(person_row)

        # Check for existing record
        existing = conn.execute(
            "SELECT check_in, check_out FROM attendance WHERE person_id = ? AND date = ?",
            (person_id, today),
        ).fetchone()

        if not existing or not existing["check_in"]:
            raise ValueError(
                f"{person['name']} has not checked in today. "
                "Check-out requires a prior check-in."
            )

        if existing["check_out"]:
            raise ValueError(
                f"{person['name']} has already checked out today at "
                f"{existing['check_out']}. Duplicate check-out rejected."
            )

        # Update check-out
        conn.execute(
            """
            UPDATE attendance
            SET check_out = ?, status = 'checked_out'
            WHERE person_id = ? AND date = ?
            """,
            (now, person_id, today),
        )
        conn.commit()

    logger.info("[Attendance] CHECK-OUT: %s (%s) @ %s", person["name"], person["employee_id"], now)
    return {
        "success": True,
        "employee_id": person["employee_id"],
        "name": person["name"],
        "check_out": now,
        "message": f"Check-out successful for {person['name']}.",
    }


# ---------------------------------------------------------------------------
# People helpers
# ---------------------------------------------------------------------------

def get_all_people() -> list[dict]:
    """Return all registered people (without embeddings)."""
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT id, employee_id, name, created_at FROM people ORDER BY name ASC"
        ).fetchall()
    return [dict(r) for r in rows]


def get_person_by_employee_id(employee_id: str) -> Optional[dict]:
    """Return person dict (without embeddings) or None."""
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id, employee_id, name, created_at FROM people WHERE employee_id = ?",
            (employee_id,),
        ).fetchone()
    return dict(row) if row else None


def get_all_people_with_embeddings() -> list[dict]:
    """Return all people INCLUDING their embeddings (for recognition)."""
    with get_connection() as conn:
        rows = conn.execute(
            "SELECT id, employee_id, name, embeddings FROM people"
        ).fetchall()
    result = []
    for r in rows:
        d = dict(r)
        d["embeddings"] = json.loads(d["embeddings"])   # list[list[float]]
        result.append(d)
    return result


def delete_person(person_id: str) -> bool:
    """
    Delete a person by internal UUID.
    Returns True if a row was deleted, False if not found.
    Cascade deletes their attendance records.
    """
    with get_connection() as conn:
        cursor = conn.execute("DELETE FROM people WHERE id = ?", (person_id,))
        conn.commit()
    return cursor.rowcount > 0
