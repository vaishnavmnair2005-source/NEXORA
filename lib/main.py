from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import mysql.connector
from passlib.context import CryptContext
import random
from twilio.rest import Client
from datetime import datetime

app = FastAPI()

# ─── SECURITY ────────────────────────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# ─── TWILIO ──────────────────────────────────────────────────────────────────
TWILIO_ACCOUNT_SID = 'your_account_sid'
TWILIO_AUTH_TOKEN = 'your_auth_token'
TWILIO_PHONE_NUMBER = '+1234567890'

# ─── DB ──────────────────────────────────────────────────────────────────────
def get_db_connection():
    return mysql.connector.connect(
        host="nexora0110-nexorameditwin.l.aivencloud.com",
        user="avnadmin",
        password="AVNS_crF3nIYJTvz3o3JVPlV",
        database="patient",
        port=18489
    )

# ─── MODELS ──────────────────────────────────────────────────────────────────
class SignupRequest(BaseModel):
    email: str
    password: str
    mrd_number: str

class PersonalInfo(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    gender: str
    dob: str
    contact_number: str
    address: str

class PairDevice(BaseModel):
    patient_id: str
    device_id: str

class MedicalCaregiverInfo(BaseModel):
    user_id: int
    hospital: str
    doctor: str
    blood_group: str
    current_status: str
    medical_history: str
    cg_full_name: str
    cg_relation: str
    cg_phone: str
    cg_is_primary: bool

class NotificationPrefs(BaseModel):
    user_id: int
    sos_alerts: bool = True
    vital_alerts: bool = True
    daily_summary: bool = False

class UpdatePersonalInfo(BaseModel):
    user_id: int
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    contact_number: Optional[str] = None
    address: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    user_id: int
    current_password: str
    new_password: str

class VitalsRecord(BaseModel):
    user_id: int
    bpm: Optional[int] = 0
    hrv: Optional[int] = 0
    spo2: Optional[int] = 0
    temp: Optional[float] = 0.0
    gsr: Optional[str] = "Normal"
    fall_status: Optional[str] = "Safe"

# ─── UTILS ───────────────────────────────────────────────────────────────────
def generate_patient_id():
    return f"PT-{random.randint(1000, 9999)}"


# ════════════════════════════════════════════════════════════════════════════
# EXISTING ENDPOINTS (Unchanged)
# ════════════════════════════════════════════════════════════════════════════

@app.post("/app/signup")
def signup(req: SignupRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id FROM users WHERE email = %s", (req.email,))
        if cursor.fetchone():
            return {"status": "exists", "message": "Email already registered"}

        hashed_password = pwd_context.hash(req.password)
        query = "INSERT INTO users (email, password, mrd_number) VALUES (%s, %s, %s)"
        cursor.execute(query, (req.email, hashed_password, req.mrd_number))
        conn.commit()
        return {"user_id": cursor.lastrowid}
    finally:
        cursor.close()
        conn.close()


@app.post("/app/personal-info")
def save_personal_info(data: PersonalInfo):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        new_patient_id = generate_patient_id()
        cursor.execute("UPDATE users SET patient_id = %s WHERE id = %s", (new_patient_id, data.user_id))
        query = """
        INSERT INTO personal_information
        (user_id, first_name, last_name, gender, dob, contact_number, address)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (data.user_id, data.first_name, data.last_name,
                               data.gender, data.dob, data.contact_number, data.address))
        conn.commit()
        return {"message": "Personal info saved", "patient_id": new_patient_id}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.post("/app/pair-device")
def pair_device(data: PairDevice):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM users WHERE patient_id = %s", (data.patient_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Patient ID not found")
        cursor.execute("UPDATE users SET device_id = %s WHERE patient_id = %s",
                       (data.device_id, data.patient_id))
        conn.commit()
        return {"message": "Device linked successfully"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.post("/app/medical-caregiver")
def save_medical_caregiver(data: MedicalCaregiverInfo):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT patient_id FROM users WHERE id = %s", (data.user_id,))
        result = cursor.fetchone()
        if not result or not result[0]:
            raise HTTPException(status_code=400, detail="Patient ID not found for this user.")
        patient_id = result[0]

        med_query = """
        INSERT INTO medical_information
        (user_id, hospital, doctor, blood_group, current_status, medical_history)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(med_query, (data.user_id, data.hospital, data.doctor,
                                   data.blood_group, data.current_status, data.medical_history))

        cg_query = """
        INSERT INTO caregivers
        (user_id, patient_id, full_name, relation, phone_number, is_primary)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(cg_query, (data.user_id, patient_id, data.cg_full_name,
                                  data.cg_relation, data.cg_phone, data.cg_is_primary))
        conn.commit()
        return {"message": "Medical and Caregiver info saved successfully"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.get("/app/profile/{user_id}")
def get_full_profile(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        query = """
            SELECT
                u.email, u.mrd_number, u.patient_id, u.device_id,
                p.first_name, p.last_name, p.gender, p.dob, p.contact_number, p.address,
                m.hospital, m.doctor, m.blood_group, m.current_status, m.medical_history,
                c.full_name as cg_full_name,
                c.relation as cg_relation,
                c.phone_number as cg_phone,
                c.is_primary as cg_is_primary
            FROM users u
            LEFT JOIN personal_information p ON u.id = p.user_id
            LEFT JOIN medical_information m ON u.id = m.user_id
            LEFT JOIN caregivers c ON u.id = c.user_id
            WHERE u.id = %s
        """
        cursor.execute(query, (user_id,))
        data = cursor.fetchone()
        if not data:
            raise HTTPException(status_code=404, detail="User not found")
        for key, value in data.items():
            if value is None:
                data[key] = ""
            if key == 'cg_is_primary':
                data[key] = bool(value)
        return data
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.delete("/app/delete-account/{user_id}")
def delete_account(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM caregivers WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM medical_information WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM personal_information WHERE user_id = %s", (user_id,))
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()
        return {"status": "success", "message": "Account wiped"}
    except mysql.connector.Error as err:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.post("/app/trigger-sos/{user_id}")
def trigger_sos(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT phone_number as cg_phone, full_name as cg_full_name FROM caregivers WHERE user_id = %s AND is_primary = 1",
            (user_id,))
        caregiver = cursor.fetchone()
        if not caregiver:
            raise HTTPException(status_code=404, detail="No caregiver assigned")
        cursor.execute(
            "INSERT INTO emergency_logs (user_id, status) VALUES (%s, 'SOS_TRIGGERED')", (user_id,))
        conn.commit()
        print(f"🚨 ALERT: Sending SOS to {caregiver['cg_full_name']} at {caregiver['cg_phone']}")
        return {"status": "success", "message": "SOS Alert Sent to Caregiver"}
    finally:
        cursor.close()
        conn.close()


@app.post("/app/vital-alert-call/{user_id}")
async def trigger_vital_alert_call(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT c.phone_number, p.first_name
            FROM caregivers c
            JOIN users u ON c.user_id = u.id
            LEFT JOIN personal_information p ON u.id = p.user_id
            WHERE c.user_id = %s AND c.is_primary = 1
            LIMIT 1
        """, (user_id,))
        result = cursor.fetchone()
        if not result or not result['phone_number']:
            raise HTTPException(status_code=404, detail="Primary caregiver not found.")

        caregiver_phone = result['phone_number']
        patient_name = result.get('first_name', 'the patient')

        twiml_message = f"""
        <Response>
            <Say voice="Polly.Joanna">
                Emergency Alert from Nexora Meditwin.
                The patient, {patient_name}, is experiencing abnormal vitals.
                Please check on them immediately.
            </Say>
        </Response>
        """
        client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        call = client.calls.create(
            twiml=twiml_message,
            to=caregiver_phone,
            from_=TWILIO_PHONE_NUMBER
        )
        return {"status": "success", "call_sid": call.sid}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        cursor.close()
        conn.close()


@app.get("/app/get-caregiver/{user_id}")
def get_caregiver_details(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT full_name as cg_full_name, relation as cg_relation, phone_number as cg_phone
            FROM caregivers
            WHERE user_id = %s
            LIMIT 1
        """, (user_id,))
        result = cursor.fetchone()
        if result:
            return {"status": "success", **result}
        return {"status": "error", "message": "No caregiver found"}
    except Exception as e:
        return {"status": "error", "detail": str(e)}
    finally:
        cursor.close()
        conn.close()


# ════════════════════════════════════════════════════════════════════════════
# NEW ENDPOINTS — Settings, Notifications, Vitals History, PDF Data
# ════════════════════════════════════════════════════════════════════════════

# ── Settings: Update Personal Info ──────────────────────────────────────────
@app.put("/app/update-personal-info")
def update_personal_info(data: UpdatePersonalInfo):
    """Update editable personal info fields from the Settings screen."""
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        fields = []
        values = []
        if data.first_name is not None:
            fields.append("first_name = %s")
            values.append(data.first_name)
        if data.last_name is not None:
            fields.append("last_name = %s")
            values.append(data.last_name)
        if data.contact_number is not None:
            fields.append("contact_number = %s")
            values.append(data.contact_number)
        if data.address is not None:
            fields.append("address = %s")
            values.append(data.address)

        if not fields:
            return {"status": "skipped", "message": "No fields to update"}

        values.append(data.user_id)
        query = f"UPDATE personal_information SET {', '.join(fields)} WHERE user_id = %s"
        cursor.execute(query, values)
        conn.commit()
        return {"status": "success", "message": "Profile updated"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


# ── Settings: Change Password ────────────────────────────────────────────────
@app.post("/app/change-password")
def change_password(data: ChangePasswordRequest):
    """Verify current password and set a new hashed password."""
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT password FROM users WHERE id = %s", (data.user_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        if not pwd_context.verify(data.current_password, row['password']):
            raise HTTPException(status_code=401, detail="Current password is incorrect")

        new_hash = pwd_context.hash(data.new_password)
        cursor.execute("UPDATE users SET password = %s WHERE id = %s",
                       (new_hash, data.user_id))
        conn.commit()
        return {"status": "success", "message": "Password changed successfully"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


# ── Notification Preferences ─────────────────────────────────────────────────
@app.post("/app/notification-prefs")
def save_notification_prefs(data: NotificationPrefs):
    """
    Save per-user notification preferences.
    Requires a `notification_preferences` table:
      CREATE TABLE notification_preferences (
        user_id INT PRIMARY KEY,
        sos_alerts BOOLEAN DEFAULT TRUE,
        vital_alerts BOOLEAN DEFAULT TRUE,
        daily_summary BOOLEAN DEFAULT FALSE,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      );
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
        INSERT INTO notification_preferences (user_id, sos_alerts, vital_alerts, daily_summary)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            sos_alerts = VALUES(sos_alerts),
            vital_alerts = VALUES(vital_alerts),
            daily_summary = VALUES(daily_summary),
            updated_at = CURRENT_TIMESTAMP
        """
        cursor.execute(query, (data.user_id, data.sos_alerts,
                               data.vital_alerts, data.daily_summary))
        conn.commit()
        return {"status": "success", "message": "Preferences saved"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.get("/app/notification-prefs/{user_id}")
def get_notification_prefs(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT sos_alerts, vital_alerts, daily_summary FROM notification_preferences WHERE user_id = %s",
            (user_id,))
        row = cursor.fetchone()
        if row:
            return {"status": "success", **row}
        # Return defaults if not set yet
        return {
            "status": "default",
            "sos_alerts": True,
            "vital_alerts": True,
            "daily_summary": False,
        }
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


# ── Vitals History (for PDF export + Health Trends) ──────────────────────────
@app.post("/app/save-vitals")
def save_vitals(data: VitalsRecord):
    """
    Persist a vitals snapshot. Requires a `vitals_history` table:
      CREATE TABLE vitals_history (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        bpm INT,
        hrv INT,
        spo2 INT,
        temp FLOAT,
        gsr VARCHAR(20),
        fall_status VARCHAR(20),
        recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
        INSERT INTO vitals_history (user_id, bpm, hrv, spo2, temp, gsr, fall_status)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (
            data.user_id, data.bpm, data.hrv, data.spo2,
            data.temp, data.gsr, data.fall_status
        ))
        conn.commit()
        return {"status": "success", "message": "Vitals saved"}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.get("/app/vitals-history/{user_id}")
def get_vitals_history(user_id: int, limit: int = 50):
    """
    Returns the last `limit` vitals records for the user.
    Used by HealthTrendsScreen and PDF export.
    """
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT bpm, hrv, spo2, temp, gsr, fall_status,
                   DATE_FORMAT(recorded_at, '%Y-%m-%d %H:%i') as timestamp
            FROM vitals_history
            WHERE user_id = %s
            ORDER BY recorded_at DESC
            LIMIT %s
        """, (user_id, limit))
        rows = cursor.fetchall()
        # Reverse to ascending order for charts
        rows.reverse()
        return {"status": "success", "records": rows, "count": len(rows)}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


@app.get("/app/vitals-summary/{user_id}")
def get_vitals_summary(user_id: int):
    """
    Returns 24-hour averages for all vitals — used by HealthTrendsScreen.
    """
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT
                ROUND(AVG(bpm), 1)  as avg_bpm,
                ROUND(MIN(bpm), 1)  as min_bpm,
                ROUND(MAX(bpm), 1)  as max_bpm,
                ROUND(AVG(hrv), 1)  as avg_hrv,
                ROUND(AVG(spo2), 1) as avg_spo2,
                ROUND(MIN(spo2), 1) as min_spo2,
                ROUND(AVG(temp), 2) as avg_temp,
                COUNT(*)            as total_readings
            FROM vitals_history
            WHERE user_id = %s
              AND recorded_at >= NOW() - INTERVAL 24 HOUR
        """, (user_id,))
        summary = cursor.fetchone()
        return {"status": "success", "summary": summary}
    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()


# ── Health Status Check ───────────────────────────────────────────────────────
@app.get("/app/health")
def health_check():
    """Simple ping to test connectivity (used by offline mode)."""
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}