<div align="center">

# 🏥 NEXORA MediTwin

### AI-Powered Real-Time Patient Monitoring Platform

*Bridging the gap between hospital care and home health — through live vitals, intelligent alerts, and seamless doctor-caregiver-patient connectivity.*

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![MySQL](https://img.shields.io/badge/MySQL-Aiven_Cloud-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://aiven.io)
[![License](https://img.shields.io/badge/License-GPL--3.0-blue?style=for-the-badge)](LICENSE)

</div>

---

## 📌 What is NEXORA?

NEXORA MediTwin is a **full-stack health-tech platform** built as a major academic project. It combines a **FastAPI web portal**, a **Flutter mobile application**, and **ML-based vitals analysis** to enable continuous, remote patient monitoring — connecting patients, their caregivers, and verified doctors in one unified system.

> **Problem it solves:** Patients discharged from hospitals often experience critical health events at home with no real-time oversight. NEXORA streams live vitals from a wearable device to doctors and caregivers via web and mobile, enabling proactive intervention.

---

## 🌟 Key Features

| Feature | Description |
|---|---|
| 📡 **Live Vitals Streaming** | Real-time heart rate, SpO₂, temperature, stress level, and fall detection from wearable hardware |
| 👨‍⚕️ **Role-Based Access** | Separate flows for verified Doctors, Caregivers, and Patients — each with tailored dashboards |
| 📱 **Mobile App (Flutter)** | Patient-facing app for vitals upload and health tracking |
| 🤖 **AI Health Assistant** | Integrated Groq LLM for symptom analysis and health Q&A |
| 🔒 **Multi-DB Architecture** | Three isolated MySQL databases — patient records, doctor profiles, and caregiver data — on Aiven Cloud |
| 📧 **Automated Alerts** | Email notifications via Gmail SMTP for critical events and account actions |
| 🏥 **Hospital Integration** | MRD number linking, verified doctor IDs, and caregiver-patient relationships |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        NEXORA Platform                          │
├──────────────┬──────────────────────────┬───────────────────────┤
│  Web Portal  │    FastAPI Backend        │   Mobile App (Flutter) │
│  (HTML/CSS/  │    (main.py)              │   Patient vitals +     │
│  Vanilla JS) │    REST API               │   registration         │
├──────────────┴──────────────────────────┴───────────────────────┤
│                      Aiven Cloud MySQL                           │
│   defaultdb (Casual/Caregiver) │ doctor DB │ patient DB          │
├─────────────────────────────────────────────────────────────────┤
│              Groq LLM  ·  Gmail SMTP  ·  Hardware Device        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗂️ Repository Structure

```
NEXORA/
├── main.py                  # FastAPI backend — all API routes (2375 lines)
├── src/                     # Core backend modules
├── static/                  # CSS, JS, images
├── index.html               # Landing page
├── patient_dashboard.html   # Real-time vitals dashboard
├── doctor.html              # Doctor portal
├── profile.html             # User profile management
├── about.html               # About NEXORA
├── [auth pages].html        # signin/signup for each role
└── requirements.txt         # Python dependencies
```

> **Other branches:** `mobile-app` (Flutter), `ml-model` (training notebooks), `dev` (active development)

---

## 🚀 Getting Started

### Prerequisites

- Python 3.11+
- pip / virtualenv
- A MySQL database (or use the included SQLite fallback for local dev)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/vaishnavmnair2005-source/NEXORA.git
cd NEXORA

# 2. Create and activate a virtual environment
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Set up environment variables
cp .env.example .env
# Edit .env and fill in your API keys (see Configuration section)

# 5. Run the server
uvicorn main:app --reload --port 8000
```

Open `http://localhost:8000` in your browser.

---

## ⚙️ Configuration

Create a `.env` file in the project root with the following variables:

```env
# LLM Provider
GROQ_API_KEY=your_groq_api_key_here

# Database (Aiven Cloud MySQL or local)
DB_HOST=your_db_host
DB_PORT=your_db_port
DB_USER=your_db_user
DB_PASS=your_db_password

# Email (Gmail SMTP)
COMPANY_EMAIL=your_email@gmail.com
EMAIL_APP_PASSWORD=your_gmail_app_password
```

> ⚠️ **Never commit `.env` to version control.** See `.gitignore`.

---

## 🔌 API Overview

The backend exposes a REST API for both the web portal and the mobile app.

### Authentication
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/register` | Register (casual / doctor / caregiver) |
| `POST` | `/login-process` | Login with role-based routing |
| `GET` | `/logout` | Clear session |
| `GET` | `/api/user-status` | Check auth + role |

### Mobile App (Patient)
| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/app/api/signup` | Patient registration from mobile |
| `POST` | `/app/api/login` | Patient login |
| `POST` | `/api/upload_vitals` | Stream live vitals from wearable |
| `GET` | `/api/get_latest` | Fetch most recent vitals reading |

### Profile & Data
| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/profile-data` | Fetch user profile (all roles) |
| `POST` | `/api/update-profile` | Update profile details |
| `DELETE` | `/api/doctor/delete-account` | Permanently delete doctor account |
| `DELETE` | `/api/caregiver/delete-account` | Permanently delete caregiver account |

---

## 👥 User Roles

**Patient** — Registers via mobile app. Assigned a unique `PT-XXXX` ID and linked to a hardware wearable device. Uploads live vitals.

**Caregiver** — Registers via web portal using a patient's `PT-XXXX` ID and their phone number. Up to 3 caregivers (1 primary from app, 2 secondary from web) per patient. Receives real-time vitals alerts.

**Doctor** — Verified using a pre-issued `NEX-DOC-XXX` ID and medical license number. Can monitor assigned patients and access health records.

---

## 🤖 ML Model

The ML component (see `models` branch) includes:
- Vitals anomaly detection using trained classifiers on physiological data
- Stress level prediction from HRV and SpO₂ patterns
- Fall detection model trained on accelerometer data

> Model training notebooks and datasets are documented in the `models` branch README.

---

## 📱 Mobile App

The Flutter mobile app (see `mobile-app` branch) provides:
- Patient onboarding and `PT-XXXX` ID registration
- Live vitals display from the wearable via Bluetooth/WiFi
- Push notifications for health alerts
- Caregiver registration flow

---

## 🛡️ Security Notes

- All passwords are hashed using **bcrypt** before storage
- Doctor registrations are verified against a pre-approved ID list
- Three isolated databases enforce strict data separation between roles
- Sessions managed via Starlette's `SessionMiddleware` with a 7-day TTL
- SSL required for all database connections

---

## 🧪 Tech Stack

| Layer | Technology |
|---|---|
| Backend | Python 3.11, FastAPI, SQLAlchemy, Uvicorn |
| Frontend | HTML5, CSS3, Vanilla JavaScript |
| Mobile | Flutter (Dart) |
| Database | MySQL on Aiven Cloud (3 isolated DBs) |
| AI/LLM | Groq API (LLaMA-3 based) |
| Auth | bcrypt, Starlette SessionMiddleware |
| Email | Gmail SMTP |
| ML | scikit-learn, pandas, numpy |

---

## 👨‍💻 Team

Built by a team of 4 engineering students as a Major Project.

| Member | Role |
|---|---|
| **Vaishnav M Nair** | UI/UX & Frontend Backend & Full-Stack |
| *P V Vaishali* | Mobile App (Flutter) |
| *Sreejith T S* | ML Model & Data |
| *P R Shivani* | Tester |

---

## 📄 License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

*Built with ❤️ at Amrita School of arts and science, Kochi · Major Project 2024–25*

</div>
