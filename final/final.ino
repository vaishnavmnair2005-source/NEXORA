/*
 * Nexora — Combined Sensor Test (MAX30102 + MLX90614 + MPU6050)
 * ==============================================================
 * Libraries needed (Arduino Library Manager):
 *   - MAX30105 by SparkFun
 *   - Adafruit MLX90614 Library by Adafruit
 *   - MPU6050 by Electronic Cats
 *
 * Wiring (all sensors share same I2C bus):
 *   VCC → ESP32 3.3V
 *   GND → ESP32 GND
 *   SDA → ESP32 GPIO 21
 *   SCL → ESP32 GPIO 22
 *   MPU6050 AD0 → GND (sets address to 0x68)
 */

#include <Wire.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <Adafruit_MLX90614.h>
#include <MPU6050.h>

// ─────────────────────────────────────────────
// OBJECTS
// ─────────────────────────────────────────────
MAX30105           particleSensor;
Adafruit_MLX90614  mlx = Adafruit_MLX90614();
MPU6050            mpu;

// ─────────────────────────────────────────────
// SpO2 / HR buffers
// ─────────────────────────────────────────────
#define BUFFER_LENGTH 100

uint32_t irBuffer[BUFFER_LENGTH];
uint32_t redBuffer[BUFFER_LENGTH];

int32_t  spo2Value;
int8_t   validSPO2;
int32_t  heartRate;
int8_t   validHeartRate;

// ─────────────────────────────────────────────
// Fall detection variables — simplified
// ─────────────────────────────────────────────
float         baselineAccel = 1.0;   // calibrated on startup
unsigned long impactStart   = 0;
bool          inImpact      = false;
bool          fallDetected  = false;

// ─────────────────────────────────────────────
// Timing
// ─────────────────────────────────────────────
unsigned long lastPrint = 0;
const int PRINT_INTERVAL = 1000;

// ─────────────────────────────────────────────
// FALL DETECTION — simplified impact method
// ─────────────────────────────────────────────
bool detectFall(float ax, float ay, float az) {
    float total = sqrt(ax * ax + ay * ay + az * az);
    float delta = total - baselineAccel;

    // Phase 1 — Impact (sudden spike above baseline)
    if (delta > 2.0 && !inImpact) {
        inImpact    = true;
        impactStart = millis();
        Serial.println("  [FALL] Impact detected!");
        return false;
    }

    // Phase 2 — Stillness after impact = confirmed fall
    if (inImpact) {
        bool isStill = (abs(delta) < 0.25);
        bool timeOk  = ((millis() - impactStart) > 300);

        if (isStill && timeOk) {
            inImpact = false;
            return true;  // FALL CONFIRMED
        }

        // Timeout after 3 seconds — reset
        if ((millis() - impactStart) > 3000) {
            inImpact = false;
        }
    }

    return false;
}

// ─────────────────────────────────────────────
// SETUP
// ─────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(1000);

    Serial.println("==========================================");
    Serial.println("Nexora — 3 Sensor Combined Test");
    Serial.println("MAX30102 + MLX90614 + MPU6050");
    Serial.println("==========================================");

    // I2C at 100kHz — stable for 3 devices on same bus
    Wire.begin(21, 22);
    Wire.setClock(100000);
    delay(500);

    // ─── Init MAX30102 ───
    Serial.print("Initialising MAX30102... ");
    if (!particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
        Serial.println("FAILED — check wiring");
        while (1);
    }
    Serial.println("OK");
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    particleSensor.setPulseAmplitudeRed(0x0A);
    particleSensor.setPulseAmplitudeGreen(0);

    // ─── Init MLX90614 ───
    Serial.print("Initialising MLX90614... ");
    if (!mlx.begin()) {
        Serial.println("FAILED — check wiring");
        while (1);
    }
    Serial.println("OK");

    // ─── Init MPU6050 ───
    Serial.print("Initialising MPU6050... ");
    mpu.initialize();
    if (!mpu.testConnection()) {
        Serial.println("FAILED — check wiring");
        while (1);
    }
    Serial.println("OK");
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_4);  // ±4g
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);  // ±500°/s

    // ─── Calibrate MPU6050 baseline ───
    Serial.println("Calibrating MPU6050 — keep sensor still...");
    float sum = 0;
    for (int i = 0; i < 50; i++) {
        int16_t ax16, ay16, az16, gx16, gy16, gz16;
        mpu.getMotion6(&ax16, &ay16, &az16, &gx16, &gy16, &gz16);
        float ax = ax16 / 8192.0;
        float ay = ay16 / 8192.0;
        float az = az16 / 8192.0;
        sum += sqrt(ax * ax + ay * ay + az * az);
        delay(20);
    }
    baselineAccel = sum / 50.0;
    Serial.print("Baseline: ");
    Serial.print(baselineAccel, 2);
    Serial.println(" g");

    // ─── Fill HR buffer ───
    Serial.println("Filling HR buffer — keep finger still...");
    for (byte i = 0; i < BUFFER_LENGTH; i++) {
        while (!particleSensor.available())
            particleSensor.check();
        redBuffer[i] = particleSensor.getRed();
        irBuffer[i]  = particleSensor.getIR();
        particleSensor.nextSample();
    }
    maxim_heart_rate_and_oxygen_saturation(
        irBuffer, BUFFER_LENGTH, redBuffer,
        &spo2Value, &validSPO2,
        &heartRate, &validHeartRate
    );

    Serial.println("All sensors ready.\n");
}

// ─────────────────────────────────────────────
// LOOP
// ─────────────────────────────────────────────
void loop() {
    // ─── Update HR/SpO2 buffer ───
    for (byte i = 25; i < BUFFER_LENGTH; i++) {
        redBuffer[i - 25] = redBuffer[i];
        irBuffer[i - 25]  = irBuffer[i];
    }
    for (byte i = 75; i < BUFFER_LENGTH; i++) {
        while (!particleSensor.available())
            particleSensor.check();
        redBuffer[i] = particleSensor.getRed();
        irBuffer[i]  = particleSensor.getIR();
        particleSensor.nextSample();
    }
    maxim_heart_rate_and_oxygen_saturation(
        irBuffer, BUFFER_LENGTH, redBuffer,
        &spo2Value, &validSPO2,
        &heartRate, &validHeartRate
    );

    // ─── Read MPU6050 ───
    int16_t ax16, ay16, az16, gx16, gy16, gz16;
    mpu.getMotion6(&ax16, &ay16, &az16, &gx16, &gy16, &gz16);

    float ax = ax16 / 8192.0;
    float ay = ay16 / 8192.0;
    float az = az16 / 8192.0;
    float gx = gx16 / 65.5;
    float gy = gy16 / 65.5;
    float gz = gz16 / 65.5;
    float totalAccel = sqrt(ax * ax + ay * ay + az * az);

    // Fall detection
    if (detectFall(ax, ay, az)) {
        fallDetected = true;
    }

    // ─── Read temperature ───
    float tempC        = mlx.readObjectTempC();
    float ambientTempC = mlx.readAmbientTempC();

    // ─── Print every 1 second ───
    if (millis() - lastPrint >= PRINT_INTERVAL) {
        lastPrint = millis();

        long irValue       = particleSensor.getIR();
        bool fingerPresent = (irValue > 50000);

        Serial.println("==========================================");

        // MAX30102
        Serial.println("[ MAX30102 — Heart Rate + SpO2 ]");
        if (!fingerPresent) {
            Serial.println("  No finger detected");
        } else {
            Serial.print("  HR:     ");
            Serial.println(validHeartRate ? String(heartRate) + " bpm" : "calculating...");
            Serial.print("  SpO2:   ");
            Serial.println(validSPO2 ? String(spo2Value) + "%" : "calculating...");
            Serial.print("  IR raw: ");
            Serial.println(irValue);
        }

        // MLX90614
        Serial.println("[ MLX90614 — Temperature ]");
        if (tempC > 20.0 && tempC < 45.0) {
            Serial.print("  Skin temp: ");
            Serial.print(tempC, 1);
            Serial.println(" C");
        } else {
            Serial.println("  Out of range — point at skin/wrist");
        }
        Serial.print("  Ambient:   ");
        Serial.print(ambientTempC, 1);
        Serial.println(" C");

        // MPU6050
        Serial.println("[ MPU6050 — Motion + Fall ]");
        Serial.print("  Accel (g):  X=");
        Serial.print(ax, 2);
        Serial.print("  Y=");
        Serial.print(ay, 2);
        Serial.print("  Z=");
        Serial.println(az, 2);
        Serial.print("  Gyro (d/s): X=");
        Serial.print(gx, 1);
        Serial.print("  Y=");
        Serial.print(gy, 1);
        Serial.print("  Z=");
        Serial.println(gz, 1);
        Serial.print("  Total accel:  ");
        Serial.print(totalAccel, 2);
        Serial.println(" g");
        Serial.print("  Baseline:     ");
        Serial.print(baselineAccel, 2);
        Serial.println(" g");
        Serial.print("  Delta:        ");
        Serial.print(totalAccel - baselineAccel, 2);
        Serial.println(" g");
        Serial.print("  Fall status:  ");
        Serial.println(fallDetected ? "*** FALL DETECTED ***" : "No fall");

        // Overall status
        Serial.println("[ STATUS ]");
        String status = "NORMAL";
        if (fallDetected)                                          status = "FALL DETECTED";
        else if (validSPO2 && spo2Value < 94)                     status = "LOW SPO2";
        else if (fingerPresent && validHeartRate && heartRate > 120) status = "HIGH HR";
        else if (fingerPresent && validHeartRate && heartRate < 50)  status = "LOW HR";
        else if (tempC > 37.5 && tempC < 45.0)                    status = "FEVER";
        Serial.print("  >> ");
        Serial.println(status);

        // Reset fall after reporting
        if (fallDetected) fallDetected = false;

        Serial.println();
    }
}
