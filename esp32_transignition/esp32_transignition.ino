/*
 * TransIgnition - ESP32 Firmware (SIM-A7670E / GSM LTE Version)
 * Deskripsi: Kontrol Relay Pengapian (Ignition) berdasarkan Status dari Backend API
 * Author: Antigravity AI
 */

// --- KONFIGURASI MODEM SIM-A7670E ---
// Tentukan tipe modem untuk TinyGSM (SIM-A7670E menggunakan command set yang mirip dengan SIM7600)
#define TINY_GSM_MODEM_SIM7600
#define TINY_GSM_RX_BUFFER 1024

#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h>
#include <ArduinoJson.h>

// --- KONFIGURASI KARTU SIM (APN) ---
// Sesuaikan APN dengan provider kartu operator yang digunakan (contoh: "internet", "telkomsel", "indosatgprs")
const char apn[]      = "internet"; 
const char gprsUser[] = "";
const char gprsPass[] = "";

// --- KONFIGURASI API ---
// Pastikan IP sesuai dengan server yang dapat diakses dari internet (VPS/Public IP)
const char* serverName = "103.93.129.118";
const int serverPort = 8000;

// IDENTITAS PERANGKAT (Sesuaikan dengan nomor SIM atau ID unik lainnya)
// ID ini harus sama dengan yang diinputkan di aplikasi Mobile Dashboard
String myDeviceId = "081234567890"; 
String resourcePath = "/ignition/status?device_id=" + myDeviceId;

// --- KONFIGURASI PENGABELAN (WIRING) ---
const int relayPin = 26;      // Hubungkan ke Pin Relay (Ignition Motor)
const int ledStatusPin = 2;  // LED Built-in untuk indikator koneksi

// Pin hardware serial untuk komunikasi ESP32 dengan SIM-A7670E
// Hubungkan TX modul ke RX (Pin 16) ESP32, dan RX modul ke TX (Pin 17) ESP32
#define MODEM_RX_PIN 3 
#define MODEM_TX_PIN 1
#define SerialAT Serial2

// Variabel status
bool lastEngineStatus = false;
unsigned long lastRequestTime = 0;
const unsigned long requestInterval = 2000; // Poll setiap 2 detik (Lebih wajar untuk koneksi seluler)

#ifdef DUMP_AT_COMMANDS
  #include <StreamDebugger.h>
  StreamDebugger debugger(SerialAT, Serial);
  TinyGsm modem(debugger);
#else
  TinyGsm modem(SerialAT);
#endif

TinyGsmClient client(modem);
HttpClient http(client, serverName, serverPort);

void setup() {
  Serial.begin(115200);
  
  pinMode(relayPin, OUTPUT);
  pinMode(ledStatusPin, OUTPUT);
  
  // Inisialisasi awal (mati)
  digitalWrite(relayPin, LOW); 
  digitalWrite(ledStatusPin, LOW);

  connectToNetwork();
}

void loop() {
  // Pengecekan koneksi ke jaringan GPRS/LTE
  if (!modem.isGprsConnected()) {
    digitalWrite(ledStatusPin, LOW);
    connectToNetwork();
  } else {
    digitalWrite(ledStatusPin, HIGH); // LED menyala anteng saat koneksi OK
  }

  // Lakukan polling status setiap interval tertentu
  if (millis() - lastRequestTime >= requestInterval) {
    checkIgnitionStatus();
    lastRequestTime = millis();
  }
}

void connectToNetwork() {
  Serial.println("Initializing modem SIM-A7670E...");
  
  // Memulai komunikasi serial dengan modem pada baud rate 115200
  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);
  delay(3000);
  
  // modem.restart(); // Hapus komentar ini jika ingin me-restart modem setiap inisialisasi awal

  String modemInfo = modem.getModemInfo();
  Serial.print("Modem Info: ");
  Serial.println(modemInfo);

  Serial.print("Waiting for network connection...");
  if (!modem.waitForNetwork()) {
    Serial.println(" Failed to connect to network. Retrying in 10s...");
    delay(10000);
    return;
  }
  Serial.println(" Success!");

  if (modem.isNetworkConnected()) {
    Serial.println("Network connected");
  }

  Serial.print("Connecting to APN: ");
  Serial.print(apn);
  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
    Serial.println(" Failed! Make sure APN setting is correct. Retrying in 10s...");
    delay(10000);
    return;
  }
  
  Serial.println(" Connected to APN (GPRS/LTE) Successfully!");
}

void checkIgnitionStatus() {
  if (modem.isGprsConnected()) {
    Serial.print("Fetching API from ");
    Serial.println(serverName);

    int err = http.get(resourcePath);
    if (err != 0) {
      Serial.print("HTTP GET failed, error code: ");
      Serial.println(err);
      return;
    }

    int statusCode = http.responseStatusCode();
    Serial.print("Status code: ");
    Serial.println(statusCode);

    if (statusCode == 200 || statusCode == 201) {
      String payload = http.responseBody();
      Serial.println("Response Payload: " + payload);

      // Parsing JSON dari Backend
      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, payload);

      if (!error) {
        bool ignitionOn = doc["ignition_on"];
        bool isLocked = doc["is_locked"];

        // Logika Kontrol Relay Mesin
        if (ignitionOn && !isLocked) {
          digitalWrite(relayPin, HIGH); // Nyalakan Mesin
          if (!lastEngineStatus) Serial.println(">>> ENGINE HAS STARTED! <<<");
        } else {
          digitalWrite(relayPin, LOW);  // Matikan Mesin
          if (lastEngineStatus) Serial.println(">>> ENGINE HAS STOPPED! <<<");
        }
        
        lastEngineStatus = ignitionOn;
      } else {
        Serial.print("JSON Parse Failed: ");
        Serial.println(error.c_str());
      }
    } else {
      Serial.print("Failed to get a valid response. Http code: ");
      Serial.println(statusCode);
    }
    
    http.stop(); // Stop the connection to clean up
  }
}
