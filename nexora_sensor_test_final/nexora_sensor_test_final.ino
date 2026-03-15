/*
 * Nexora — Combined Sensor Test (MAX30102 + MLX90614 + MPU6050)
 * ==============================================================
 * Tests all 3 I2C sensors simultaneously on ESP32
 * 
 * Libraries needed (Arduino Library Manager):
 *   - MAX30105 by SparkFun
 *   - Adafruit MLX90614 Library by Adafruit
 *   - MPU6050 by Electronic Cats  ← install this one
 * 
 * Wiring (all sensors share same I2C bus):
 *   VCC  → ESP32 3.3V
 *   GND  → ESP32 GND
 *   SDA  → ESP32 GPIO 21
 *   SCL  → ESP32 GPIO 22
 * 
 * I2C Addresses:
 *   MAX30102  → 0x57
 *   MLX90614  → 0x5A
 *   MPU6050   → 0x68
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
// Fall detection variables
// ─────────────────────────────────────────────
#define FALL_THRESHOLD     2.5   // g-force threshold for fall detection
#define FALL_CONFIRM_MS    500   // ms to confirm fall (impact then stillness)

bool     fallDetected    = false;
bool     impactDetected  = false;
unsigned long impactTime = 0;

// ─────────────────────────────────────────────
// Timing
// ─────────────────────────────────────────────
unsigned long lastPrint = 0;
const int PRINT_INTERVAL = 1000;

// ─────────────────────────────────────────────
// FALL DETECTION FUNCTION
// ─────────────────────────────────────────────
bool detectFall(float ax, float ay, float az) {
    // Calculate total acceleration magnitude
    float totalAccel = sqrt(ax * ax + ay * ay + az * az);

    // Step 1 — Impact detection (sudden high g-force)
    if (totalAccel > FALL_THRESHOLD && !impactDetected) {
        impactDetected = true;
        impactTime     = millis();
        Serial.println("  [FALL] Impact detected!");
        return false;
    }

    // Step 2 — Confirm fall (stillness after impact)
    if (impactDetected) {
        unsigned long timeSinceImpact = millis() - impactTime;

        // Check if person is still after impact (lying on ground)
        bool isStill = (totalAccel < 0.3);

        if (isStill && timeSinceImpact > FALL_CONFIRM_MS) {
            impactDetected = false;
            return true;  // FALL CONFIRMED
        }

        // Reset if no stillness within 2 seconds
        if (timeSinceImpact > 2000) {
            impactDetected = false;
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

    // I2C at 100kHz — required for stability with 3 devices
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

    // MPU6050 configuration
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_4);  // ±4g range
    mpu.setFullScaleGyroRange(MPU6050_GYRO_FS_500);  // ±500°/s range

    Serial.println("\nAll 3 sensors ready.");
    Serial.println("------------------------------------------");
    Serial.println("Place finger on MAX30102");
    Serial.println("Point MLX90614 at wrist");
    Serial.println("Hold/wear MPU6050 on body");
    Serial.println("------------------------------------------");

    // Fill initial buffer
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

    Serial.println("Ready.\n");
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
    int16_t ax16, ay16, az16;
    int16_t gx16, gy16, gz16;
    mpu.getMotion6(&ax16, &ay16, &az16, &gx16, &gy16, &gz16);

    // Convert to g (±4g range → divide by 8192)
    float ax = ax16 / 8192.0;
    float ay = ay16 / 8192.0;
    float az = az16 / 8192.0;

    // Convert to °/s (±500°/s range → divide by 65.5)
    float gx = gx16 / 65.5;
    float gy = gy16 / 65.5;
    float gz = gz16 / 65.5;

    // Total acceleration magnitude
    float totalAccel = sqrt(ax * ax + ay * ay + az * az);

    // Fall detection
    if (detectFall(ax, ay, az)) {
        fallDetected = true;
        Serial.println("  *** FALL DETECTED ***");
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
            Serial.print("  HR:   ");
            Serial.print(validHeartRate ? String(heartRate) + " bpm" : "calculating...");
            Serial.println();
            Serial.print("  SpO2: ");
            Serial.print(validSPO2 ? String(spo2Value) + "%" : "calculating...");
            Serial.println();
            Serial.print("  IR raw: ");
            Serial.println(irValue);
        }

        // MLX90614
        Serial.println("[ MLX90614 — Temperature ]");
        if (tempC > 20.0 && tempC < 45.0) {
            Serial.print("  Object (skin): ");
            Serial.print(tempC, 1);
            Serial.println(" C");
        } else {
            Serial.println("  Object temp: out of range — point at skin");
        }
        Serial.print("  Ambient:       ");
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
        Serial.print("  Total accel: ");
        Serial.print(totalAccel, 2);
        Serial.println(" g");
        Serial.print("  Fall status: ");
        Serial.println(fallDetected ? "*** FALL DETECTED ***" : "No fall");

        // Overall status
        Serial.println("[ STATUS ]");
        String status = "NORMAL";
        if (fallDetected)                          status = "FALL DETECTED";
        else if (validSPO2 && spo2Value < 94)      status = "LOW SPO2";
        else if (validHeartRate && heartRate > 120) status = "HIGH HR";
        else if (validHeartRate && heartRate < 50)  status = "LOW HR";
        else if (tempC > 37.5 && tempC < 45.0)     status = "FEVER";
        Serial.print("  >> ");
        Serial.println(status);

        // Reset fall after reporting
        if (fallDetected) fallDetected = false;

        Serial.println();
    }
}
