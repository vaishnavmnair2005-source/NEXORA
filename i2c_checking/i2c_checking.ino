#include <Wire.h>

void setup() {
    Serial.begin(115200);
    delay(1000);
    Wire.begin(21, 22);
    Wire.setClock(100000);
    delay(500);

    Serial.println("Scanning...");
    int count = 0;
    for (byte addr = 1; addr < 127; addr++) {
        Wire.beginTransmission(addr);
        byte error = Wire.endTransmission();
        if (error == 0) {
            Serial.print("Found: 0x");
            if (addr < 16) Serial.print("0");
            Serial.println(addr, HEX);
            count++;
        }
    }
    Serial.print("Total devices: ");
    Serial.println(count);
}

void loop() {}