import pandas as pd
import numpy as np
import joblib
import os

# --- CONFIGURATION ---
STRESS_MODEL_PATH = os.path.join('models', 'stress_model.pkl')
ANOMALY_MODEL_PATH = os.path.join('models', 'anomaly_model.pkl')
ANOMALY_SCALER_PATH = os.path.join('models', 'anomaly_scaler.pkl')

class NexoraHealthMonitor:
    def __init__(self):
        print("[INIT] Loading Nexora AI Engines...")
        
        # 1. Load Stress Brain
        if os.path.exists(STRESS_MODEL_PATH):
            self.stress_model = joblib.load(STRESS_MODEL_PATH)
            print("   -> Stress Model Loaded (HR + HRV + Motion)")
        else:
            print(f"[ERROR] Stress model missing at {STRESS_MODEL_PATH}")
            self.stress_model = None

        # 2. Load Medical Anomaly Brain
        if os.path.exists(ANOMALY_MODEL_PATH):
            self.anomaly_model = joblib.load(ANOMALY_MODEL_PATH)
            self.scaler = joblib.load(ANOMALY_SCALER_PATH)
            print("   -> Anomaly Model Loaded (HR + SpO2 + Temp)")
        else:
            print(f"[ERROR] Anomaly model missing at {ANOMALY_MODEL_PATH}")
            self.anomaly_model = None

    def analyze_patient(self, hr, spo2, temp, rmssd, sdnn, motion):
        """
        The Main Function: Takes sensor data -> Returns Health Status
        """
        results = {
            "stress_status": "UNKNOWN",
            "medical_status": "UNKNOWN",
            "alert_level": "GREEN"
        }

        # --- A. CHECK FOR STRESS (Mental) ---
        if self.stress_model:
            # Prepare Input: ['HR', 'RMSSD', 'SDNN', 'Motion']
            stress_input = pd.DataFrame([[hr, rmssd, sdnn, motion]], 
                                      columns=['HR', 'RMSSD', 'SDNN', 'Motion'])
            
            # Predict (1=Baseline, 2=Stress)
            stress_pred = self.stress_model.predict(stress_input)[0]
            
            if stress_pred == 2:
                results["stress_status"] = "HIGH STRESS"
                results["alert_level"] = "YELLOW"  # Warning
            else:
                results["stress_status"] = "RELAXED"

        # --- B. CHECK FOR MEDICAL ANOMALIES (Physical) ---
        if self.anomaly_model:
            # Prepare Input: ['HeartRate', 'SpO2', 'Temperature']
            # Note: Must scale this data first!
            anomaly_input = pd.DataFrame([[hr, spo2, temp]], 
                                       columns=['HeartRate', 'SpO2', 'Temperature'])
            scaled_input = self.scaler.transform(anomaly_input)
            
            # Predict (1=Normal, -1=Anomaly)
            anomaly_pred = self.anomaly_model.predict(scaled_input)[0]
            
            if anomaly_pred == -1:
                results["medical_status"] = "CRITICAL ANOMALY"
                results["alert_level"] = "RED"    # Emergency!
            else:
                results["medical_status"] = "NORMAL"

        return results

# --- TEST SCENARIO ---
if __name__ == "__main__":
    ai_engine = NexoraHealthMonitor()
    
    print("\n--- TEST 1: Healthy Relaxed Patient ---")
    # HR: 70, SpO2: 98, Temp: 36.6, HRV: 50ms, Motion: Low
    status = ai_engine.analyze_patient(hr=70, spo2=98, temp=36.6, rmssd=50, sdnn=60, motion=0.1)
    print(status)

    print("\n--- TEST 2: High Stress (Mental) ---")
    # HR: 100, SpO2: 98, Temp: 36.6, HRV: 15ms (Low!), Motion: Low
    status = ai_engine.analyze_patient(hr=100, spo2=98, temp=36.6, rmssd=15, sdnn=20, motion=0.1)
    print(status)

    print("\n--- TEST 3: Medical Emergency (Fever + Hypoxia) ---")
    # HR: 110, SpO2: 88 (Danger), Temp: 39.0 (Fever), HRV: 40, Motion: Still
    status = ai_engine.analyze_patient(hr=110, spo2=88, temp=39.0, rmssd=40, sdnn=40, motion=0.1)
    print(status)