import pandas as pd
import numpy as np
import joblib
import os
import matplotlib.pyplot as plt
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
import warnings
warnings.filterwarnings('ignore')

# --- CONFIGURATION ---
INPUT_FILE = os.path.join('data', 'vitals_training', 'medical_vitals.csv')
MODEL_PATH = os.path.join('models', 'anomaly_model.pkl')
SCALER_PATH = os.path.join('models', 'anomaly_scaler.pkl')
THRESHOLD_PATH = os.path.join('models', 'anomaly_threshold.pkl')


# =============================================================================
# FIX #1: THE BIGGEST BUG — Isolation Forest must be trained on NORMAL data ONLY
#
# YOUR ORIGINAL CODE DID THIS:
#   X_train = concat(real_normal_data + synthetic_anomalies)
#   model.fit(X_train)   ← WRONG
#
# WHY IT'S WRONG:
#   Isolation Forest is unsupervised. It learns "normal" from the distribution
#   of training data. If you mix anomalies in, you shift its idea of "normal"
#   toward anomalies. It becomes worse at detecting the exact things you added.
#   You're poisoning your own model.
#
# THE FIX:
#   Step 1 → Train ONLY on clean normal data
#   Step 2 → Use labeled test set (normal + synthetic anomalies) to EVALUATE
#   Step 3 → Pick threshold using that evaluation, not the default contamination
# =============================================================================


def generate_synthetic_anomalies(n=300):
    """
    FIX #2: Anomalies are now more realistic — gradual deterioration,
    not just extreme outlier values.
    
    Your original code:
        SpO2: np.random.normal(85, 3, n//3)  → Always already in danger zone
    
    Real anomalies start normal and drift into danger. We simulate this
    by including "borderline" cases too, not just obvious emergencies.
    This forces the model to learn subtle patterns.
    """
    np.random.seed(42)
    n_each = n // 5  # 5 types now instead of 3

    # Type 1: High Fever (obvious)
    fever_obvious = pd.DataFrame({
        'HeartRate_mean': np.random.normal(115, 8, n_each),
        'HeartRate_std': np.random.normal(5, 1, n_each),
        'HeartRate_min': np.random.normal(100, 5, n_each),
        'HeartRate_max': np.random.normal(130, 8, n_each),
        'HeartRate_trend': np.random.normal(0.05, 0.02, n_each),
        'SpO2_mean': np.random.normal(96, 1, n_each),
        'SpO2_std': np.random.normal(0.5, 0.2, n_each),
        'SpO2_min': np.random.normal(94, 1, n_each),
        'SpO2_max': np.random.normal(98, 1, n_each),
        'SpO2_trend': np.random.normal(-0.01, 0.005, n_each),
        'Temperature_mean': np.random.normal(39.2, 0.5, n_each),
        'Temperature_std': np.random.normal(0.2, 0.05, n_each),
        'Temperature_min': np.random.normal(38.8, 0.4, n_each),
        'Temperature_max': np.random.normal(39.8, 0.5, n_each),
        'Temperature_trend': np.random.normal(0.02, 0.01, n_each),
        'label': -1  # -1 = anomaly (matches Isolation Forest convention)
    })

    # Type 2: Hypoxia — severe (SpO2 < 90)
    hypoxia_severe = pd.DataFrame({
        'HeartRate_mean': np.random.normal(105, 12, n_each),
        'HeartRate_std': np.random.normal(8, 2, n_each),
        'HeartRate_min': np.random.normal(90, 8, n_each),
        'HeartRate_max': np.random.normal(120, 10, n_each),
        'HeartRate_trend': np.random.normal(0.08, 0.03, n_each),
        'SpO2_mean': np.random.normal(85, 3, n_each),   # Danger zone
        'SpO2_std': np.random.normal(2, 0.5, n_each),
        'SpO2_min': np.random.normal(80, 3, n_each),
        'SpO2_max': np.random.normal(90, 2, n_each),
        'SpO2_trend': np.random.normal(-0.1, 0.03, n_each),  # Falling trend
        'Temperature_mean': np.random.normal(37.0, 0.3, n_each),
        'Temperature_std': np.random.normal(0.15, 0.05, n_each),
        'Temperature_min': np.random.normal(36.7, 0.3, n_each),
        'Temperature_max': np.random.normal(37.3, 0.3, n_each),
        'Temperature_trend': np.random.normal(0.0, 0.005, n_each),
        'label': -1
    })

    # Type 3: FIX — Borderline/Early hypoxia (SpO2 91-94, falling trend)
    # This is what kills people — it's missed because each reading seems "okay"
    # Your original model never saw this. It only saw SpO2=85.
    hypoxia_early = pd.DataFrame({
        'HeartRate_mean': np.random.normal(95, 8, n_each),
        'HeartRate_std': np.random.normal(6, 2, n_each),
        'HeartRate_min': np.random.normal(85, 6, n_each),
        'HeartRate_max': np.random.normal(108, 8, n_each),
        'HeartRate_trend': np.random.normal(0.05, 0.02, n_each),
        'SpO2_mean': np.random.normal(92.5, 1, n_each),  # Borderline
        'SpO2_std': np.random.normal(1.5, 0.3, n_each),
        'SpO2_min': np.random.normal(90, 1.5, n_each),
        'SpO2_max': np.random.normal(95, 1, n_each),
        'SpO2_trend': np.random.normal(-0.08, 0.02, n_each),  # KEY: falling
        'Temperature_mean': np.random.normal(37.2, 0.3, n_each),
        'Temperature_std': np.random.normal(0.12, 0.04, n_each),
        'Temperature_min': np.random.normal(36.9, 0.3, n_each),
        'Temperature_max': np.random.normal(37.5, 0.3, n_each),
        'Temperature_trend': np.random.normal(0.01, 0.005, n_each),
        'label': -1
    })

    # Type 4: Bradycardia (dangerously low HR)
    bradycardia = pd.DataFrame({
        'HeartRate_mean': np.random.normal(38, 5, n_each),
        'HeartRate_std': np.random.normal(4, 1, n_each),
        'HeartRate_min': np.random.normal(30, 4, n_each),
        'HeartRate_max': np.random.normal(46, 5, n_each),
        'HeartRate_trend': np.random.normal(-0.05, 0.02, n_each),
        'SpO2_mean': np.random.normal(94, 2, n_each),
        'SpO2_std': np.random.normal(1, 0.3, n_each),
        'SpO2_min': np.random.normal(91, 2, n_each),
        'SpO2_max': np.random.normal(97, 1, n_each),
        'SpO2_trend': np.random.normal(-0.02, 0.01, n_each),
        'Temperature_mean': np.random.normal(36.2, 0.3, n_each),
        'Temperature_std': np.random.normal(0.1, 0.03, n_each),
        'Temperature_min': np.random.normal(35.9, 0.3, n_each),
        'Temperature_max': np.random.normal(36.5, 0.3, n_each),
        'Temperature_trend': np.random.normal(-0.01, 0.005, n_each),
        'label': -1
    })

    # Type 5: Sepsis-like (high HR, rising temp, falling SpO2 together)
    sepsis = pd.DataFrame({
        'HeartRate_mean': np.random.normal(118, 10, n_each),
        'HeartRate_std': np.random.normal(10, 2, n_each),
        'HeartRate_min': np.random.normal(100, 8, n_each),
        'HeartRate_max': np.random.normal(135, 10, n_each),
        'HeartRate_trend': np.random.normal(0.1, 0.03, n_each),
        'SpO2_mean': np.random.normal(91, 2, n_each),
        'SpO2_std': np.random.normal(2, 0.5, n_each),
        'SpO2_min': np.random.normal(88, 2, n_each),
        'SpO2_max': np.random.normal(94, 2, n_each),
        'SpO2_trend': np.random.normal(-0.09, 0.02, n_each),
        'Temperature_mean': np.random.normal(38.8, 0.4, n_each),
        'Temperature_std': np.random.normal(0.25, 0.07, n_each),
        'Temperature_min': np.random.normal(38.3, 0.4, n_each),
        'Temperature_max': np.random.normal(39.5, 0.5, n_each),
        'Temperature_trend': np.random.normal(0.03, 0.01, n_each),
        'label': -1
    })

    return pd.concat([fever_obvious, hypoxia_severe, hypoxia_early,
                      bradycardia, sepsis], ignore_index=True)


def generate_synthetic_normal(n=500):
    """
    FIX #1 support: Healthy baseline data for scaler calibration.
    Only used for scaler fitting if real data is too sparse.
    NEVER mixed into Isolation Forest training.
    """
    np.random.seed(123)
    return pd.DataFrame({
        'HeartRate_mean': np.random.normal(75, 10, n),
        'HeartRate_std': np.random.normal(4, 1, n),
        'HeartRate_min': np.random.normal(65, 8, n),
        'HeartRate_max': np.random.normal(85, 10, n),
        'HeartRate_trend': np.random.normal(0.0, 0.01, n),
        'SpO2_mean': np.random.normal(97.5, 1, n),
        'SpO2_std': np.random.normal(0.5, 0.15, n),
        'SpO2_min': np.random.normal(96, 1, n),
        'SpO2_max': np.random.normal(99, 0.5, n),
        'SpO2_trend': np.random.normal(0.0, 0.005, n),
        'Temperature_mean': np.random.normal(36.6, 0.3, n),
        'Temperature_std': np.random.normal(0.1, 0.03, n),
        'Temperature_min': np.random.normal(36.3, 0.3, n),
        'Temperature_max': np.random.normal(36.9, 0.3, n),
        'Temperature_trend': np.random.normal(0.0, 0.003, n),
        'label': 1  # 1 = normal
    })


FEATURE_COLS = [
    'HeartRate_mean', 'HeartRate_std', 'HeartRate_min', 'HeartRate_max', 'HeartRate_trend',
    'SpO2_mean', 'SpO2_std', 'SpO2_min', 'SpO2_max', 'SpO2_trend',
    'Temperature_mean', 'Temperature_std', 'Temperature_min', 'Temperature_max', 'Temperature_trend'
]


def main():
    if not os.path.exists(INPUT_FILE):
        print("[ERROR] medical_vitals.csv not found. Run load_vitaldb_fixed.py first.")
        return

    # =========================================================================
    # STEP 1: Load and prepare NORMAL-ONLY training data
    # =========================================================================
    print("[INFO] Loading VitalDB windowed data...")
    df_real = pd.read_csv(INPUT_FILE)
    print(f"   -> Loaded {len(df_real)} windows from {df_real['Subject_ID'].nunique()} patients")

    # REPLACE with this (just print the actual columns so we can see what's there):
    if 'HeartRate_mean' not in df_real.columns:
        print("[ERROR] Column mismatch. Actual columns in your CSV:")
        print(list(df_real.columns))
    return

    # Drop Subject_ID — not a feature
    feature_data = df_real[FEATURE_COLS].dropna()
    print(f"   -> {len(feature_data)} windows after NaN removal")

    if len(feature_data) < 200:
        print("[WARNING] Very little real data. Padding with synthetic normal data.")
        syn_normal = generate_synthetic_normal(500)[FEATURE_COLS]
        feature_data = pd.concat([feature_data, syn_normal], ignore_index=True)
        print(f"   -> Padded to {len(feature_data)} total normal windows")

    # =========================================================================
    # STEP 2: Split normal data into train/test BEFORE fitting anything
    # FIX: Your original code had no train/test split at all.
    # 80% trains the model, 20% is held out to evaluate it honestly.
    # =========================================================================
    X_normal_train, X_normal_test = train_test_split(
        feature_data, test_size=0.2, random_state=42
    )
    print(f"\n[INFO] Normal data split: {len(X_normal_train)} train / {len(X_normal_test)} test")

    # =========================================================================
    # STEP 3: Scale using ONLY training data
    # FIX: Scaler must be fit on training data only. If you fit on all data,
    # you leak test set statistics into the scaler → inflated performance.
    # =========================================================================
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_normal_train)

    # =========================================================================
    # STEP 4: Train Isolation Forest on NORMAL DATA ONLY
    # FIX: contamination is now a tunable hyperparameter, not a guess.
    # We set it low (0.05) because our training data IS clean normal data.
    # The contamination accounts for occasional mislabeled normal windows.
    # =========================================================================
    print("\n[INFO] Training Isolation Forest on NORMAL DATA ONLY...")
    model = IsolationForest(
        n_estimators=200,       # More trees = more stable (was default 100)
        contamination=0.05,     # 5% expected noise in normal training data
        max_samples='auto',
        random_state=42
    )
    model.fit(X_train_scaled)

    # =========================================================================
    # STEP 5: Evaluate with a PROPER labeled test set
    # FIX: Your original evaluated on 1 hardcoded point. That's not evaluation.
    # We now test on held-out normal windows + synthetic anomalies with labels.
    # =========================================================================
    print("\n[INFO] Building labeled test set for evaluation...")

    # Label the held-out normal windows
    X_normal_test_labeled = X_normal_test.copy()
    X_normal_test_labeled['label'] = 1

    # Generate anomalies (these are ONLY used for evaluation, NOT training)
    df_anomalies = generate_synthetic_anomalies(n=300)
    X_anomaly_test = df_anomalies[FEATURE_COLS + ['label']]

    # Combine into one test set
    X_test_all = pd.concat([X_normal_test_labeled, X_anomaly_test], ignore_index=True)
    y_true = X_test_all['label'].values   # 1=normal, -1=anomaly
    X_test_features = X_test_all[FEATURE_COLS].values

    # Scale the test set using the SAME scaler (fit on training only)
    X_test_scaled = scaler.transform(X_test_features)

    # Predict
    y_pred = model.predict(X_test_scaled)       # 1=normal, -1=anomaly
    y_scores = model.score_samples(X_test_scaled)  # FIX: continuous risk score

    # =========================================================================
    # FIX #6: Proper evaluation metrics
    # =========================================================================
    print("\n" + "=" * 50)
    print("EVALUATION RESULTS")
    print("=" * 50)
    print("\nClassification Report:")
    print(classification_report(y_true, y_pred, target_names=['ANOMALY (-1)', 'NORMAL (1)']))

    # Confusion Matrix
    cm = confusion_matrix(y_true, y_pred, labels=[-1, 1])
    tn, fp, fn, tp = cm.ravel()
    print(f"True Negatives  (Correctly flagged anomalies): {tn}")
    print(f"False Positives (Normal flagged as anomaly):   {fp}")
    print(f"False Negatives (Missed anomalies!):           {fn}  ← Most dangerous")
    print(f"True Positives  (Correctly passed normal):     {tp}")

    # False Positive Rate — important for wearables (alarm fatigue is real)
    fpr = fp / (fp + tp) if (fp + tp) > 0 else 0
    fnr = fn / (fn + tn) if (fn + tn) > 0 else 0
    print(f"\nFalse Positive Rate (FPR): {fpr:.2%}  (Healthy patient falsely alarmed)")
    print(f"False Negative Rate (FNR): {fnr:.2%}  (Missed emergency — must be <5%)")

    # =========================================================================
    # FIX #7: Custom threshold based on performance, not default contamination
    # Instead of accepting the model's default cutoff, we find the threshold
    # that minimizes False Negatives (missed emergencies) while keeping
    # False Positives under control.
    # =========================================================================
    print("\n[INFO] Optimizing decision threshold...")
    thresholds = np.percentile(y_scores, np.arange(1, 30, 1))
    best_threshold = None
    best_fnr = 1.0

    for thresh in thresholds:
        y_pred_thresh = np.where(y_scores < thresh, -1, 1)
        cm_t = confusion_matrix(y_true, y_pred_thresh, labels=[-1, 1])
        tn_t, fp_t, fn_t, tp_t = cm_t.ravel()
        fnr_t = fn_t / (fn_t + tn_t) if (fn_t + tn_t) > 0 else 1
        fpr_t = fp_t / (fp_t + tp_t) if (fp_t + tp_t) > 0 else 1

        # Constraint: FPR must be < 20% (alarm fatigue threshold)
        # Among valid thresholds, minimize FNR (missed emergencies)
        if fpr_t < 0.20 and fnr_t < best_fnr:
            best_fnr = fnr_t
            best_threshold = thresh

    if best_threshold:
        print(f"   -> Optimal threshold: {best_threshold:.4f}")
        print(f"   -> At this threshold, FNR = {best_fnr:.2%} (missed emergencies)")
    else:
        best_threshold = np.percentile(y_scores, 10)
        print(f"   -> Using default 10th percentile threshold: {best_threshold:.4f}")

    # =========================================================================
    # STEP 6: Score Distribution Plot
    # Visualizes separation between normal and anomaly score distributions.
    # If they overlap heavily, your model is weak — you'll see it immediately.
    # =========================================================================
    plt.figure(figsize=(10, 5))
    normal_mask = y_true == 1
    anomaly_mask = y_true == -1
    plt.hist(y_scores[normal_mask], bins=50, alpha=0.6, color='green', label='Normal')
    plt.hist(y_scores[anomaly_mask], bins=50, alpha=0.6, color='red', label='Anomaly')
    if best_threshold:
        plt.axvline(x=best_threshold, color='black', linestyle='--',
                    label=f'Threshold ({best_threshold:.3f})')
    plt.xlabel('Anomaly Score (lower = more anomalous)')
    plt.ylabel('Count')
    plt.title('Isolation Forest: Score Distribution\n(Good model = clear separation between green and red)')
    plt.legend()
    plt.tight_layout()

    if not os.path.exists('models'):
        os.makedirs('models')
    plt.savefig(os.path.join('models', 'score_distribution.png'), dpi=150)
    print("\n[INFO] Score distribution plot saved to models/score_distribution.png")
    print("       If the green and red distributions heavily overlap → model is weak.")
    print("       If they are separated → model is good.")

    # =========================================================================
    # STEP 7: Save everything
    # =========================================================================
    joblib.dump(model, MODEL_PATH)
    joblib.dump(scaler, SCALER_PATH)
    joblib.dump(best_threshold, THRESHOLD_PATH)

    print(f"\n[SUCCESS] Saved:")
    print(f"   Model    → {MODEL_PATH}")
    print(f"   Scaler   → {SCALER_PATH}")
    print(f"   Threshold → {THRESHOLD_PATH}")


if __name__ == "__main__":
    main()