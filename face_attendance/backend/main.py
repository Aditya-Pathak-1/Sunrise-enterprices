"""
main.py — FastAPI application entry point.

CHECKPOINT 1 routes (no face recognition required):
  GET  /health
  GET  /people
  GET  /attendance/today
  GET  /attendance/history/{employee_id}
  DELETE /people/{person_id}

CHECKPOINT 2 routes (stubs — face recognition not yet implemented):
  POST /register
  POST /recognize
  POST /attendance/check-in
  POST /attendance/check-out

Run with:
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

from __future__ import annotations

import logging
import os
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# Load .env if present (optional — all settings have defaults)
load_dotenv()

# Local modules
from database import init_db, get_connection
from models import (
    PersonOut,
    PersonListResponse,
    AttendanceTodayResponse,
    AttendanceHistoryResponse,
    AttendanceRecord,
    CheckInResponse,
    CheckOutResponse,
    RecognizeResponse,
    RegisterResponse,
    StatusResponse,
)
from attendance import (
    get_all_people,
    get_today_attendance,
    get_attendance_history,
    get_person_by_employee_id,
    delete_person,
    do_check_in,
    do_check_out,
)
from face_engine import face_engine

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App creation + startup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="FaceAttend API",
    description=(
        "Face-recognition based attendance system. "
        "Register people, scan faces, and record check-in/check-out."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ---------------------------------------------------------------------------
# CORS — allow all origins for LAN/development use
# ---------------------------------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event() -> None:
    """Initialize the database on server startup."""
    init_db()
    logger.info("[Startup] FaceAttend API is ready.")


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/health", tags=["System"], summary="Health check")
async def health_check() -> dict:
    return {"status": "ok", "message": "FaceAttend API is running."}

# ---------------------------------------------------------------------------
# Employee Authentication
# ---------------------------------------------------------------------------
from pydantic import BaseModel

class LoginRequest(BaseModel):
    name: str
    contact_number: str

class SignupRequest(BaseModel):
    name: str
    designation: str
    contact_number: str

def get_employees_data():
    path = Path(__file__).parent / "data" / "employees.json"
    if not path.exists():
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def save_employees_data(data):
    path = Path(__file__).parent / "data" / "employees.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

@app.post("/auth/login", tags=["Auth"])
async def login(req: LoginRequest):
    employees = get_employees_data()
    for emp in employees:
        if emp["name"].strip().lower() == req.name.strip().lower() and emp["contact_number"] == req.contact_number:
            return {"success": True, "message": "Login successful", "employee": emp}
    raise HTTPException(status_code=401, detail="Invalid Name or Contact Number")

@app.post("/auth/signup", tags=["Auth"])
async def signup(req: SignupRequest):
    employees = get_employees_data()
    # Check if exists
    for emp in employees:
        if emp["name"].strip().lower() == req.name.strip().lower() and emp["contact_number"] == req.contact_number:
            raise HTTPException(status_code=409, detail="Employee already exists")
    
    new_emp = {
        "name": req.name,
        "designation": req.designation,
        "contact_number": req.contact_number
    }
    employees.append(new_emp)
    save_employees_data(employees)
    return {"success": True, "message": "Signup successful", "employee": new_emp}

# ---------------------------------------------------------------------------
# People endpoints
# ---------------------------------------------------------------------------

@app.get(
    "/people",
    response_model=PersonListResponse,
    tags=["People"],
    summary="List all registered people",
)
async def list_people() -> PersonListResponse:
    """Return all registered people (without embeddings)."""
    people = get_all_people()
    return PersonListResponse(
        people=[PersonOut(**p) for p in people],
        total=len(people),
    )


@app.delete(
    "/people/{person_id}",
    response_model=StatusResponse,
    tags=["People"],
    summary="Delete a registered person",
)
async def remove_person(person_id: str) -> StatusResponse:
    """
    Delete a person by their internal UUID.
    Also deletes all their attendance records (cascade).
    """
    deleted = delete_person(person_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Person with id={person_id!r} not found.",
        )
    return StatusResponse(status="ok", message=f"Person {person_id!r} deleted successfully.")


# ---------------------------------------------------------------------------
# Registration endpoint (CHECKPOINT 2 for face recognition; structure now)
# ---------------------------------------------------------------------------

@app.post(
    "/register",
    response_model=RegisterResponse,
    tags=["People"],
    summary="Register a new person with face image(s)",
    status_code=status.HTTP_201_CREATED,
)
async def register_person(
    name: str = Form(..., description="Full name of the person"),
    employee_id: str = Form(..., description="Unique employee / student ID, e.g. EMP001"),
    images: list[UploadFile] = File(..., description="One or more face photos"),
) -> RegisterResponse:
    """
    Register a person.

    - Validates employee_id is unique.
    - Reads uploaded image(s).
    - Generates face embeddings via FaceEngine (CHECKPOINT 2).
    - Stores the person and their embeddings in the database.
    """
    # --- Validate uniqueness ---
    existing = get_person_by_employee_id(employee_id)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Employee ID {employee_id!r} is already registered as {existing['name']!r}.",
        )

    if not images:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="At least one face image is required.",
        )

    # --- Process images → embeddings (CHECKPOINT 2) ---
    embeddings: list[list[float]] = []
    for img_file in images:
        img_bytes = await img_file.read()
        if not img_bytes:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Uploaded file {img_file.filename!r} is empty.",
            )
        try:
            embedding = face_engine.get_embedding(img_bytes)
            embeddings.append(embedding)
        except NotImplementedError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "Face recognition engine is not yet active. "
                    "Complete CHECKPOINT 2 setup first."
                ),
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=str(exc),
            )

    # --- Persist to database ---
    person_uuid = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()

    with get_connection() as conn:
        conn.execute(
            """
            INSERT INTO people (id, employee_id, name, embeddings, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (person_uuid, employee_id, name, json.dumps(embeddings), created_at),
        )
        conn.commit()

    logger.info("[Register] New person: %s (%s) → %s", name, employee_id, person_uuid)
    return RegisterResponse(
        success=True,
        employee_id=employee_id,
        name=name,
        message=f"{name} registered successfully with {len(embeddings)} face image(s).",
    )


# ---------------------------------------------------------------------------
# Recognition endpoint (CHECKPOINT 2)
# ---------------------------------------------------------------------------

@app.post(
    "/recognize",
    response_model=RecognizeResponse,
    tags=["Recognition"],
    summary="Recognize a face from an uploaded image",
)
async def recognize_face(
    image: UploadFile = File(..., description="Face image to recognize"),
) -> RecognizeResponse:
    """
    Detect and recognize a face.

    Returns recognized=True + person details if match ≥ threshold.
    Returns recognized=False if no match or no face detected.
    """
    img_bytes = await image.read()
    if not img_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Uploaded image is empty.",
        )

    try:
        embedding = face_engine.get_embedding(img_bytes)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )
    except ValueError as exc:
        return RecognizeResponse(recognized=False, message=str(exc))

    from attendance import get_all_people_with_embeddings
    all_people = get_all_people_with_embeddings()

    try:
        best_person, similarity = face_engine.find_best_match(embedding, all_people)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )

    if best_person is None:
        return RecognizeResponse(
            recognized=False,
            similarity=None,
            message="Face not recognized. Unknown person.",
        )

    return RecognizeResponse(
        recognized=True,
        employee_id=best_person["employee_id"],
        name=best_person["name"],
        similarity=round(similarity, 4),
        message=f"Recognized: {best_person['name']} (similarity={similarity:.2%})",
    )


# ---------------------------------------------------------------------------
# Attendance: Check-In
# ---------------------------------------------------------------------------

@app.post(
    "/attendance/check-in",
    response_model=CheckInResponse,
    tags=["Attendance"],
    summary="Check in via face recognition",
    status_code=status.HTTP_200_OK,
)
async def check_in(
    image: UploadFile = File(..., description="Face image for recognition"),
) -> CheckInResponse:
    """
    Recognize the person in the uploaded image and record their check-in.

    - Rejects unknown faces.
    - Rejects duplicate check-ins.
    """
    img_bytes = await image.read()
    if not img_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Uploaded image is empty.",
        )

    # --- Recognize ---
    try:
        embedding = face_engine.get_embedding(img_bytes)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )

    from attendance import get_all_people_with_embeddings
    all_people = get_all_people_with_embeddings()

    try:
        best_person, similarity = face_engine.find_best_match(embedding, all_people)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )

    if best_person is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Face not recognized. Attendance not marked.",
        )

    # --- Check-in ---
    try:
        result = do_check_in(best_person["id"])
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    return CheckInResponse(**result)


# ---------------------------------------------------------------------------
# Attendance: Check-Out
# ---------------------------------------------------------------------------

@app.post(
    "/attendance/check-out",
    response_model=CheckOutResponse,
    tags=["Attendance"],
    summary="Check out via face recognition",
    status_code=status.HTTP_200_OK,
)
async def check_out(
    image: UploadFile = File(..., description="Face image for recognition"),
) -> CheckOutResponse:
    """
    Recognize the person and record their check-out.

    - Requires a prior check-in today.
    - Rejects duplicate check-outs.
    """
    img_bytes = await image.read()
    if not img_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Uploaded image is empty.",
        )

    # --- Recognize ---
    try:
        embedding = face_engine.get_embedding(img_bytes)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )

    from attendance import get_all_people_with_embeddings
    all_people = get_all_people_with_embeddings()

    try:
        best_person, similarity = face_engine.find_best_match(embedding, all_people)
    except NotImplementedError:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Face recognition engine is not yet active. Complete CHECKPOINT 2 setup.",
        )

    if best_person is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Face not recognized. Check-out not recorded.",
        )

    # --- Check-out ---
    try:
        result = do_check_out(best_person["id"])
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    except LookupError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))

    return CheckOutResponse(**result)


# ---------------------------------------------------------------------------
# Attendance: Today
# ---------------------------------------------------------------------------

@app.get(
    "/attendance/today",
    response_model=AttendanceTodayResponse,
    tags=["Attendance"],
    summary="Get today's attendance records",
)
async def today_attendance() -> AttendanceTodayResponse:
    """Return all attendance records for today's date."""
    from datetime import date
    records = get_today_attendance()
    return AttendanceTodayResponse(
        date=date.today().isoformat(),
        records=[AttendanceRecord(**r) for r in records],
        total=len(records),
    )


# ---------------------------------------------------------------------------
# Attendance: History
# ---------------------------------------------------------------------------

@app.get(
    "/attendance/history/{employee_id}",
    response_model=AttendanceHistoryResponse,
    tags=["Attendance"],
    summary="Get attendance history for a person",
)
async def attendance_history(employee_id: str) -> AttendanceHistoryResponse:
    """Return full attendance history for the given employee_id."""
    person, records = get_attendance_history(employee_id)
    if person is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Employee ID {employee_id!r} not found.",
        )
    return AttendanceHistoryResponse(
        employee_id=person["employee_id"],
        name=person["name"],
        records=[AttendanceRecord(**r) for r in records],
        total=len(records),
    )
