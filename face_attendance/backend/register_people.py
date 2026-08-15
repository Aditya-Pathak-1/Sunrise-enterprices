"""
register_people.py — Batch registration script for FaceAttend.

CHECKPOINT 1: Directory scanning + validation structure.
CHECKPOINT 2: Embedding generation will be wired in.

Usage
─────
Place face images in this structure:
    backend/faces/
        EMP001/          ← employee_id is the folder name
            photo1.jpg
            photo2.jpg
        EMP002/
            photo1.jpg

Then run (from the backend/ directory, with venv active):
    python register_people.py

Or register a single person:
    python register_people.py --employee-id EMP003 --name "Priya Sharma"

The script will:
  1. Read the faces/ directory (or --faces-dir argument).
  2. For each employee folder, find all images.
  3. [CHECKPOINT 2] Generate embeddings for each image.
  4. Register the person via the backend REST API (POST /register).
  5. Print a summary table.

Environment
───────────
  API_BASE_URL  : Backend URL (default: http://localhost:8000)
  FACES_DIR     : Override faces directory (default: ./faces)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000")
FACES_DIR = Path(os.environ.get("FACES_DIR", Path(__file__).parent / "faces"))

SUPPORTED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Name mapping: if employee folder name has no matching --names file,
# we derive name from folder name (e.g., EMP001 → "Person EMP001").
# You can provide a names.txt file with lines: EMP001,Arjun Sharma
NAMES_FILE = FACES_DIR / "names.txt"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_name_map() -> dict[str, str]:
    """
    Load employee_id → name mapping from names.txt if it exists.
    Format: one line per person: EMPID,Full Name
    """
    mapping: dict[str, str] = {}
    if NAMES_FILE.exists():
        with open(NAMES_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(",", 1)
                if len(parts) == 2:
                    emp_id, name = parts[0].strip(), parts[1].strip()
                    mapping[emp_id] = name
    return mapping


def get_image_files(folder: Path) -> list[Path]:
    """Return all supported image files in a folder (non-recursive)."""
    return sorted(
        p for p in folder.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTENSIONS
    )


def check_backend() -> bool:
    """Return True if the backend is reachable."""
    try:
        resp = requests.get(f"{API_BASE_URL}/health", timeout=5)
        return resp.status_code == 200
    except requests.RequestException:
        return False


def register_person_via_api(
    employee_id: str,
    name: str,
    image_paths: list[Path],
) -> dict:
    """
    POST /register with the given person and images.
    Returns the parsed JSON response dict.
    Raises requests.HTTPError on non-2xx responses.
    """
    files = []
    file_handles = []
    try:
        for img_path in image_paths:
            fh = open(img_path, "rb")
            file_handles.append(fh)
            files.append(("images", (img_path.name, fh, "image/jpeg")))

        data = {"name": name, "employee_id": employee_id}
        response = requests.post(
            f"{API_BASE_URL}/register",
            data=data,
            files=files,
            timeout=60,        # allow time for embedding generation
        )
        response.raise_for_status()
        return response.json()
    finally:
        for fh in file_handles:
            fh.close()


# ---------------------------------------------------------------------------
# Main registration flow
# ---------------------------------------------------------------------------

def register_all(faces_dir: Path, dry_run: bool = False) -> None:
    """Scan faces_dir and register all people found."""
    if not faces_dir.exists():
        print(f"[ERROR] Faces directory not found: {faces_dir}")
        print(f"  Create it and add subdirectories named by employee_id.")
        sys.exit(1)

    name_map = load_name_map()

    # Gather all employee folders
    employee_dirs = sorted(
        d for d in faces_dir.iterdir() if d.is_dir() and not d.name.startswith(".")
    )

    if not employee_dirs:
        print(f"[WARN] No employee subdirectories found in {faces_dir}")
        return

    print(f"\n{'='*60}")
    print(f"  FaceAttend — Batch Registration")
    print(f"  API:       {API_BASE_URL}")
    print(f"  Faces dir: {faces_dir}")
    print(f"  Found:     {len(employee_dirs)} employee folder(s)")
    print(f"{'='*60}\n")

    if not dry_run:
        if not check_backend():
            print(f"[ERROR] Cannot reach backend at {API_BASE_URL}")
            print("  Start the backend first: uvicorn main:app --host 0.0.0.0 --port 8000")
            sys.exit(1)

    results = []
    for emp_dir in employee_dirs:
        employee_id = emp_dir.name
        name = name_map.get(employee_id, f"Person {employee_id}")
        images = get_image_files(emp_dir)

        print(f"  [{employee_id}] {name}")
        print(f"    Images found: {len(images)}")

        if not images:
            print(f"    [SKIP] No supported images found.")
            results.append({"employee_id": employee_id, "status": "skipped", "reason": "no images"})
            continue

        for img in images:
            print(f"    - {img.name} ({img.stat().st_size // 1024} KB)")

        if dry_run:
            print(f"    [DRY RUN] Would register with {len(images)} image(s).")
            results.append({"employee_id": employee_id, "status": "dry_run"})
            continue

        try:
            resp = register_person_via_api(employee_id, name, images)
            print(f"    [OK] Registered: {resp.get('message', 'success')}")
            results.append({"employee_id": employee_id, "status": "ok", "name": name})
        except requests.HTTPError as exc:
            detail = ""
            try:
                detail = exc.response.json().get("detail", str(exc))
            except Exception:
                detail = str(exc)
            print(f"    [FAIL] {detail}")
            results.append({"employee_id": employee_id, "status": "failed", "reason": detail})
        except Exception as exc:
            print(f"    [ERROR] {exc}")
            results.append({"employee_id": employee_id, "status": "error", "reason": str(exc)})

    # Summary
    print(f"\n{'='*60}")
    print("  Registration Summary")
    print(f"{'='*60}")
    ok = sum(1 for r in results if r["status"] == "ok")
    fail = sum(1 for r in results if r["status"] in ("failed", "error"))
    skip = sum(1 for r in results if r["status"] in ("skipped", "dry_run"))
    print(f"  ✓ Registered: {ok}")
    print(f"  ✗ Failed:     {fail}")
    print(f"  - Skipped:    {skip}")
    print(f"{'='*60}\n")


def register_single(
    employee_id: str,
    name: str,
    images_dir: Path,
) -> None:
    """Register a single person from a specific directory."""
    images = get_image_files(images_dir)
    if not images:
        print(f"[ERROR] No images found in {images_dir}")
        sys.exit(1)

    if not check_backend():
        print(f"[ERROR] Cannot reach backend at {API_BASE_URL}")
        sys.exit(1)

    print(f"Registering {name} ({employee_id}) with {len(images)} image(s)...")
    try:
        resp = register_person_via_api(employee_id, name, images)
        print(f"[OK] {resp['message']}")
    except requests.HTTPError as exc:
        try:
            detail = exc.response.json().get("detail", str(exc))
        except Exception:
            detail = str(exc)
        print(f"[FAIL] {detail}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="FaceAttend — Batch face registration script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--faces-dir",
        type=Path,
        default=FACES_DIR,
        help=f"Directory containing employee subdirectories (default: {FACES_DIR})",
    )
    parser.add_argument(
        "--api-url",
        default=API_BASE_URL,
        help=f"Backend API URL (default: {API_BASE_URL})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan and report without actually registering anyone",
    )
    parser.add_argument(
        "--employee-id",
        help="Register a single person (requires --name and --images-dir)",
    )
    parser.add_argument(
        "--name",
        help="Name for single-person registration",
    )
    parser.add_argument(
        "--images-dir",
        type=Path,
        help="Images directory for single-person registration",
    )

    args = parser.parse_args()

    global API_BASE_URL
    API_BASE_URL = args.api_url

    if args.employee_id:
        if not args.name or not args.images_dir:
            parser.error("--employee-id requires --name and --images-dir")
        register_single(args.employee_id, args.name, args.images_dir)
    else:
        register_all(args.faces_dir, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
