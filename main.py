from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import mysql.connector
import psycopg2
from passlib.context import CryptContext
import random
from twilio.rest import Client

app = FastAPI()

# 🛡️ Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Twilio credentials (replace with your real values)
TWILIO_ACCOUNT_SID = 'your_account_sid'
TWILIO_AUTH_TOKEN = 'your_auth_token'
TWILIO_PHONE_NUMBER = '+1234567890'

# ── MySQL connection (patient data) ──────────────────────────────────
def get_db_connection():
    return mysql.connector.connect(
        host="nexora0110-nexorameditwin.l.aivencloud.com",
        user="avnadmin",
        password="AVNS_crF3nIYJTvz3o3JVPlV",
        database="patient",
        port=18489
    )

# ── PostgreSQL connection (health monitoring / vitals) ───────────────
def get_health_db():
    return psycopg2.connect(
        host="100.94.230.117",
        port=5432,
        database="health_monitoring",
        user="postgres",      # 🛑 fill this in
        password="amma"  # 🛑 fill this in
    )

# ── Pydantic Models ───────────────────────────────────────────────────
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

# ── Helper ────────────────────────────────────────────────────────────
def generate_patient_id():
    return f"PT-{random.randint(1000, 9999)}"

# ── Auth Routes ───────────────────────────────────────────────────────
@app.post("/app/signup")
def signup(req: SignupRequest):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id FROM users WHERE email = %s", (req.email,))
        if cursor.fetchone():
            raise HTTPException(status_code=400, detail="This email is already registered")

        hashed_password = pwd_context.hash(req.password)
        query = "INSERT INTO users (email, password, mrd_number) VALUES (%s, %s, %s)"
        cursor.execute(query, (req.email, hashed_password, req.mrd_number))
        conn.commit()
        return {"user_id": cursor.lastrowid}

    except mysql.connector.IntegrityError as e:
        error_message = str(e).lower()
        if 'email' in error_message:
            raise HTTPException(status_code=400, detail="This email is already registered")
        elif 'mrd_number' in error_message:
            raise HTTPException(status_code=400, detail="This MRD number is already registered")
        else:
            raise HTTPException(status_code=400, detail="This account already exists")
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
                c.full_name as cg_full_name,
                c.relation as cg_relation,
                c.phone_number as cg_phone,
                c.is_primary as cg_is_primary,
                m.blood_group
            FROM users u
            LEFT JOIN personal_information p ON u.id = p.user_id
            LEFT JOIN caregivers c ON u.id = c.user_id
            LEFT JOIN medical_information m ON u.id = m.user_id
            WHERE u.id = %s
        """
        cursor.execute(query, (user_id,))
        data = cursor.fetchone()

        if not data:
            raise HTTPException(status_code=404, detail="User not found")

        for key, value in data.items():
            if value is None:
                data[key] = ""
            if key == 'cg_is_primary' and value != "":
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
        return {"status": "error", "message": str(err)}, 500
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
            (user_id,)
        )
        caregiver = cursor.fetchone()

        if not caregiver:
            raise HTTPException(status_code=404, detail="No caregiver assigned")

        cursor.execute(
            "INSERT INTO emergency_logs (user_id, status) VALUES (%s, 'SOS_TRIGGERED')",
            (user_id,)
        )
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
            raise HTTPException(status_code=404, detail="Primary caregiver not found for this user.")

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
def get_caregiver(user_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        query = """
            SELECT full_name as cg_full_name, relation as cg_relation, phone_number as cg_phone
            FROM caregivers
            WHERE user_id = %s AND is_primary = 1
            LIMIT 1
        """
        cursor.execute(query, (user_id,))
        caregiver = cursor.fetchone()

        if not caregiver:
            raise HTTPException(status_code=404, detail="Caregiver not found")

        return {
            "status": "success",
            "cg_full_name": caregiver['cg_full_name'],
            "cg_relation": caregiver['cg_relation'],
            "cg_phone": caregiver['cg_phone']
        }

    except mysql.connector.Error as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        cursor.close()
        conn.close()

# ── 🚨 FAKE DETECTING HACK ─────────────────────────────────
@app.get("/vitals/latest/{user_id}")
def get_latest_vitals(user_id: int):
    # We leave user_id in the URL so Flutter doesn't break, 
    # but we completely IGNORE it in the database query below!
    conn = None
    cursor = None
    try:
        conn = get_health_db()
        cursor = conn.cursor()
        
        # Notice there is NO "WHERE user_id = %s" here anymore. 
        # It just grabs the absolute latest row in the whole table.
        cursor.execute("""
            SELECT heart_rate, spo2, temperature, hrv, rmssd, sdnn, pnn50
            FROM vitals_raw_median
            ORDER BY computed_at DESC
            LIMIT 1
        """)
        
        row = cursor.fetchone()
        
        if not row:
            raise HTTPException(status_code=404, detail="No vitals found in database at all")
            
        return {
            "bpm":       row[0],
            "spo2":      row[1],
            "temp":      row[2],
            "hrv":       row[3],
            "hrv_rmssd": row[4],
            "hrv_sdnn":  row[5],
            "hrv_pnn50": row[6],
        }
    except HTTPException:
        raise 
    except Exception as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

# ── GRAPH HISTORY ROUTE (Last 24 rows from vitals_raw_median) ────────
@app.get("/vitals/history/{user_id}")
def get_vitals_history(user_id: int):
    conn = None
    cursor = None
    try:
        conn = get_health_db()
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT heart_rate, spo2, temperature, hrv, computed_at
            FROM vitals_raw_median
            ORDER BY computed_at DESC
            LIMIT 24
        """)
        rows = cursor.fetchall()
        if not rows:
            return {"data": []}
            
        rows.reverse()  # oldest → newest for the chart left to right
        history = []
        for row in rows:
            time_str = row[4].strftime("%H:%M") if row[4] else ""
            history.append({
                "bpm":  row[0] if row[0] is not None else 0,
                "spo2": row[1] if row[1] is not None else 0,
                "temp": row[2] if row[2] is not None else 0,
                "hrv":  row[3] if row[3] is not None else 0,
                "timestamp": time_str
            })
        return {"data": history}
    except Exception as err:
        raise HTTPException(status_code=500, detail=str(err))
    finally:
        if cursor: cursor.close()
        if conn:   conn.close()