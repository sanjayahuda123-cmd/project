/*
 * TransIgnition - ESP32 Firmware (SIM-A7670E / GSM LTE Version)
 */

#define TINY_GSM_MODEM_SIM7600
#define TINY_GSM_RX_BUFFER 1024

#include <TinyGsmClient.h>
#include <ArduinoHttpClient.h>
#include <ArduinoJson.h>

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define BLE_SERVICE_UUID "7A0247E7-8E88-409B-A959-AB5092DDB03E"

// ------------------- MODEM PIN -------------------
#define MODEM_RX_PIN 16
#define MODEM_TX_PIN 17
#define MODEM_PWR_PIN 4

#define SerialAT Serial2

// ------------------- APN -------------------
const char apn[]      = "internet";
const char gprsUser[] = "";
const char gprsPass[] = "";

// ------------------- API -------------------
const char* serverName = "103.93.129.118";
const int serverPort = 8000;

String myDeviceId = "081234567890";
String resourcePath = "/ignition/status?device_id=" + myDeviceId;

// ------------------- PIN -------------------
const int relayPin = 26;
const int ledStatusPin = 2;

// ------------------- TIMER -------------------
unsigned long lastRequestTime = 0;
unsigned long lastReconnectTime = 0;
unsigned long lastLoopTime = 0;

const unsigned long requestInterval = 3000;
const unsigned long reconnectInterval = 10000;
const unsigned long loopInterval = 100;

bool lastEngineStatus = false;

TinyGsm modem(SerialAT);
TinyGsmClient client(modem);
HttpClient http(client, serverName, serverPort);

// ================= SETUP =================
void setup() {

  Serial.begin(115200);

  pinMode(relayPin, OUTPUT);
  pinMode(ledStatusPin, OUTPUT);

  digitalWrite(relayPin, LOW);
  digitalWrite(ledStatusPin, LOW);

  // Power On Modem
  pinMode(MODEM_PWR_PIN, OUTPUT);
  digitalWrite(MODEM_PWR_PIN, LOW);
  delay(1000);
  digitalWrite(MODEM_PWR_PIN, HIGH);
  delay(5000);

  connectToNetwork();
}

// ================= LOOP =================
void loop() {

  unsigned long now = millis();

  if (now - lastLoopTime >= loopInterval) {

    lastLoopTime = now;

    checkConnectionTask();
    checkIgnitionTask();
    checkSerialCommand();

  }
}

// ================= CONNECT NETWORK =================
void connectToNetwork() {

  Serial.println("Initializing Modem...");

  SerialAT.begin(115200, SERIAL_8N1, MODEM_RX_PIN, MODEM_TX_PIN);

  delay(3000);

  modem.restart();
  delay(3000);

  Serial.println("Checking SIM...");

  if (!modem.getSimStatus()) {
    Serial.println("SIM not ready");
    return;
  }

  // --- Auto-detect Device ID using SIM CCID ---
  String ccid = modem.getSimCCID();
  if (ccid.length() > 0) {
    myDeviceId = ccid;
    resourcePath = "/ignition/status?device_id=" + myDeviceId;
    Serial.print("Device ID Automatically set to SIM CCID: ");
    Serial.println(myDeviceId);
  } else {
    Serial.println("Warning: Could not read CCID. Using default Device ID.");
  }
  // --------------------------------------------

  // --- Start BLE Advertising ---
  BLEDevice::init(myDeviceId.c_str()); // Set BLE Device Name to CCID
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(BLE_SERVICE_UUID);
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(BLE_SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  Serial.println("BLE Advertising Started for TWS Connect");
  // -----------------------------

  Serial.println("Waiting Network...");

  if (!modem.waitForNetwork(60000)) {
    Serial.println("Network failed");
    return;
  }

  Serial.println("Network Connected");

  Serial.print("Connecting APN: ");
  Serial.println(apn);

  if (!modem.gprsConnect(apn, gprsUser, gprsPass)) {
    Serial.println("GPRS Failed");
    return;
  }

  Serial.println("GPRS Connected");

  Serial.print("Signal: ");
  Serial.println(modem.getSignalQuality());

  http.setTimeout(10000);
}

// ================= CONNECTION TASK =================
void checkConnectionTask() {

  if (!modem.isGprsConnected()) {

    digitalWrite(ledStatusPin, LOW);

    if (millis() - lastReconnectTime > reconnectInterval) {

      Serial.println("Reconnecting Network...");

      connectToNetwork();

      lastReconnectTime = millis();
    }

  } else {

    digitalWrite(ledStatusPin, HIGH);

  }
}

// ================= IGNITION TASK =================
void checkIgnitionTask() {

  if (millis() - lastRequestTime < requestInterval) return;

  lastRequestTime = millis();

  if (!modem.isGprsConnected()) return;

  Serial.println("Fetching API...");

  int err = http.get(resourcePath);

  if (err != 0) {

    Serial.print("HTTP Error: ");
    Serial.println(err);
    return;
  }

  int statusCode = http.responseStatusCode();

  Serial.print("HTTP Code: ");
  Serial.println(statusCode);

  if (statusCode != 200 && statusCode != 201) {

    http.stop();
    return;
  }

  String payload = http.responseBody();

  Serial.println(payload);

  StaticJsonDocument<256> doc;

  DeserializationError error = deserializeJson(doc, payload);

  if (error) {

    Serial.print("JSON Error: ");
    Serial.println(error.c_str());

    http.stop();
    return;
  }

  bool ignitionOn = doc["ignition_on"];
  bool isLocked = doc["is_locked"];

  controlRelay(ignitionOn, isLocked);

  http.stop();
}

// ================= RELAY CONTROL =================
void controlRelay(bool ignitionOn, bool isLocked) {

  bool currentEngineTarget = ignitionOn && !isLocked;

  if (currentEngineTarget) {

    digitalWrite(relayPin, HIGH);

    if (!lastEngineStatus)
      Serial.println("ENGINE START");

  } else {

    digitalWrite(relayPin, LOW);

    if (lastEngineStatus)
      Serial.println("ENGINE STOP");

  }

  lastEngineStatus = currentEngineTarget;
}

// ================= SERIAL COMMAND =================
void checkSerialCommand() {

  if (!Serial.available()) return;

  String command = Serial.readStringUntil('\n');

  command.trim();

  if (command == "restart") {

    Serial.println("Restarting modem...");
    modem.restart();

  } 
  else if (command.startsWith("setid ")) {

    myDeviceId = command.substring(6);
    myDeviceId.trim();

    resourcePath = "/ignition/status?device_id=" + myDeviceId;

    Serial.print("Device ID Updated: ");
    Serial.println(myDeviceId);
  }

}