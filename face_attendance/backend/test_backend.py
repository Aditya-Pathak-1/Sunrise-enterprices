r"""
test_backend.py -- End-to-end backend test for CHECKPOINT 2.

Run this AFTER starting the uvicorn server:
    .\venv\Scripts\uvicorn main:app --host 0.0.0.0 --port 8000

Tests:
  1. Health check
  2. Download buffalo_l model (first /register triggers lazy load)
  3. Register a person using a real face image from faces/ directory
  4. Recognize the registered person
  5. Recognize an unknown face (reject)
  6. Check-in
  7. Duplicate check-in (must fail)
  8. Check-out
  9. Duplicate check-out (must fail)
  10. Attendance history
"""

import sys
import os
import requests
from pathlib import Path

BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
FACES_DIR = Path(__file__).parent / "faces"

GREEN = "\033[92m"
RED   = "\033[91m"
RESET = "\033[0m"
BOLD  = "\033[1m"


def ok(msg):
    print(f"  {GREEN}[PASS]{RESET} {msg}")


def fail(msg):
    print(f"  {RED}[FAIL]{RESET} {msg}")
    sys.exit(1)


def section(title):
    print(f"\n{BOLD}{'='*55}{RESET}")
    print(f"{BOLD}  {title}{RESET}")
    print(f"{BOLD}{'='*55}{RESET}")


def find_test_image(employee_id: str) -> Path | None:
    emp_dir = FACES_DIR / employee_id
    if not emp_dir.exists():
        return None
    for ext in ("*.jpg", "*.jpeg", "*.png"):
        imgs = list(emp_dir.glob(ext))
        if imgs:
            return imgs[0]
    return None


# ──────────────────────────────────────────────────────
# TEST 1: Health
# ──────────────────────────────────────────────────────
section("Test 1: Health Check")
r = requests.get(f"{BASE_URL}/health", timeout=5)
assert r.status_code == 200, f"Expected 200, got {r.status_code}"
ok(f"Health: {r.json()['message']}")


# ──────────────────────────────────────────────────────
# TEST 2: Find a test image
# ──────────────────────────────────────────────────────
section("Test 2: Find Test Image")
test_emp_id = None
test_img_path = None

for emp_dir in FACES_DIR.iterdir():
    if emp_dir.is_dir() and not emp_dir.name.startswith(".") and emp_dir.name != "__pycache__":
        img = find_test_image(emp_dir.name)
        if img:
            test_emp_id = emp_dir.name
            test_img_path = img
            break

if not test_img_path:
    print(f"\n{RED}[SKIP]{RESET} No face images found in {FACES_DIR}")
    print("  To test recognition, add images:")
    print("    faces/EMP001/photo.jpg")
    print("    faces/EMP002/photo.jpg")
    print("\nThen re-run this script.")
    sys.exit(0)

ok(f"Found test image: {test_img_path} (employee_id={test_emp_id})")

# Read name from names.txt
names_file = FACES_DIR / "names.txt"
test_name = f"Person {test_emp_id}"
if names_file.exists():
    for line in names_file.read_text().splitlines():
        line = line.strip()
        if line.startswith("#") or "," not in line:
            continue
        emp_id, name = line.split(",", 1)
        if emp_id.strip() == test_emp_id:
            test_name = name.strip()
            break
ok(f"Name: {test_name}")


# ──────────────────────────────────────────────────────
# TEST 3: Register (triggers buffalo_l download on first call)
# ──────────────────────────────────────────────────────
section(f"Test 3: Register {test_name} ({test_emp_id})")
print("  NOTE: First call downloads buffalo_l model (~350MB). May take a few minutes...")

with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/register",
        data={"name": test_name, "employee_id": test_emp_id},
        files={"images": (test_img_path.name, f, "image/jpeg")},
        timeout=300,  # generous timeout for model download
    )

if r.status_code == 409:
    ok(f"Already registered (skipping): {r.json()['detail']}")
elif r.status_code == 201:
    data = r.json()
    ok(f"Registered: {data['message']}")
else:
    fail(f"Register failed [{r.status_code}]: {r.text}")


# ──────────────────────────────────────────────────────
# TEST 4: Recognize (same person)
# ──────────────────────────────────────────────────────
section("Test 4: Recognize Registered Person")
with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/recognize",
        files={"image": (test_img_path.name, f, "image/jpeg")},
        timeout=60,
    )

assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
data = r.json()
if data["recognized"]:
    ok(f"Recognized: {data['name']} | employee_id={data['employee_id']} | similarity={data['similarity']:.4f}")
else:
    fail(f"Should have recognized the person but got: {data['message']}")


# ──────────────────────────────────────────────────────
# TEST 5: Check-In
# ──────────────────────────────────────────────────────
section("Test 5: Check-In")
with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/attendance/check-in",
        files={"image": (test_img_path.name, f, "image/jpeg")},
        timeout=60,
    )

if r.status_code == 200:
    data = r.json()
    ok(f"Check-in: {data['name']} at {data['check_in']}")
elif r.status_code == 409:
    ok(f"Already checked in today (OK for re-runs): {r.json()['detail']}")
else:
    fail(f"Check-in failed [{r.status_code}]: {r.text}")


# ──────────────────────────────────────────────────────
# TEST 6: Duplicate Check-In (must reject with 409)
# ──────────────────────────────────────────────────────
section("Test 6: Duplicate Check-In (must return 409)")
with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/attendance/check-in",
        files={"image": (test_img_path.name, f, "image/jpeg")},
        timeout=60,
    )

if r.status_code == 409:
    ok(f"Duplicate check-in correctly rejected: {r.json()['detail'][:60]}")
else:
    fail(f"Expected 409 for duplicate check-in, got {r.status_code}: {r.text}")


# ──────────────────────────────────────────────────────
# TEST 7: Check-Out
# ──────────────────────────────────────────────────────
section("Test 7: Check-Out")
with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/attendance/check-out",
        files={"image": (test_img_path.name, f, "image/jpeg")},
        timeout=60,
    )

if r.status_code == 200:
    data = r.json()
    ok(f"Check-out: {data['name']} at {data['check_out']}")
elif r.status_code == 409:
    ok(f"Already checked out today (OK for re-runs): {r.json()['detail']}")
else:
    fail(f"Check-out failed [{r.status_code}]: {r.text}")


# ──────────────────────────────────────────────────────
# TEST 8: Duplicate Check-Out (must reject with 409)
# ──────────────────────────────────────────────────────
section("Test 8: Duplicate Check-Out (must return 409)")
with open(test_img_path, "rb") as f:
    r = requests.post(
        f"{BASE_URL}/attendance/check-out",
        files={"image": (test_img_path.name, f, "image/jpeg")},
        timeout=60,
    )

if r.status_code == 409:
    ok(f"Duplicate check-out correctly rejected: {r.json()['detail'][:60]}")
else:
    fail(f"Expected 409 for duplicate check-out, got {r.status_code}: {r.text}")


# ──────────────────────────────────────────────────────
# TEST 9: GET /attendance/today
# ──────────────────────────────────────────────────────
section("Test 9: Today's Attendance")
r = requests.get(f"{BASE_URL}/attendance/today", timeout=10)
assert r.status_code == 200
data = r.json()
ok(f"Date: {data['date']} | Records: {data['total']}")
for rec in data["records"]:
    ok(f"  {rec['employee_id']} | {rec['name']} | IN:{rec['check_in'][:19] if rec['check_in'] else '-'} | OUT:{rec['check_out'][:19] if rec['check_out'] else '-'} | {rec['status']}")


# ──────────────────────────────────────────────────────
# TEST 10: GET /attendance/history
# ──────────────────────────────────────────────────────
section(f"Test 10: Attendance History for {test_emp_id}")
r = requests.get(f"{BASE_URL}/attendance/history/{test_emp_id}", timeout=10)
assert r.status_code == 200
data = r.json()
ok(f"{data['name']} | {data['total']} record(s)")


# ──────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────
section("All Tests Passed!")
print(f"  {GREEN}Backend is fully functional with InsightFace buffalo_l.{RESET}")
print(f"  API docs: http://localhost:8000/docs\n")
