
#include <Wire.h>
#include "MAX30105.h"
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// Create Sensor Objects
MAX30105 particleSensor;
Adafruit_MPU6050 mpu;

void setup() {
  Serial.begin(115200);
  while (!Serial);
  Serial.println("\n--- DUAL SENSOR TEST (MAX30102 + MPU6050) ---");

  // Initialize I2C
  Wire.begin();

  // 1. CHECK MAX30102
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("[FAIL] MAX30102 not found. Check wiring.");
  } else {
    Serial.println("[SUCCESS] MAX30102 Found!");
    particleSensor.setup(); // Default settings
  }

  // 2. CHECK MPU6050
  if (!mpu.begin()) {
    Serial.println("[FAIL] MPU6050 not found. Check wiring.");
  } else {
    Serial.println("[SUCCESS] MPU6050 Found!");
    mpu.setAccelerometerRange(MPU6050_RANGE_8_G);
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);
    mpu.setFilterBandwidth(MPU6050_BAND_21_HZ);
  }
  
  Serial.println("---------------------------------------------");
  delay(1000);
}

void loop() {
  // READ MPU6050
  sensors_event_t a, g, temp;
  mpu.getEvent(&a, &g, &temp);

  // READ MAX30102
  long irValue = particleSensor.getIR();

  // PRINT EVERYTHING
  Serial.print("Motion X: "); Serial.print(a.acceleration.x);
  Serial.print(" | IR Value: "); Serial.print(irValue);
  
  if (irValue > 50000) Serial.print(" (Finger Detected)");
  else Serial.print(" (No Finger)");
  
  Serial.println();
  delay(200);
}