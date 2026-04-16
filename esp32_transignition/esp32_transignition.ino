/*
 * TransIgnition - ESP32 Firmware (SIM-A7670E / GSM LTE Version)
 * MQTT Implementation
 */

#define TINY_GSM_MODEM_SIM7600
#define TINY_GSM_RX_BUFFER 1024

#include <TinyGsmClient.h>
#include <PubSubClient.h>
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

// ------------------- MQTT -------------------
const char* mqttServer = "103.93.129.118"; // IP VPS Pribadi
const int mqttPort = 1883;

String myDeviceId = "081234567890";
String mqttTopicControl = "transignition/device/dummy/control";
String mqttTopicStatus = "transignition/device/dummy/status";

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
PubSubClient mqtt(client);

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
    
    if (mqtt.connected()) {
      mqtt.loop();
    }
    
    publishStatusTask();
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
    mqttTopicControl = "transignition/device/" + myDeviceId + "/control";
    mqttTopicStatus = "transignition/device/" + myDeviceId + "/status";
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

  mqtt.setServer(mqttServer, mqttPort);
  mqtt.setCallback(mqttCallback);

  connectToMqtt();
}

// ================= MQTT CONNECT =================
void connectToMqtt() {
  if (!modem.isGprsConnected()) return;
  
  Serial.println("Connecting to MQTT...");
  // Gunakan myDeviceId sebagai Client ID MQTT
  if (mqtt.connect(myDeviceId.c_str())) {
    Serial.println("MQTT Connected");
    
    // Subscribe ke topic control
    mqtt.subscribe(mqttTopicControl.c_str());
    
    // Publish status awal
    publishStatus();
  } else {
    Serial.print("MQTT Failed, rc=");
    Serial.println(mqtt.state());
  }
}

// ================= MQTT CALLBACK =================
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");
  Serial.print(topic);
  Serial.print("] ");
  
  String msg = "";
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  Serial.println(msg);
  
  // Parse JSON
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, msg);
  
  if (error) {
    Serial.print("JSON Error: ");
    Serial.println(error.c_str());
    return;
  }
  
  bool ignitionOn = doc["ignition_on"];
  bool isLocked = doc["is_locked"];
  
  controlRelay(ignitionOn, isLocked);
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
    
    // Check MQTT connection
    if (!mqtt.connected()) {
      if (millis() - lastReconnectTime > reconnectInterval) {
         connectToMqtt();
         lastReconnectTime = millis();
      }
    }

  }
}

// ================= STATUS PUBLISH TASK =================
void publishStatus() {
  if (mqtt.connected()) {
    StaticJsonDocument<256> doc;
    doc["ignition_on"] = lastEngineStatus;
    
    String payload;
    serializeJson(doc, payload);
    mqtt.publish(mqttTopicStatus.c_str(), payload.c_str());
  }
}

void publishStatusTask() {
  // Periodically send ping/status to backend
  if (millis() - lastRequestTime < requestInterval) return;
  lastRequestTime = millis();

  if (mqtt.connected()) {
    publishStatus();
  }
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

    mqttTopicControl = "transignition/device/" + myDeviceId + "/control";
    mqttTopicStatus = "transignition/device/" + myDeviceId + "/status";

    Serial.print("Device ID Updated: ");
    Serial.println(myDeviceId);
    
    if (mqtt.connected()) {
      mqtt.unsubscribe(mqttTopicControl.c_str());
      mqtt.disconnect();
    }
  }

}