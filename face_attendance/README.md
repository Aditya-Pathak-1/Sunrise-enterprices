# FaceAttend

A face-recognition attendance system — FastAPI backend + Flutter Android app.

---

## Project Structure

```
face_attendance/
├── backend/               # Python FastAPI + InsightFace buffalo_l
└── mobile/face_attend/    # Flutter Android app
```

---

## BACKEND SETUP

### Prerequisites
- Python 3.10+
- Internet connection (downloads buffalo_l model ~350MB on first run)

### Steps

```powershell
cd face_attendance/backend

# Create virtual environment
python -m venv venv
.\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Start server (accessible on LAN)
$env:PYTHONUTF8="1"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

API docs: http://localhost:8000/docs

---

## REGISTER PEOPLE

### Step 1 — Add face photos

```
backend/faces/
    EMP001/
        photo1.jpg
        photo2.jpg
    EMP002/
        photo1.jpg
```

### Step 2 — Add names

Edit `backend/faces/names.txt`:
```
EMP001,Arjun Sharma
EMP002,Priya Patel
```

### Step 3 — Run registration script

```powershell
# Dry run (preview without registering)
.\venv\Scripts\python register_people.py --dry-run

# Register all
.\venv\Scripts\python register_people.py
```

---

## CONFIGURE FLUTTER APP

### Find your laptop's LAN IP

```powershell
ipconfig
# Look for: IPv4 Address . . . . : 192.168.x.x
```

### Update the base URL

Edit `mobile/face_attend/lib/config.dart`:
```dart
static const String baseUrl = 'http://192.168.YOUR.IP:8000';
```

---

## FLUTTER / APK SETUP

### Prerequisites
1. **Flutter SDK** — https://docs.flutter.dev/get-started/install/windows
2. **Android Studio** — https://developer.android.com/studio
   - During install: Android SDK, Android SDK Platform-Tools, Android Emulator
   - Accept licenses: `flutter doctor --android-licenses`

### Build debug APK (for testing)

```powershell
cd face_attendance/mobile/face_attend
flutter pub get
flutter build apk --debug
```

APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### Build release APK

```powershell
flutter build apk --release
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Install on connected Android device

```powershell
# Enable USB Debugging on phone, connect via USB
flutter install
```

Or transfer APK manually via USB and install.

---

## BACKEND API REFERENCE

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /health | Health check |
| GET | /people | List registered people |
| POST | /register | Register person with face image(s) |
| POST | /recognize | Recognize a face |
| POST | /attendance/check-in | Check in via face |
| POST | /attendance/check-out | Check out via face |
| GET | /attendance/today | Today's attendance |
| GET | /attendance/history/{employee_id} | Person's history |
| DELETE | /people/{person_id} | Remove a person |

---

## FACE RECOGNITION CONFIG

Edit `backend/.env`:
```
FACE_SIMILARITY_THRESHOLD=0.35
```

- Lower → more strict (fewer false positives)
- Higher → more lenient (accepts less similar faces)
- Range: InsightFace buffalo_l cosine similarity (-1.0 to 1.0)

---

## RUN BACKEND TESTS

With the server running, in a separate terminal:

```powershell
cd face_attendance/backend
.\venv\Scripts\python test_backend.py
```

---

## TECH STACK

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.44 + Dart |
| Backend | Python 3.13 + FastAPI 0.111 |
| Database | SQLite (WAL mode) |
| Face Detection | RetinaFace (InsightFace buffalo_l) |
| Face Recognition | ArcFace R100 (InsightFace buffalo_l) |
| Inference Runtime | ONNX Runtime (CPU) |
| API Server | Uvicorn 0.30 |

---

## ATTENDANCE RULES

1. First scan (CHECK IN) → creates today's check-in record
2. Duplicate check-in on same day → rejected (409)
3. CHECK OUT requires prior check-in
4. Duplicate check-out → rejected (409)
5. Unknown faces → never mark attendance
6. Similarity threshold configurable via environment variable
