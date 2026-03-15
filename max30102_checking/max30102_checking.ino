#include <Wire.h>
#include "MAX30105.h" // SparkFun library uses this name for MAX30102 too

MAX30105 particleSensor;

void setup() {
  Serial.begin(115200);
  Serial.println("Initializing MAX30102...");

  // Initialize sensor
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) { // Use default I2C port, 400kHz speed
    Serial.println("MAX30102 was not found. Please check wiring/power. ");
    while (1);
  }

  // Setup to sense a nice looking saw tooth on the plotter
  byte ledBrightness = 0x1F; // Options: 0=Off to 255=50mA
  byte sampleAverage = 8; // Options: 1, 2, 4, 8, 16, 32
  byte ledMode = 3; // Options: 1 = Red only, 2 = Red + IR, 3 = Red + IR + Green
  int sampleRate = 100; // Options: 50, 100, 200, 400, 800, 1000, 1600, 3200
  int pulseWidth = 411; // Options: 69, 118, 215, 411
  int adcRange = 4096; // Options: 2048, 4096, 8192, 16384

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange); // Configure sensor with these settings
  Serial.println("MAX30102 Found! Place your finger on the sensor.");
}

void loop() {
  // Read the IR value (this detects your finger)
  long irValue = particleSensor.getIR();

  if (irValue < 50000) {
    Serial.print(" No finger?");
  } else {
    Serial.print(" Finger Detected!");
  }
  
  Serial.print(" IR=");
  Serial.print(irValue);
  Serial.print(", Red=");
  Serial.print(particleSensor.getRed());
  Serial.println();
  
  delay(100); // Slow down for readability
}