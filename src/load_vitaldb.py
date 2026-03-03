"""
PATCH for load_vitaldb_fixed.py
================================
Problem:  Only 442 windows from 40 patients. 60/100 patients skipped
          because Solar8000/BT (temperature) was missing/corrupt.

Two changes to make in load_vitaldb_fixed.py:

CHANGE 1: Increase MAX_CASES from 100 → 500
          At ~40% yield rate, 500 requests → ~200 usable patients → ~2000+ windows
          VitalDB has 5915 patients so this is well within limits.

CHANGE 2: Make temperature optional
          Load HR + SpO2 from all patients. Load BT only if available.
          When BT is unavailable, use the dataset median (36.5°C).
          This is clinically reasonable — temperature changes very slowly
          and your IoT device has its own temp sensor anyway.
"""

from pyexpat import features

import vitaldb
import pandas as pd
import numpy as np
import os

# --- UPDATED CONFIGURATION ---
TRACKS_REQUIRED = [
    'Solar8000/HR',
    'Solar8000/PLETH_SPO2',
]
TRACK_TEMP = 'Solar8000/BT'   # Optional — loaded separately

OUTPUT_DIR = 'data/vitals_training'
OUTPUT_FILE = os.path.join(OUTPUT_DIR, 'medical_vitals.csv')

MAX_CASES = 500       # Up from 100. At 40% yield = ~200 usable patients
DURATION_MIN = 30
WINDOW_SIZE = 60
STEP_SIZE = 30

MEDIAN_TEMP_FALLBACK = 36.5   # Used when BT sensor unavailable


def validate_sensor_reading(row):
    hr, spo2 = row['HeartRate'], row['SpO2']
    if not (20 <= hr <= 250):
        return False
    if not (70 <= spo2 <= 100):
        return False
    temp = row.get('Temperature', MEDIAN_TEMP_FALLBACK)
    if not (34.0 <= temp <= 42.0):
        return False
    return True


def compute_window_features(window_df):
    features = {}
    
    # BASE FEATURES — make sure this loop is still here
    for col in ['HeartRate', 'SpO2', 'Temperature']:
        values = window_df[col].values
        features[f'{col}_mean'] = np.mean(values)
        features[f'{col}_std'] = np.std(values)
        features[f'{col}_min'] = np.min(values)
        features[f'{col}_max'] = np.max(values)
        if len(values) > 1:
            features[f'{col}_trend'] = np.polyfit(range(len(values)), values, 1)[0]
        else:
            features[f'{col}_trend'] = 0.0

    # CROSS-SIGNAL FEATURES — these come AFTER, not instead of
    hr_vals = window_df['HeartRate'].values
    spo2_vals = window_df['SpO2'].values

    corr = np.corrcoef(hr_vals, spo2_vals)[0, 1]
    features['HR_SpO2_correlation'] = 0.0 if np.isnan(corr) else corr

    mid = len(hr_vals) // 2
    features['SpO2_acceleration'] = np.mean(spo2_vals[mid:]) - np.mean(spo2_vals[:mid])
    features['HR_acceleration'] = np.mean(hr_vals[mid:]) - np.mean(hr_vals[:mid])
    features['HR_cv'] = (np.std(hr_vals) / np.mean(hr_vals)) if np.mean(hr_vals) > 0 else 0.0

    # NaN guard
    features = {k: (0.0 if (v is None or np.isnan(v)) else v) for k, v in features.items()}
    return features

def main():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    print("[INFO] Connecting to VitalDB...")

    # Find patients that have at least HR + SpO2 (temp is optional now)
    case_ids = vitaldb.find_cases(TRACKS_REQUIRED)
    print(f"[INFO] Found {len(case_ids)} patients with HR and SpO2 sensors.")

    target_cases = case_ids[:MAX_CASES]
    all_windows = []
    skipped = 0
    temp_imputed_count = 0

    print(f"[INFO] Downloading from {MAX_CASES} patients (temp is now optional)...")

    for case_id in target_cases:
        # Try loading all 3 tracks
        vals = vitaldb.load_case(case_id, TRACKS_REQUIRED + [TRACK_TEMP], interval=1)

        has_temp = True
        if vals is None:
            # Fallback: try without temperature
            vals = vitaldb.load_case(case_id, TRACKS_REQUIRED, interval=1)
            has_temp = False

        if vals is None:
            skipped += 1
            continue

        limit = 60 * DURATION_MIN
        if len(vals) > limit:
            vals = vals[:limit]

        if has_temp and vals.shape[1] == 3:
            df = pd.DataFrame(vals, columns=['HeartRate', 'SpO2', 'Temperature'])
        else:
            # Only HR + SpO2 available — impute temperature
            if vals.shape[1] == 3:
                df = pd.DataFrame(vals, columns=['HeartRate', 'SpO2', 'Temperature'])
                # Check if temp column is all NaN (sensor not connected)
                if df['Temperature'].isna().mean() > 0.5:
                    df['Temperature'] = MEDIAN_TEMP_FALLBACK
                    has_temp = False
                    temp_imputed_count += 1
            else:
                df = pd.DataFrame(vals, columns=['HeartRate', 'SpO2'])
                df['Temperature'] = MEDIAN_TEMP_FALLBACK
                has_temp = False
                temp_imputed_count += 1

        df['Subject_ID'] = case_id
        df.dropna(subset=['HeartRate', 'SpO2'], inplace=True)
        df['Temperature'] = df['Temperature'].fillna(MEDIAN_TEMP_FALLBACK)

        valid_mask = df.apply(validate_sensor_reading, axis=1)
        n_before = len(df)
        df = df[valid_mask]
        n_after = len(df)

        if n_after < WINDOW_SIZE:
            skipped += 1
            continue

        n_windows = 0
        for start in range(0, len(df) - WINDOW_SIZE + 1, STEP_SIZE):
            window = df.iloc[start:start + WINDOW_SIZE]
            feats = compute_window_features(window)
            if feats is None:
                continue  # Skip this window, don't crash
            feats['Subject_ID'] = case_id
            feats['temp_imputed'] = not has_temp
            all_windows.append(feats)
            n_windows += 1

        temp_label = "(temp imputed)" if not has_temp else ""
        print(f"   -> Patient {case_id}: {n_windows} windows {temp_label}")

    print(f"\n[INFO] Skipped {skipped} patients.")
    print(f"[INFO] Temperature imputed for {temp_imputed_count} patients.")

    if all_windows:
        master_df = pd.DataFrame(all_windows)
        # Drop the imputed flag before saving — it's metadata, not a feature
        feature_df = master_df.drop(columns=['temp_imputed'])
        feature_df.to_csv(OUTPUT_FILE, index=False)
        print("-" * 40)
        print(f"[SUCCESS] Saved to: {OUTPUT_FILE}")
        print(f"Total Windows:  {len(feature_df)}")
        print(f"Total Patients: {feature_df['Subject_ID'].nunique()}")
        print(f"\nTarget: >1000 windows from >50 patients for a usable model.")
        if len(feature_df) < 1000:
            print(f"[WARNING] Still only {len(feature_df)} windows.")
            print(f"          Consider increasing MAX_CASES further or removing temp features entirely.")
    else:
        print("[ERROR] No data extracted.")


if __name__ == "__main__":
    main()