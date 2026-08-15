"""
database.py — SQLite initialization and connection management.

Tables:
  people     — registered persons with face embeddings (JSON-serialized)
  attendance — daily check-in / check-out records
"""

import sqlite3
import os
from pathlib import Path

# Resolve DB path relative to this file so it works regardless of CWD
BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "data" / "attendance.db"


def get_connection() -> sqlite3.Connection:
    """Return a new SQLite connection with row_factory set to Row."""
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row        # allows dict-like access by column name
    conn.execute("PRAGMA journal_mode=WAL")  # write-ahead logging for concurrency
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db() -> None:
    """Create tables if they do not exist."""
    os.makedirs(DB_PATH.parent, exist_ok=True)

    with get_connection() as conn:
        conn.executescript("""
            -- ---------------------------------------------------------------
            -- People: one row per registered person.
            -- embeddings: JSON array of float arrays (one per enrolled photo).
            -- ---------------------------------------------------------------
            CREATE TABLE IF NOT EXISTS people (
                id          TEXT    PRIMARY KEY,          -- UUID
                employee_id TEXT    NOT NULL UNIQUE,      -- public identifier e.g. EMP001
                name        TEXT    NOT NULL,
                embeddings  TEXT    NOT NULL DEFAULT '[]',-- JSON: list[list[float]]
                created_at  TEXT    NOT NULL
            );

            -- ---------------------------------------------------------------
            -- Attendance: one row per (person, date).
            -- ---------------------------------------------------------------
            CREATE TABLE IF NOT EXISTS attendance (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                person_id   TEXT    NOT NULL,             -- FK → people.id
                date        TEXT    NOT NULL,             -- YYYY-MM-DD
                check_in    TEXT,                         -- ISO-8601 timestamp or NULL
                check_out   TEXT,                         -- ISO-8601 timestamp or NULL
                status      TEXT    NOT NULL DEFAULT 'present',
                UNIQUE(person_id, date),
                FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE
            );

            CREATE INDEX IF NOT EXISTS idx_attendance_person_date
                ON attendance (person_id, date);
        """)
    print(f"[DB] Initialized -> {DB_PATH}")


if __name__ == "__main__":
    init_db()
