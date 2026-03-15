/*
  Simple ESP32 Camera Streamer
  - This is the code for your ESP32-CAM module.
  - It will be uploaded using your new ESP32-CAM-MB programmer.
*/

// ===================================================
//
// 1. BOARD SETUP (Do this in your Arduino IDE)
//
// - Go to File > Preferences
// - Add this URL to "Additional Board Manager URLs":
//   https://dl.espressif.com/dl/package_esp32_index.json
//
// - Go to Tools > Board > Boards Manager
// - Search for "esp32" and install it.
//
// - Go to Tools > Board > esp32
// - Select "AI Thinker ESP32-CAM"
//
// ===================================================

#include "esp_camera.h"
#include <WiFi.h>
#include "esp_timer.h"
#include "img_converters.h"
#include "Arduino.h"
#include "soc/soc.h"           // Disable brownout problems
#include "soc/rtc_cntl_reg.h"  // Disable brownout problems
#include "driver/rtc_io.h"
#include <WebServer.h>        // Use WebServer for ESP32

// --- ACTION REQUIRED ---
// Put your Wi-Fi credentials here
const char* ssid = "vaishnav";
const char* password = "Vaishu@18";
// ---------------------

// Define the camera pins (this is the standard for AI-THINKER board)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

WebServer server(80);
WebServer streamServer(81);

void startCameraServer();

void setup() {
  // Disable the brownout detector, which can cause reboots on power dips
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); 
  
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  
  // --- EDITED FOR PERFORMANCE ---
  // Using QVGA (320x240) is much faster than VGA
  config.frame_size = FRAMESIZE_HVGA; // (320x240)
  // ------------------------------

  config.pixel_format = PIXFORMAT_JPEG; 
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  
  // --- EDITED FOR PERFORMANCE ---
  // Using a slightly higher number (lower quality) to save bandwidth
  config.jpeg_quality = 10;// 0-63 (lower = better quality)
  // ------------------------------
  
  config.fb_count = 1;

  // Camera init
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }

  // Adjust camera settings for better performance
  sensor_t * s = esp_camera_sensor_get();
  // Set the new, faster frame size
  s->set_framesize(s, FRAMESIZE_HVGA); // (320x240)
  s->set_quality(s, 10); // (0-63)
  
  // Connect to Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to ");
  Serial.print(ssid);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  
  // Print the IP address
  Serial.println("");
  Serial.println("Camera Ready! Use the following IP addresses:");
  Serial.print("Web Server: http://");
  Serial.println(WiFi.localIP());
  Serial.print("Stream: http://");
  Serial.print(WiFi.localIP());
  Serial.println(":81/stream");

  // Start the web server and stream server
  startCameraServer();
}

void loop() {
  server.handleClient();
  streamServer.handleClient();
  delay(1);
}

// --- Stream Handler ---
void handle_jpg_stream(void) {
  WiFiClient client = streamServer.client();
  String response = "HTTP/1.1 200 OK\r\n";
  response += "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";
  streamServer.sendContent(response);

  while (true) {
    camera_fb_t * fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Camera capture failed");
      break;
    }
    
    response = "--frame\r\n";
    response += "Content-Type: image/jpeg\r\n";
    response += "Content-Length: " + String(fb->len) + "\r\n\r\n";
    streamServer.sendContent(response);
    
    client.write((char *)fb->buf, fb->len);
    streamServer.sendContent("\r\n");
    
    esp_camera_fb_return(fb);
    
    if (!client.connected()) {
      break;
    }
  }
}

// --- Webpage Handler ---
void handle_jpg(void) {
  WiFiClient client = server.client();
  
  camera_fb_t * fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("Camera capture failed");
    server.send(500, "text/plain", "Camera capture failed");
    return;
  }

  String response = "HTTP/1.1 200 OK\r\n";
  response += "Content-Type: image/jpeg\r\n";
  response += "Content-Length: " + String(fb->len) + "\r\n\r\n";
  server.sendContent(response);
  
  client.write((char *)fb->buf, fb->len);
  
  esp_camera_fb_return(fb);
}

void handle_root(void) {
  String page = "<!DOCTYPE html><html><head><title>ESP32-CAM Stream</title>";
  page += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>";
  page += "<style>body{font-family: Arial, sans-serif; text-align: center; background-color: #f4f4f4;}";
  page += "h1{color: #333;} img{border: 2px solid #333; border-radius: 8px; max-width: 90%;}";
  page += "</style></head><body>";
  page += "<h1>ESP32-CAM Stream</h1>";
  page += "<h3>This is the video feed for your Sign Language Translator.</h3>";
  // This img src points to the :81/stream URL
  page += "<img src='" + String("http://") + WiFi.localIP().toString() + ":81/stream" + "'>";
  page += "</body></html>";
  
  server.send(200, "text/html", page);
}

void startCameraServer() {
  server.on("/", handle_root);
  server.on("/jpg", handle_jpg);
  server.begin();
  
  streamServer.on("/stream", handle_jpg_stream);
  streamServer.begin();
}

