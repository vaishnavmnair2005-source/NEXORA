# =============================================================================
#  NEXORA MediTwin Platform — Backend Server
#  FastAPI application powering the web portal and mobile app integration
# =============================================================================

from fastapi import FastAPI, Form, Request, BackgroundTasks, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse, FileResponse, RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from datetime import datetime, date, timedelta
import secrets
from pathlib import Path
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from sqlalchemy import Column, Integer, String, ForeignKey, create_engine, Text, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker
import uvicorn
import smtplib
import bcrypt
import re


# =============================================================================
#  APP INITIALIZATION
# =============================================================================

app = FastAPI(title="NEXORA MediTwin Server")

app.add_middleware(
    SessionMiddleware,
    secret_key="nexora-secret-key",
    max_age=604800,  # 7 days
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/static", StaticFiles(directory="static"), name="static")


# =============================================================================
#  GLOBAL CONFIG
# =============================================================================

# In-memory buffer for live vitals streamed from the mobile app
cloud_storage: list[dict] = []


COMPANY_EMAIL  = "teamnexora2026@gmail.com"
EMAIL_PASSWORD = "ciib bqvt oxgu zjvo"

# Authorised doctors: ID → full name (must match exactly on signup)
AUTHORIZED_DOCTORS = {
    "NEX-DOC-001": "Dr. Hisham Ahamed",
    "NEX-DOC-002": "Dr. Anand Kumar A",
    "NEX-DOC-003": "Dr. M.G.K Pillai",
    "NEX-DOC-004": "Dr. Praveen Sreekumar",
    "NEX-DOC-005": "Dr. Sarath Menon",
    "NEX-DOC-006": "Dr. Geetha Philips",
    "NEX-DOC-007": "Dr. G. Vijayaraghavan",
    "NEX-DOC-008": "Dr. Suresh Chandran",
    "NEX-DOC-009": "Dr. P.K. Sasidharan",
    "NEX-DOC-010": "Dr. Suresh Davis",
    "NEX-DOC-011": "Dr. Gigy Varkey",
    "NEX-DOC-012": "Dr. Santhichandra Pai",
    "NEX-DOC-013": "Dr. Sagy V. Kuruttukulam",
    "NEX-DOC-014": "Dr. Dilip Panicker",
    "NEX-DOC-015": "Dr. P.V. Louis",
    "NEX-DOC-016": "Dr. Asokan Nambiar",
    "NEX-DOC-017": "Dr. James Jose",
    "NEX-DOC-018": "Dr. Feroz Aziz",
    "NEX-DOC-019": "Dr. Anand Kumar",
    "NEX-DOC-020": "Dr. Murali Krishna",
    "NEX-DOC-021": "Dr. Sudhayakumar",
    "NEX-DOC-022": "Dr. Jo Joseph",
    "NEX-DOC-023": "Dr. Mathew Abraham",
    "NEX-DOC-024": "Dr. Babu Francis",
    "NEX-DOC-025": "Dr. Ajith Kumar V",
    "NEX-DOC-026": "Dr. Sanjeev V. Thomas",
    "NEX-DOC-027": "Dr. R.Lakshmi",
    "NEX-DOC-028": "Dr. Thomas Paul",
    "NEX-DOC-029": "Dr. Dinesh Nayak",
    "NEX-DOC-030": "Dr. Ravi K",
}


# =============================================================================
#  EMAIL UTILITY
# =============================================================================

def send_email(subject: str, body: str, recipient: str) -> bool:
    """Send a plain-text email via Gmail SMTP. Returns True on success."""
    try:
        msg = MIMEMultipart()
        msg["From"]    = COMPANY_EMAIL
        msg["To"]      = recipient
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))

        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(COMPANY_EMAIL, EMAIL_PASSWORD)
        server.send_message(msg)
        server.quit()
        return True
    except Exception:
        return False


# =============================================================================
#  DATABASE CONFIGURATION — THREE SEPARATE DATABASES
#
#  defaultdb  → Casual / caregiver web users  (CasualUser)
#  doctor     → Verified doctors              (DoctorUser)
#  patient    → Mobile-app patients + caregivers linked to them
#               (PatientUser, PersonalInformation, MedicalInformation, Caregiver)
#
#  The Caregiver table lives inside the `patient` database so that a
#  caregiver can be joined directly to the PatientUser who registered
#  through the NEXORA mobile app.
# =============================================================================

_DB_HOST = "nexora0110-nexorameditwin.l.aivencloud.com"
_DB_PORT = "18489"
_DB_USER = "avnadmin"
_DB_PASS = "AVNS_crF3nIYJTvz3o3JVPlV"
_SSL     = {"ssl": {"ssl_mode": "REQUIRED"}}

def _make_engine(db_name: str):
    url = f"mysql+pymysql://{_DB_USER}:{_DB_PASS}@{_DB_HOST}:{_DB_PORT}/{db_name}"
    return create_engine(url, pool_pre_ping=True, connect_args=_SSL)

engine_casual  = _make_engine("defaultdb")
engine_doctor  = _make_engine("doctor")
engine_patient = _make_engine("patient")    # users/caregivers live in the patient database

SessionCasual  = sessionmaker(autocommit=False, autoflush=False, bind=engine_casual)
SessionDoctor  = sessionmaker(autocommit=False, autoflush=False, bind=engine_doctor)
SessionPatient = sessionmaker(autocommit=False, autoflush=False, bind=engine_patient)

BaseCasual  = declarative_base()
BaseDoctor  = declarative_base()
BasePatient = declarative_base()


# =============================================================================
#  MODELS
# =============================================================================

class CasualUser(BaseCasual):
    """Web-portal users: casual visitors and caregivers."""
    __tablename__ = "casual_user"
    id              = Column(Integer, primary_key=True, index=True)
    full_name       = Column(String(100))
    email           = Column(String(255), unique=True, index=True)
    phone_number    = Column(String(20))
    hashed_password = Column(String(255))


class DoctorUser(BaseDoctor):
    """Verified medical professionals."""
    __tablename__ = "doctors"
    id                  = Column(Integer, primary_key=True, index=True)
    full_name           = Column(String(100))
    email               = Column(String(255), unique=True, index=True)
    phone_number        = Column(String(20))
    doctor_id           = Column(String(50))
    license_number      = Column(String(50))
    specialization      = Column(String(100))
    hospital_affiliation= Column(String(100))
    password            = Column(String(255))


class PatientUser(BasePatient):
    """
    Patients who registered via the NEXORA mobile app.
    Exact match of the actual `users` table columns:
      id, mrd_number, email, password, patient_id, device_id
    WARNING: full_name and device_no do NOT exist in the real DB — never add them here.
    """
    __tablename__ = "users"
    id         = Column(Integer, primary_key=True, index=True)
    mrd_number = Column(String(50))               # Hospital MRD / ward number
    email      = Column(String(255), unique=True, index=True)
    password   = Column(String(255))
    patient_id = Column(String(50), index=True)   # Public-facing ID e.g. "PT-8949"
    device_id  = Column(String(50))               # Hardware device identifier


class PersonalInformation(BasePatient):
    """Extended personal details for a patient (filled via mobile app)."""
    __tablename__ = "personal_information"
    id             = Column(Integer, primary_key=True, index=True)
    user_id        = Column(Integer, ForeignKey("users.id"))
    first_name     = Column(String(100))
    last_name      = Column(String(100))
    dob            = Column(String(20))
    gender         = Column(String(20))
    address        = Column(String(255))
    contact_number = Column(String(50))


class MedicalInformation(BasePatient):
    """Medical profile for a patient (filled via mobile app)."""
    __tablename__ = "medical_information"
    id               = Column(Integer, primary_key=True, index=True)
    user_id          = Column(Integer, ForeignKey("users.id"))
    hospital         = Column(String(255))
    doctor           = Column(String(255))
    blood_group      = Column(String(10))
    medical_history  = Column(Text)
    current_status   = Column(String(255))


class Caregiver(BasePatient):
    """
    Links a web-portal user (CasualUser) to a mobile-app patient (PatientUser).
    Lives in the `patient` database for direct joins with PatientUser records.
    """
    __tablename__ = "caregivers"
    id           = Column(Integer, primary_key=True, index=True)
    user_id      = Column(Integer, index=True)   # → CasualUser.id (defaultdb)
    full_name    = Column(String(100))
    relation     = Column(String(50))
    phone_number = Column(String(20))
    patient_id   = Column(String(50))            # e.g. "PT-1234" → PatientUser.id
    is_primary   = Column(Integer)               # 1 = primary caregiver, 0 = secondary


# =============================================================================
#  DATABASE SESSION DEPENDENCY
# =============================================================================

class DBSessions:
    """Opens one session per database and closes all on exit."""
    def __init__(self):
        self.casual  = SessionCasual()
        self.doctor  = SessionDoctor()
        self.patient = SessionPatient()

    def close(self):
        self.casual.close()
        self.doctor.close()
        self.patient.close()


def get_dbs():
    sessions = DBSessions()
    try:
        yield sessions
    finally:
        sessions.close()


# =============================================================================
#  UTILITY HELPERS
# =============================================================================

def check_auth(request: Request) -> bool:
    return bool(request.session.get("user_id"))


def get_patient_by_pt_id(db_session, patient_id_str: str):
    """
    Look up a PatientUser by their string patient_id (e.g. 'PT-8949').
    Queries the `patient_id` column in the `users` table — the correct way
    to resolve a PT-XXXX identifier to a patient record.
    Returns None if not found.
    """
    if not patient_id_str:
        return None
    return db_session.query(PatientUser).filter(
        PatientUser.patient_id == patient_id_str.strip().upper()
    ).first()


def resolve_patient_numeric_id(patient_id_str: str):
    """
    DEPRECATED — kept only for any remaining legacy call sites.
    Prefer get_patient_by_pt_id() which does a real DB lookup.
    This naive string-parse is unreliable (PT-8949 → 8949 ≠ users.id=9).
    """
    if not patient_id_str:
        return None
    clean = patient_id_str.upper().replace("PT-", "").replace("PT", "").strip()
    return int(clean) if clean.isdigit() else None


def build_full_name(personal, patient) -> str:
    """Return the best available full name for a patient.
    Name comes from personal_information (first_name + last_name).
    The users table has no full_name column.
    """
    if personal and (personal.first_name or personal.last_name):
        return f"{personal.first_name or ''} {personal.last_name or ''}".strip()
    # Fall back to email prefix if no personal info yet
    if patient and patient.email:
        return patient.email.split("@")[0]
    return ""


def calc_age(dob_str: str) -> int | str | None:
    """Calculate age from a YYYY-MM-DD string. Returns None on failure."""
    if not dob_str:
        return None
    try:
        dob     = datetime.strptime(dob_str, "%Y-%m-%d").date()
        today   = date.today()
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    except Exception:
        return dob_str  # Fallback: return the raw string


# =============================================================================
#  WEB AUTHENTICATION — REGISTER
# =============================================================================

@app.post("/api/register")
def register_user(
    request:     Request,
    background_tasks: BackgroundTasks,
    role:        str = Form("casual"),
    full_name:   str = Form(None),
    phone:       str = Form(None),
    email:       str = Form(None),
    password:    str = Form(None),
    # Doctor-specific
    doctor_id:   str = Form(None),
    license_number: str = Form(None),
    specialization: str = Form(None),
    hospital:    str = Form(None),
    # Caregiver-specific
    relation:    str = Form(None),
    patient_id:  str = Form(None),
    is_primary:  str = Form(None),
    next:        str = Form(None),
    dbs: DBSessions = Depends(get_dbs),
):
    err_base = "/casual-signup" if role == "casual" else "/signup"

    # ── Shared validation ────────────────────────────────────────────────────
    if not full_name or not re.match(r"^[A-Za-z\s\.]+$", full_name):
        return RedirectResponse(f"{err_base}?error=invalid_name", 303)
    if phone and not re.match(r"^\d{10}$", phone):
        return RedirectResponse(f"{err_base}?error=invalid_phone", 303)

    # Email + password required for non-caregiver roles
    if role != "caregiver":
        if not email or not email.endswith("@gmail.com"):
            return RedirectResponse(f"{err_base}?error=invalid_email", 303)
        if not password:
            return RedirectResponse(f"{err_base}?error=missing_fields", 303)

    hashed_pw = ""
    if password:
        hashed_pw = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

    user_id    = None
    final_email = email

    # ── DOCTOR ──────────────────────────────────────────────────────────────
    if role == "doctor":
        if not full_name.strip().lower().startswith("dr."):
            full_name = f"Dr. {full_name.strip()}"

        if doctor_id not in AUTHORIZED_DOCTORS:
            return RedirectResponse("/signup?error=invalid_doctor_id", 303)

        if AUTHORIZED_DOCTORS[doctor_id].lower() != full_name.lower().strip():
            return RedirectResponse("/signup?error=name_mismatch", 303)

        if dbs.doctor.query(DoctorUser).filter(DoctorUser.email == email).first():
            return RedirectResponse("/signup?error=email_exists", 303)

        if dbs.doctor.query(DoctorUser).filter(DoctorUser.doctor_id == doctor_id).first():
            return RedirectResponse("/signup?error=doctor_already_registered", 303)

        if license_number and dbs.doctor.query(DoctorUser).filter(DoctorUser.license_number == license_number).first():
            return RedirectResponse("/signup?error=license_exists", 303)

        new_doctor = DoctorUser(
            full_name           = full_name,
            email               = email,
            phone_number        = phone,
            password            = hashed_pw,
            doctor_id           = doctor_id,
            license_number      = license_number,
            specialization      = specialization,
            hospital_affiliation= hospital,
        )
        dbs.doctor.add(new_doctor)
        dbs.doctor.commit()
        dbs.doctor.refresh(new_doctor)
        user_id = new_doctor.id

    # ── CAREGIVER ────────────────────────────────────────────────────────────
    elif role == "caregiver":
        if not relation or not relation.strip():
            return RedirectResponse("/signup?error=invalid_relation", 303)

        # Strict format check — must be PT-<digits> exactly (e.g. PT-8949)
        if not patient_id:
            return RedirectResponse("/signup?error=invalid_patient_id", 303)

        patient_id = patient_id.strip().upper()  # normalise → "PT-8949"

        if not re.match(r"^PT-\d+$", patient_id):
            return RedirectResponse("/signup?error=invalid_patient_id", 303)

        # ── Confirm the patient exists using the patient_id column (e.g. "PT-8949") ──
        # IMPORTANT: We look up users.patient_id = "PT-8949", NOT users.id = 8949.
        # The numeric part of PT-8949 is NOT the same as the row primary key.
        try:
            mobile_patient = get_patient_by_pt_id(dbs.patient, patient_id)
        except Exception:
            return RedirectResponse("/signup?error=patient_not_found", 303)

        if not mobile_patient:
            return RedirectResponse("/signup?error=patient_not_found", 303)

        # Prevent duplicate caregiver–patient links for the same phone number
        try:
            existing_link = dbs.patient.query(Caregiver).filter(
                Caregiver.phone_number == phone,
                Caregiver.patient_id   == patient_id,
            ).first()
        except Exception:
            existing_link = None

        if existing_link:
            return RedirectResponse("/signup?error=patient_already_linked", 303)

        # ── Enforce caregiver limits ──────────────────────────────────────────
        # Rule: 1 caregiver is registered from the mobile app (is_primary=1).
        # The website allows a maximum of 2 additional (secondary) caregivers.
        # Hard cap: 3 total caregivers per patient across all sources.
        try:
            total_cg_count = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id == patient_id
            ).count()
            web_cg_count = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id == patient_id,
                Caregiver.is_primary == 0,
            ).count()
        except Exception:
            total_cg_count = 0
            web_cg_count   = 0

        if total_cg_count >= 3:
            return RedirectResponse("/signup?error=caregiver_limit_reached", 303)
        if web_cg_count >= 2:
            return RedirectResponse("/signup?error=web_caregiver_limit_reached", 303)

        # Find or create the CasualUser record for this caregiver
        existing_user = dbs.casual.query(CasualUser).filter(
            CasualUser.phone_number == phone
        ).first()

        if existing_user:
            user_id     = existing_user.id
            final_email = existing_user.email
        else:
            final_email = f"{phone}@nexora.temp"
            temp_user   = dbs.casual.query(CasualUser).filter(
                CasualUser.email == final_email
            ).first()
            if temp_user:
                user_id = temp_user.id
            else:
                new_casual = CasualUser(
                    full_name       = full_name,
                    email           = final_email,
                    phone_number    = phone,
                    hashed_password = "",
                )
                dbs.casual.add(new_casual)
                dbs.casual.commit()
                dbs.casual.refresh(new_casual)
                user_id = new_casual.id

        new_cg = Caregiver(
            user_id      = user_id,
            full_name    = full_name,
            relation     = relation.strip(),
            phone_number = phone,
            patient_id   = patient_id,
            is_primary   = 1 if is_primary == "yes" else 0,
        )
        # Disable FK checks temporarily (caregiver.user_id references a different DB)
        dbs.patient.execute(text("SET FOREIGN_KEY_CHECKS=0"))
        dbs.patient.add(new_cg)
        dbs.patient.commit()
        dbs.patient.execute(text("SET FOREIGN_KEY_CHECKS=1"))

        request.session["user"]            = final_email
        request.session["role"]            = "caregiver"
        request.session["user_id"]         = user_id
        request.session["patient_id_ref"]  = patient_id
        return RedirectResponse("/", 303)

    # ── CASUAL ───────────────────────────────────────────────────────────────
    else:
        if dbs.casual.query(CasualUser).filter(CasualUser.email == email).first():
            return RedirectResponse("/casual-signup?error=email_exists", 303)

        new_casual = CasualUser(
            full_name       = full_name,
            email           = email,
            phone_number    = phone,
            hashed_password = hashed_pw,
        )
        dbs.casual.add(new_casual)
        dbs.casual.commit()
        dbs.casual.refresh(new_casual)
        user_id = new_casual.id

    # Set session and send welcome email (doctor + casual)
    request.session["user"]    = final_email
    request.session["role"]    = role
    request.session["user_id"] = user_id

    if final_email and not final_email.endswith("@nexora.temp"):
        background_tasks.add_task(
            send_email, "Welcome to NEXORA MediTwin",
            "Your account is active. Sign in at nexora.health.", final_email
        )

    destination = next if (next and next.startswith("/")) else "/"
    return RedirectResponse(destination, 303)


# =============================================================================
#  WEB AUTHENTICATION — LOGIN
# =============================================================================

@app.post("/login-process")
def process_login(
    request:   Request,
    role:      str = Form("casual"),
    email:     str = Form(None),
    password:  str = Form(None),
    doctor_id: str = Form(None),
    patient_id: str = Form(None),
    phone:     str = Form(None),
    next:      str = Form(None),
    dbs: DBSessions = Depends(get_dbs),
):
    # ── CAREGIVER ────────────────────────────────────────────────────────────
    if role == "caregiver":
        if not patient_id or not phone:
            return RedirectResponse("/login?error=missing_fields", 303)

        pid_clean   = patient_id.strip().upper()
        phone_clean = phone.strip()

        # Look up caregiver by BOTH patient_id AND phone — the only credentials they have
        cg = dbs.patient.query(Caregiver).filter(
            Caregiver.patient_id   == pid_clean,
            Caregiver.phone_number == phone_clean,
        ).first()

        if not cg:
            # Targeted error: phone found but wrong patient_id
            if dbs.patient.query(Caregiver).filter(
                Caregiver.phone_number == phone_clean
            ).first():
                return RedirectResponse("/login?error=patient_id_mismatch", 303)
            return RedirectResponse("/login?error=caregiver_not_found", 303)

        # ── Find or create a CasualUser purely for the session ───────────────
        # RULES:
        #  - Web-signup caregivers: cg.user_id = casual_user.id (FK disabled at insert)
        #  - App caregivers (primary): cg.user_id = patient.users.id (different DB!)
        #  - We NEVER update caregivers.user_id here to avoid FK constraint (1452)
        casual_user = None

        # Step 1 — try cg.user_id directly in defaultdb (works for web-signup caregivers)
        if cg.user_id:
            casual_user = dbs.casual.query(CasualUser).filter(
                CasualUser.id == cg.user_id
            ).first()

        # Step 2 — try by phone number (catches app-registered caregivers)
        if not casual_user:
            casual_user = dbs.casual.query(CasualUser).filter(
                CasualUser.phone_number == phone_clean
            ).first()

        # Step 3 — nothing found: create a session-only CasualUser in defaultdb
        #          DO NOT touch caregivers table at all
        if not casual_user:
            temp_email  = f"{phone_clean}@nexora.temp"
            casual_user = dbs.casual.query(CasualUser).filter(
                CasualUser.email == temp_email
            ).first()
            if not casual_user:
                casual_user = CasualUser(
                    full_name       = cg.full_name or "Caregiver",
                    email           = temp_email,
                    phone_number    = phone_clean,
                    hashed_password = "",
                )
                dbs.casual.add(casual_user)
                dbs.casual.commit()
                dbs.casual.refresh(casual_user)

        # Store caregiver_db_id so every subsequent API can find the right row
        # with a single PK lookup — no more ambiguous user_id joins
        request.session["user"]            = casual_user.email
        request.session["role"]            = "caregiver"
        request.session["user_id"]         = casual_user.id
        request.session["patient_id_ref"]  = cg.patient_id
        request.session["caregiver_db_id"] = cg.id   # PK of caregivers row
        return RedirectResponse("/", 303)

    # ── DOCTOR ──────────────────────────────────────────────────────────────
    elif role == "doctor":
        if not email or not password:
            return RedirectResponse("/login?error=missing_fields", 303)

        user = dbs.doctor.query(DoctorUser).filter(DoctorUser.email == email).first()

        if not user or not bcrypt.checkpw(password.encode(), user.password.encode()):
            return RedirectResponse("/login?error=invalid_credentials", 303)

        if doctor_id and user.doctor_id != doctor_id:
            return RedirectResponse("/login?error=doctor_id_mismatch", 303)

        request.session["user"]    = user.email
        request.session["role"]    = "doctor"
        request.session["user_id"] = user.id

    # ── CASUAL ───────────────────────────────────────────────────────────────
    else:
        if not email or not password:
            return RedirectResponse("/casual-signin?error=missing_fields", 303)

        user = dbs.casual.query(CasualUser).filter(CasualUser.email == email).first()

        if not user:
            return RedirectResponse("/casual-signin?error=user_not_found", 303)
        if not user.hashed_password or not bcrypt.checkpw(
            password.encode(), user.hashed_password.encode()
        ):
            return RedirectResponse("/casual-signin?error=invalid_credentials", 303)

        request.session["user"]    = user.email
        request.session["role"]    = "casual"
        request.session["user_id"] = user.id

    destination = next if (next and next.startswith("/")) else "/"
    return RedirectResponse(destination, 303)


@app.get("/logout")
def logout(request: Request):
    request.session.clear()
    return RedirectResponse("/", 302)


@app.delete("/api/doctor/delete-account")
def delete_doctor_account(request: Request, dbs: DBSessions = Depends(get_dbs)):
    """
    Permanently deletes the doctor's account.
    Removes the DoctorUser row from the doctor DB and clears the session.
    The doctor must sign up again to regain access.
    """
    user_id = request.session.get("user_id")
    role    = request.session.get("role")

    if not user_id or role != "doctor":
        raise HTTPException(401, "Not authenticated as doctor")

    doctor = dbs.doctor.query(DoctorUser).filter(DoctorUser.id == user_id).first()
    if not doctor:
        raise HTTPException(404, "Doctor account not found")

    dbs.doctor.delete(doctor)
    dbs.doctor.commit()

    request.session.clear()
    return {"status": "deleted"}



@app.delete("/api/caregiver/delete-account")
def delete_caregiver_account(request: Request, dbs: DBSessions = Depends(get_dbs)):
    """
    Permanently deletes the caregiver's account.
    Removes the Caregiver row from the patient DB and the CasualUser row from the casual DB,
    then clears the session so the user cannot log in again until they sign up.
    """
    user_id     = request.session.get("user_id")
    role        = request.session.get("role")
    cg_db_id    = request.session.get("caregiver_db_id")
    pid_ref     = request.session.get("patient_id_ref")

    if not user_id or role != "caregiver":
        raise HTTPException(401, "Not authenticated as caregiver")

    # 1. Remove Caregiver row(s) from patient DB
    cg = None
    if cg_db_id:
        cg = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
    if not cg and pid_ref:
        casual = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
        if casual:
            cg = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id   == pid_ref,
                Caregiver.phone_number == (casual.phone_number or ""),
            ).first()
    if cg:
        dbs.patient.delete(cg)
        dbs.patient.commit()

    # 2. Remove CasualUser row from casual DB
    casual_user = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
    if casual_user:
        dbs.casual.delete(casual_user)
        dbs.casual.commit()

    # 3. Clear session — user can no longer log in until they sign up again
    request.session.clear()

    return {"status": "deleted"}


# =============================================================================
#  USER STATUS API
# =============================================================================

@app.get("/api/user-status")
def user_status(request: Request, dbs: DBSessions = Depends(get_dbs)):
    user_id = request.session.get("user_id")
    role    = request.session.get("role")

    if not user_id or not role:
        return {"logged_in": False, "role": None}

    user = None
    if role == "doctor":
        user = dbs.doctor.query(DoctorUser).filter(DoctorUser.id == user_id).first()
    elif role == "casual":
        user = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
    elif role == "caregiver":
        user = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
        if not user:
            # Session user not in defaultdb — treat as logged out
            request.session.clear()
            return {"logged_in": False, "role": None}
        # Verify the caregiver record still exists using the PK stored at signin
        cg_db_id = request.session.get("caregiver_db_id")
        pid_ref  = request.session.get("patient_id_ref")
        cg = None
        if cg_db_id:
            cg = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
        if not cg and pid_ref:
            cg = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id == pid_ref,
                Caregiver.phone_number == (user.phone_number or "")
            ).first()
        if not cg:
            request.session.clear()
            return {"logged_in": False, "role": None}

    if not user:
        request.session.clear()
        return {"logged_in": False, "role": None}

    data = {"logged_in": True, "role": role}
    if role == "caregiver":
        # Return full caregiver profile so home page can render it in one request
        pid_ref  = request.session.get("patient_id_ref")
        cg_db_id = request.session.get("caregiver_db_id")
        cg_row   = None
        if cg_db_id:
            cg_row = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
        if not cg_row and pid_ref:
            cg_user = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
            if cg_user:
                cg_row = dbs.patient.query(Caregiver).filter(
                    Caregiver.patient_id   == pid_ref,
                    Caregiver.phone_number == (cg_user.phone_number or ""),
                ).first()
        data["patient_id"] = pid_ref
        if cg_row:
            data["caregiver"] = {
                "name":       cg_row.full_name    or "",
                "phone":      cg_row.phone_number or "",
                "relation":   cg_row.relation     or "",
                "patient_id": cg_row.patient_id   or "",
                "is_primary": cg_row.is_primary == 1,
            }
    return data


# =============================================================================
#  MOBILE APP API — Patient sign-up / login + live vitals upload
#
#  These endpoints are called exclusively by the NEXORA mobile app.
#  PatientUser records created here are the same records that Caregivers
#  link to via the `patient_id` field in the Caregiver table.
# =============================================================================

class AppSignupRequest(BaseModel):
    email:     str
    password:  str
    mrd_number: str = ""   # Hospital MRD number
    patient_id: str = ""   # e.g. "PT-8949"
    device_id:  str = ""   # Hardware device ID


@app.post("/app/api/signup")
def app_signup(payload: AppSignupRequest, dbs: DBSessions = Depends(get_dbs)):
    if dbs.patient.query(PatientUser).filter(PatientUser.email == payload.email).first():
        return {"status": "error", "message": "Email already registered"}

    hashed = bcrypt.hashpw(payload.password.encode(), bcrypt.gensalt()).decode()
    new_patient = PatientUser(
        email      = payload.email,
        password   = hashed,
        mrd_number = payload.mrd_number or "",
        patient_id = payload.patient_id.strip().upper() if payload.patient_id else "",
        device_id  = payload.device_id or "",
    )
    dbs.patient.add(new_patient)
    dbs.patient.commit()
    return {"status": "success", "user_id": new_patient.id}


class AppLoginRequest(BaseModel):
    email:    str
    password: str


@app.post("/app/api/login")
def app_login(payload: AppLoginRequest, dbs: DBSessions = Depends(get_dbs)):
    patient = dbs.patient.query(PatientUser).filter(PatientUser.email == payload.email).first()
    if patient and bcrypt.checkpw(payload.password.encode(), patient.password.encode()):
        return {"status": "success", "user_id": patient.id}
    return {"status": "error", "message": "Invalid credentials"}


class VitalsPayload(BaseModel):
    """Vitals streamed in real-time from the patient's wearable via the mobile app."""
    heart_rate:    int
    sp02:          int
    temperature:   float
    stress_level:  str
    fall_detected: bool
    device_id:     str = ""


@app.post("/api/upload_vitals")
async def upload_vitals(payload: VitalsPayload):
    cloud_storage.append({**payload.dict(), "timestamp": datetime.now().strftime("%H:%M:%S")})
    return {"status": "success"}


@app.get("/api/get_latest")
async def get_latest_vitals(device_id: str = Query(None)):
    """Return the most recent vitals reading, optionally filtered by device_id."""
    if device_id:
        for item in reversed(cloud_storage):
            if item.get("device_id") == device_id:
                return {"status": "success", "data": item}
        return {"status": "no_data"}

    if cloud_storage:
        return {"status": "success", "data": cloud_storage[-1]}
    return {"status": "no_data"}


# =============================================================================
#  PROFILE API
# =============================================================================

@app.get("/api/profile-data")
async def get_profile(request: Request, dbs: DBSessions = Depends(get_dbs)):
    if not check_auth(request):
        raise HTTPException(status_code=401)

    uid  = request.session["user_id"]
    role = request.session["role"]

    if role == "doctor":
        u = dbs.doctor.query(DoctorUser).filter(DoctorUser.id == uid).first()
        if not u:
            raise HTTPException(404)
        return {
            "role": "doctor", "full_name": u.full_name, "email": u.email,
            "phone": u.phone_number, "doctor_id": u.doctor_id,
            "license_number": u.license_number, "specialization": u.specialization,
            "hospital": u.hospital_affiliation,
        }

    elif role == "caregiver":
        pid_ref   = request.session.get("patient_id_ref")
        cg_db_id  = request.session.get("caregiver_db_id")
        casual    = dbs.casual.query(CasualUser).filter(CasualUser.id == uid).first()

        # Look up caregiver by PK first (fastest & unambiguous)
        cg = None
        if cg_db_id:
            cg = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
        # Fallback: match by patient_id + phone
        if not cg and pid_ref and casual:
            cg = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id   == pid_ref,
                Caregiver.phone_number == (casual.phone_number or ""),
            ).first()

        if not casual or not cg:
            raise HTTPException(404)
        return {
            "role":       "caregiver",
            "full_name":  cg.full_name    or "",
            "email":      casual.email    or "",
            "phone":      cg.phone_number or "",
            "relation":   cg.relation     or "",
            "patient_id": cg.patient_id   or "",
            "is_primary": "yes" if cg.is_primary == 1 else "no",
        }

    else:
        u = dbs.casual.query(CasualUser).filter(CasualUser.id == uid).first()
        if not u:
            raise HTTPException(404)
        return {
            "role": "casual", "full_name": u.full_name,
            "email": u.email, "phone": u.phone_number,
        }


@app.post("/api/update-profile")
async def update_profile(
    request:        Request,
    full_name:      str = Form(...),
    phone:          str = Form(...),
    new_password:   str = Form(None),
    doctor_id:      str = Form(None),
    license_number: str = Form(None),
    specialization: str = Form(None),
    hospital:       str = Form(None),
    relation:       str = Form(None),
    is_primary:     str = Form(None),
    dbs: DBSessions = Depends(get_dbs),
):
    if not check_auth(request):
        raise HTTPException(401)

    uid  = request.session["user_id"]
    role = request.session["role"]

    hashed_pw = None
    if new_password:
        if len(new_password) < 8:
            raise HTTPException(422, "Password too short")
        hashed_pw = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

    if role == "casual":
        user = dbs.casual.query(CasualUser).filter(CasualUser.id == uid).first()
        if user:
            user.full_name    = full_name.strip()
            user.phone_number = phone
            if hashed_pw:
                user.hashed_password = hashed_pw
            dbs.casual.commit()

    elif role == "doctor":
        user = dbs.doctor.query(DoctorUser).filter(DoctorUser.id == uid).first()
        if user:
            if not full_name.strip().lower().startswith("dr."):
                full_name = f"Dr. {full_name.strip()}"
            if doctor_id:
                if doctor_id not in AUTHORIZED_DOCTORS:
                    raise HTTPException(422)
                if AUTHORIZED_DOCTORS[doctor_id].lower() != full_name.lower():
                    raise HTTPException(422)
                user.doctor_id = doctor_id
            user.full_name           = full_name.strip()
            user.phone_number        = phone
            if hashed_pw:
                user.password = hashed_pw
            if license_number:
                user.license_number = license_number
            if specialization:
                user.specialization = specialization
            if hospital:
                user.hospital_affiliation = hospital
            dbs.doctor.commit()

    elif role == "caregiver":
        casual = dbs.casual.query(CasualUser).filter(CasualUser.id == uid).first()
        if casual:
            casual.full_name    = full_name.strip()
            casual.phone_number = phone
            if hashed_pw:
                casual.hashed_password = hashed_pw
            dbs.casual.commit()

        pid_ref = request.session.get("patient_id_ref")
        cg = dbs.patient.query(Caregiver).filter(
            Caregiver.user_id    == uid,
            Caregiver.patient_id == pid_ref,
        ).first()
        if cg:
            cg.full_name    = full_name.strip()
            cg.phone_number = phone
            if relation:
                cg.relation = relation.strip()
            if is_primary is not None:
                cg.is_primary = 1 if is_primary == "yes" else 0
            dbs.patient.commit()

    return {"status": "success"}


# =============================================================================
#  CAREGIVER DATA APIs
# =============================================================================

@app.get("/api/caregiver/patients")
def get_caregiver_patients(request: Request, dbs: DBSessions = Depends(get_dbs)):
    """Return all patients linked to the logged-in caregiver."""
    user_id   = request.session.get("user_id")
    cg_db_id  = request.session.get("caregiver_db_id")
    pid_ref   = request.session.get("patient_id_ref")

    if not user_id:
        raise HTTPException(401)

    # Primary lookup: caregiver PK stored in session at login — unambiguous
    # regardless of which DB user_id refers to (app vs web caregivers differ).
    cg_records = []
    if cg_db_id:
        cg = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
        if cg:
            cg_records = [cg]

    # Fallback: match by patient_id + phone via CasualUser
    if not cg_records and pid_ref:
        casual = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
        if casual and casual.phone_number:
            cg_records = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id   == pid_ref,
                Caregiver.phone_number == casual.phone_number,
            ).all()

    # Last resort: user_id join (works for web-signup caregivers where
    # Caregiver.user_id == CasualUser.id was explicitly set at registration)
    if not cg_records:
        cg_records = dbs.patient.query(Caregiver).filter(
            Caregiver.user_id == user_id
        ).all()

    if not cg_records:
        return []

    results = []
    for cg in cg_records:
        # Look up patient by their patient_id string (e.g. "PT-8949"), not by numeric parse
        patient = get_patient_by_pt_id(dbs.patient, cg.patient_id)
        if not patient:
            continue

        personal = dbs.patient.query(PersonalInformation).filter(
            PersonalInformation.user_id == patient.id
        ).first()

        results.append({
            "id":         patient.id,
            "patient_id": patient.patient_id or cg.patient_id,  # always live from users table
            "full_name":  build_full_name(personal, patient),
            "device_id":  patient.device_id or "",
            "device_no":  "",
            "gender":     personal.gender if personal else "N/A",
            "dob":        personal.dob    if personal else "N/A",
            "relation":   cg.relation     or "",
            "is_primary": cg.is_primary == 1,
            "status":     "Online",
        })

    return results


@app.get("/api/patient-data")
async def get_patient_data(
    request:    Request,
    patient_id: str = Query(None),
    dbs: DBSessions = Depends(get_dbs),
):
    """
    Return full patient profile for the logged-in caregiver.
    Accepts an optional ?patient_id=PT-XXXX query param to select a specific patient.
    """
    if not check_auth(request):
        raise HTTPException(401)
    if request.session.get("role") != "caregiver":
        raise HTTPException(403, "Caregiver access only")

    caregiver_user_id = request.session.get("user_id")
    pid_ref = patient_id or request.session.get("patient_id_ref")

    # Resolve caregiver record
    cg = None
    if pid_ref:
        cg = dbs.patient.query(Caregiver).filter(
            Caregiver.user_id    == caregiver_user_id,
            Caregiver.patient_id == pid_ref,
        ).first()
    if not cg:
        cg = dbs.patient.query(Caregiver).filter(
            Caregiver.user_id == caregiver_user_id
        ).first()
    if not cg:
        raise HTTPException(404, "No caregiver record found")

    # Look up patient by their patient_id string — do NOT parse it numerically
    patient = get_patient_by_pt_id(dbs.patient, cg.patient_id)
    if not patient:
        raise HTTPException(404, f"Patient '{cg.patient_id}' not found in users table")

    personal = dbs.patient.query(PersonalInformation).filter(
        PersonalInformation.user_id == patient.id
    ).first()
    medical = dbs.patient.query(MedicalInformation).filter(
        MedicalInformation.user_id == patient.id
    ).first()

    return {
        "patient_id":       cg.patient_id,
        "numeric_id":       patient.id,
        "full_name":        build_full_name(personal, patient),
        "email":            patient.email          or "",
        "device_id":        patient.device_id      or "",
        "device_no":        "",  # device_no column does not exist in users table
        "mrd_number":       patient.mrd_number     or "",
        "first_name":       (personal.first_name    or "") if personal else "",
        "last_name":        (personal.last_name     or "") if personal else "",
        "dob":              (personal.dob           or "") if personal else "",
        "age":              calc_age(personal.dob)         if personal else None,
        "gender":           (personal.gender        or "") if personal else "",
        "address":          (personal.address       or "") if personal else "",
        "contact_number":   (personal.contact_number or "") if personal else "",
        "hospital":         (medical.hospital        or "") if medical  else "",
        "doctor":           (medical.doctor          or "") if medical  else "",
        "blood_group":      (medical.blood_group     or "") if medical  else "",
        "emergency_number": "",  # not in DB
        "medical_history":  (medical.medical_history or "") if medical  else "",
        "current_status":   (medical.current_status  or "") if medical  else "",
        "caregiver_name":     cg.full_name  or "",
        "caregiver_relation": cg.relation   or "",
        "is_primary":         cg.is_primary == 1,
    }


@app.get("/api/caregiver/patient-data")
async def get_caregiver_patient_data(
    request:    Request,
    patient_id: str = Query(None),
    dbs: DBSessions = Depends(get_dbs),
):
    """
    Return profile + latest vitals for a caregiver's linked patient.
    Vitals are sourced from cloud_storage (populated by the mobile app).
    """
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(401)

    pid_ref   = patient_id or request.session.get("patient_id_ref")
    cg_db_id  = request.session.get("caregiver_db_id")

    # Use PK lookup first — unambiguous regardless of which DB user_id refers to
    cg = None
    if cg_db_id:
        cg = dbs.patient.query(Caregiver).filter(Caregiver.id == cg_db_id).first()
    if not cg and pid_ref:
        # Fallback: match by patient_id + phone via CasualUser
        casual = dbs.casual.query(CasualUser).filter(CasualUser.id == user_id).first()
        if casual:
            cg = dbs.patient.query(Caregiver).filter(
                Caregiver.patient_id   == pid_ref,
                Caregiver.phone_number == (casual.phone_number or ""),
            ).first()
    if not cg:
        raise HTTPException(404, "No caregiver record")

    # Look up patient by their patient_id string — do NOT parse it numerically
    patient = get_patient_by_pt_id(dbs.patient, cg.patient_id)
    if not patient:
        raise HTTPException(404, "Linked patient not found")

    personal = dbs.patient.query(PersonalInformation).filter(
        PersonalInformation.user_id == patient.id
    ).first()
    medical = dbs.patient.query(MedicalInformation).filter(
        MedicalInformation.user_id == patient.id
    ).first()

    # Find the latest vitals from the mobile app for this patient's device
    device_id    = patient.device_id or ""
    latest_vitals = None
    if device_id:
        for item in reversed(cloud_storage):
            if item.get("device_id") == device_id:
                latest_vitals = item
                break
    if not latest_vitals and cloud_storage:
        latest_vitals = cloud_storage[-1]  # Fallback to most recent upload

    # Helper: safe string value from a possibly-None field
    def sv(obj, field, default=""):
        if obj is None:
            return default
        return getattr(obj, field, None) or default

    dob_val = sv(personal, "dob")
    return {
        "profile": {
            "patient_id":     patient.patient_id or cg.patient_id,  # live from users table
            "full_name":      build_full_name(personal, patient),
            "email":          patient.email       or "",
            "device_id":      patient.device_id   or "",
            "mrd_number":     patient.mrd_number  or "",
            "gender":         sv(personal, "gender"),
            "age":            calc_age(personal.dob) if personal and personal.dob else None,
            "dob":            str(dob_val) if dob_val else "",
            "address":        sv(personal, "address"),
            "contact_number": sv(personal, "contact_number"),
            "blood_group":    sv(medical,  "blood_group"),
            "hospital":       sv(medical,  "hospital"),
            "doctor":         sv(medical,  "doctor"),
            "medical_history":sv(medical,  "medical_history"),
            "condition":      sv(medical,  "current_status"),
        },
        "caregiver": {
            "name":       cg.full_name  or "",
            "relation":   cg.relation   or "",
            "is_primary": cg.is_primary == 1,
        },
        "vitals": latest_vitals or {
            "heart_rate":    "--",
            "sp02":          "--",
            "temperature":   "--",
            "stress_level":  "--",
            "fall_detected": False,
            "timestamp":     None,
            "status":        "Offline",
        },
    }


# =============================================================================
#  FORGOT PASSWORD / CREDENTIAL RECOVERY  (OTP-based — no links)
#
#  Doctor flow:
#    1. POST /api/forgot-password/doctor   → generates 6-digit OTP, emails it
#    2. POST /api/verify-otp/doctor        → validates OTP, returns a short-lived
#                                            session token (stored server-side)
#    3. POST /api/reset-password           → verifies session token, sets new pw
#
#  Caregiver flow:
#    POST /api/forgot-credentials/caregiver → looks up Patient ID by phone number
# =============================================================================

# _reset_tokens stores two kinds of entries, keyed by a random string:
#   OTP entry:     { type:"otp",     email, otp, expires_at }
#   Session entry: { type:"session", email, expires_at }
_reset_tokens: dict[str, dict] = {}


def _purge_expired():
    """Remove expired entries to prevent unbounded growth."""
    now = datetime.utcnow()
    expired = [k for k, v in _reset_tokens.items() if now > v["expires_at"]]
    for k in expired:
        del _reset_tokens[k]


@app.post("/api/forgot-password/doctor")
async def forgot_password_doctor(
    background_tasks: BackgroundTasks,
    email: str = Form(...),
    dbs: DBSessions = Depends(get_dbs),
):
    """
    Step 1 — Generate a 6-digit OTP and email it to the doctor.
    Always returns success to prevent email enumeration.
    """
    _purge_expired()
    user = dbs.doctor.query(DoctorUser).filter(
        DoctorUser.email == email.strip().lower()
    ).first()

    if user:
        otp = str(secrets.randbelow(900000) + 100000)   # 100000–999999
        otp_key = secrets.token_urlsafe(16)
        _reset_tokens[otp_key] = {
            "type":       "otp",
            "email":      user.email,
            "otp":        otp,
            "expires_at": datetime.utcnow() + timedelta(minutes=10),
        }
        body = (
            f"Hello {user.full_name},\n\n"
            f"Your NEXORA MediTwin password reset code is:\n\n"
            f"    {otp}\n\n"
            f"This code is valid for 10 minutes. Do not share it with anyone.\n\n"
            f"If you did not request this, please ignore this email.\n\n"
            f"— NEXORA MediTwin Team"
        )
        background_tasks.add_task(
            send_email, "NEXORA — Your Password Reset Code", body, user.email
        )
        # Return otp_key so the frontend can reference this pending OTP without
        # exposing the OTP itself or the user's email in the browser.
        return {"status": "success", "otp_key": otp_key}

    # Account not found — still return success shape (no enumeration)
    return {"status": "success", "otp_key": None}


@app.post("/api/verify-otp/doctor")
async def verify_otp_doctor(
    otp_key:  str = Form(...),
    otp_code: str = Form(...),
):
    """
    Step 2 — Validate the OTP the user typed.
    On success: delete the OTP entry and create a short-lived reset-session token.
    Returns that session token to the frontend so Step 3 can use it.
    """
    _purge_expired()
    entry = _reset_tokens.get(otp_key)

    if not entry or entry.get("type") != "otp":
        raise HTTPException(400, detail="otp_expired")
    if datetime.utcnow() > entry["expires_at"]:
        del _reset_tokens[otp_key]
        raise HTTPException(400, detail="otp_expired")
    if entry["otp"] != otp_code.strip():
        raise HTTPException(400, detail="otp_invalid")

    # OTP correct — swap for a reset-session token (5 min)
    del _reset_tokens[otp_key]
    session_key = secrets.token_urlsafe(32)
    _reset_tokens[session_key] = {
        "type":       "session",
        "email":      entry["email"],
        "expires_at": datetime.utcnow() + timedelta(minutes=5),
    }
    return {"status": "success", "session_token": session_key}


@app.post("/api/reset-password")
async def reset_password(
    session_token: str = Form(...),
    new_password:  str = Form(...),
    dbs: DBSessions = Depends(get_dbs),
):
    """
    Step 3 — Set the new password using the session token from Step 2.
    Token is consumed (single-use).
    """
    _purge_expired()
    entry = _reset_tokens.get(session_token)

    if not entry or entry.get("type") != "session":
        raise HTTPException(400, detail="Session expired. Please start over.")
    if datetime.utcnow() > entry["expires_at"]:
        del _reset_tokens[session_token]
        raise HTTPException(400, detail="Session expired. Please start over.")
    if len(new_password) < 8:
        raise HTTPException(422, detail="Password must be at least 8 characters.")

    email = entry["email"]
    user  = dbs.doctor.query(DoctorUser).filter(DoctorUser.email == email).first()
    if not user:
        raise HTTPException(404, detail="Account not found.")

    user.password = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
    dbs.doctor.commit()

    del _reset_tokens[session_token]   # single-use
    return {"status": "success"}


@app.post("/api/forgot-credentials/caregiver")
async def forgot_credentials_caregiver(
    phone: str = Form(...),
    dbs: DBSessions = Depends(get_dbs),
):
    """
    Credential recovery for caregivers who forgot their Patient ID.
    Looks up the caregiver record by phone number and returns the linked Patient ID.
    """
    phone_clean = phone.strip()
    cg = dbs.patient.query(Caregiver).filter(
        Caregiver.phone_number == phone_clean
    ).first()

    if not cg:
        raise HTTPException(status_code=404, detail="no_account_found")

    return {
        "status":     "found",
        "patient_id": cg.patient_id,
        "full_name":  cg.full_name or "",
    }




@app.post("/api/contact")
async def contact(
    background_tasks: BackgroundTasks,
    name:    str = Form(...),
    email:   str = Form(...),
    message: str = Form(...),
):
    background_tasks.add_task(send_email, f"Contact: {name}", message, COMPANY_EMAIL)
    return {"status": "success"}


@app.post("/api/local-inquiry")
async def local_inquiry(
    background_tasks: BackgroundTasks,
    name:    str = Form(...),
    region:  str = Form(...),
    message: str = Form(...),
):
    background_tasks.add_task(send_email, f"Local inquiry: {region}", message, COMPANY_EMAIL)
    return {"status": "success"}


# =============================================================================
#  REGULATORY DOWNLOAD
# =============================================================================

@app.get("/api/regulatory/download")
async def regulatory_download():
    return RedirectResponse("/static/NEXORA MediTwin Documentation.pdf", 303)


# =============================================================================
#  HTML PAGE ROUTES
# =============================================================================

def _html(filename: str) -> str:
    return (Path(__file__).parent / filename).read_text(encoding="utf-8")


# ── Protected portal pages ────────────────────────────────────────────────────

@app.get("/doctor-dashboard", response_class=HTMLResponse)
async def serve_doctor_dashboard(request: Request):
    if not check_auth(request):
        return RedirectResponse("/login", 303)
    if request.session.get("role") != "doctor":
        return HTMLResponse("<h1>403 — Access Denied</h1>", 403)
    return _html("doctor.html")


@app.get("/patient-dashboard", response_class=HTMLResponse)
async def serve_patient_dashboard(request: Request):
    if not check_auth(request):
        return RedirectResponse("/login", 303)
    if request.session.get("role") != "caregiver":
        return RedirectResponse("/", 303)
    return _html("patient_dashboard.html")


@app.get("/profile", response_class=HTMLResponse)
async def serve_profile(request: Request):
    if not check_auth(request):
        return RedirectResponse("/login", 303)
    return _html("profile.html")


@app.get("/contact", response_class=HTMLResponse)
async def serve_contact(request: Request):
    if not check_auth(request):
        return RedirectResponse("/casual-signin?next=/contact", 303)
    return _html("contact.html")


@app.get("/enquire-locally", response_class=HTMLResponse)
async def serve_local(request: Request):
    if not check_auth(request):
        return RedirectResponse("/casual-signin?next=/enquire-locally", 303)
    return _html("local.html")


# ── Authentication pages ─────────────────────────────────────────────────────

@app.get("/login",        response_class=HTMLResponse)
@app.get("/signin",       response_class=HTMLResponse)
async def serve_signin():
    return _html("signin.html")

@app.get("/signup",       response_class=HTMLResponse)
async def serve_signup():
    return _html("signup.html")

@app.get("/casual-signup",response_class=HTMLResponse)
async def serve_casual_signup():
    return _html("casual-signup.html")

@app.get("/casual-signin",response_class=HTMLResponse)
async def serve_casual_signin():
    return _html("casual-signin.html")


# ── Public static pages ──────────────────────────────────────────────────────

_PUBLIC_PAGES = [
    "index", "about", "help", "privacy", "terms",
    "security", "success", "local-success", "regulatory",
    "quality", "incident",
]

for _page in _PUBLIC_PAGES:
    _route = "/" if _page == "index" else f"/{_page}"
    _file  = f"{_page}.html"

    def _make_handler(f=_file):
        async def handler():
            return HTMLResponse(_html(f))
        return handler

    app.get(_route, response_class=HTMLResponse)(_make_handler())


# ── Patient data form stubs (POST redirects handled elsewhere) ────────────────

@app.post("/api/personal-info")
def save_personal_info(request: Request, dbs: DBSessions = Depends(get_dbs)):
    return RedirectResponse("/", 303)


@app.post("/api/medical-info")
def save_medical_info(request: Request, dbs: DBSessions = Depends(get_dbs)):
    return RedirectResponse("/", 303)


# =============================================================================
#  ENTRY POINT
# =============================================================================

if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)