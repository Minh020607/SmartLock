#include <WiFi.h>
#include <WiFiMulti.h>
#include <PubSubClient.h>
#include <Wire.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Keypad.h>
#include <LiquidCrystal_I2C.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <Preferences.h>

/* ================= CẤU HÌNH HỆ THỐNG ================= */
const char* mqttServer = "d60daf22.ala.asia-southeast1.emqxsl.com";
const int mqttPort = 8883;
const char* lockId = "e16147df-f1a2-40bb-b813-750bd79e6b2e";

#define SS_PIN 5
#define RST_PIN 32
#define BUZZER_PIN 4
#define BUTTON_PIN 34
#define SOLENOID_PIN 17
#define BATTERY_PIN 35 

/* ================= ĐỐI TƯỢNG VÀ BIẾN ================= */
WiFiMulti wifiMulti;
MFRC522 rfid(SS_PIN, RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2);
Preferences preferences;
WiFiClientSecure espClient; 
PubSubClient mqttClient(espClient);

unsigned long lastLCDActivity = 0;      
const unsigned long LCD_TIMEOUT = 20000; 
bool isLCDBacklightOn = true;          
int globalBattery = 100; 
String currentPass = "1236"; 

#define ROW_NUM 4
#define COL_NUM 3
byte pin_rows[ROW_NUM] = {33, 25, 26, 27};
byte pin_cols[COL_NUM] = {14, 12, 13};
char keys[ROW_NUM][COL_NUM] = { {'1','2','3'}, {'4','5','6'}, {'7','8','9'}, {'*','0','#'} };
Keypad keypad = Keypad(makeKeymap(keys), pin_rows, pin_cols, ROW_NUM, COL_NUM);

enum SystemState { SYS_IDLE, SYS_WAIT_PASSWORD, SYS_LOCKED, SYS_CHANGE_OLD, SYS_CHANGE_NEW, SYS_CHANGE_CONFIRM };
SystemState currentState = SYS_IDLE;

String inputPassword = "";
String tempPassword = ""; 
int failCount = 0;      
int failCountRFID = 0;  
unsigned long lockStartTime = 0;
unsigned long lastActivityTime = 0;
const unsigned long TIMEOUT_TIME = 10000; 
bool isLearningMode = false;
unsigned long lastNetCheck = 0; 

/* ================= HÀM HỖ TRỢ ================= */
void beepStep() { digitalWrite(BUZZER_PIN, HIGH); delay(50); digitalWrite(BUZZER_PIN, LOW); }
void beepSuccess() { for(int i=0; i<2; i++){ digitalWrite(BUZZER_PIN, HIGH); delay(100); digitalWrite(BUZZER_PIN, LOW); delay(50); } }
void beepError() { for(int i=0; i<3; i++){ digitalWrite(BUZZER_PIN, HIGH); delay(400); digitalWrite(BUZZER_PIN, LOW); delay(100); } }

void wakeUpLCD() {
  lastLCDActivity = millis(); 
  if (!isLCDBacklightOn) { lcd.backlight(); isLCDBacklightOn = true; }
}

int getBatteryPercent() {
  long sum = 0;
  for(int i=0; i<10; i++) { sum += analogRead(BATTERY_PIN); }
  float voltage = ((sum / 10.0) / 4095.0) * 3.3 * 4.7;
  float percent = (voltage - 9.0) / (12.6 - 9.0) * 100.0;
  return (int)constrain(percent, 0, 100);
}

void showIdle() {
  globalBattery = getBatteryPercent(); 
  wakeUpLCD();
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print("--- HE THONG ---");
  lcd.setCursor(0, 1); lcd.print("KHOA  Pin:");
  lcd.print(globalBattery); lcd.print("%");
  currentState = SYS_IDLE;
  inputPassword = "";
}

// Hàm gửi trạng thái chuẩn (dùng cho Mở/Khóa/Cảnh báo)
void publishStatus(bool locked, const char* method, const char* userName, bool saveToHistory = true) {
  if (!mqttClient.connected()) return; 
  String topic = "smartlock/" + String(lockId) + "/status";
  StaticJsonDocument<256> doc;
  doc["locked"] = locked;
  doc["online"] = true;
  doc["battery"] = getBatteryPercent();
  doc["method"] = method; 
  doc["by"] = userName;
  doc["save"] = saveToHistory; 
  String payload;
  serializeJson(doc, payload);
  mqttClient.publish(topic.c_str(), payload.c_str(), true); 
}

// Hàm gửi thông báo quản lý (Dành riêng cho Thêm/Xóa thẻ để tránh hiện "Đã khóa")
void publishAdminEvent(const char* method, const char* note) {
  if (!mqttClient.connected()) return;
  String topic = "smartlock/" + String(lockId) + "/status";
  StaticJsonDocument<256> doc;
  doc["online"] = true;
  doc["method"] = method; 
  doc["by"] = note;
  doc["save"] = true;
  // Không gửi kèm biến "locked" để App không báo trạng thái khóa
  String payload;
  serializeJson(doc, payload);
  mqttClient.publish(topic.c_str(), payload.c_str(), true);
}

void unlock(const char* method, const char* userName) {
  wakeUpLCD();
  lcd.clear(); lcd.print("DA XAC NHAN!");
  lcd.setCursor(0,1); lcd.print("MO CUA: "); lcd.print(userName);
  digitalWrite(SOLENOID_PIN, HIGH);
  publishStatus(false, method, userName, true); 
  beepSuccess();
  delay(3000); 
  digitalWrite(SOLENOID_PIN, LOW);
  lcd.clear(); lcd.print("DA KHOA LAI");
  publishStatus(true, "auto_lock", "He Thong", false); 
  delay(1500);
  showIdle();
}

void maintainConnections() {
  if (millis() - lastNetCheck < 10000) return;
  lastNetCheck = millis();
  if (wifiMulti.run() != WL_CONNECTED) return; 

  if (!mqttClient.connected()) {
    String clientId = "ESP32_Lock_" + String(random(1000, 9999));
    if (mqttClient.connect(clientId.c_str(), "anhminh", "020623")) {
        mqttClient.subscribe(("smartlock/" + String(lockId) + "/cmd").c_str());
        publishStatus((digitalRead(SOLENOID_PIN) == LOW), "boot", "He Thong", false);
    }
  }
}

/* ================= XỬ LÝ PHẦN CỨNG ================= */
void handleRFID() {
  if (currentState == SYS_LOCKED) return;
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;
  wakeUpLCD();
  
  String cardID = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    cardID += String(rfid.uid.uidByte[i] < 0x10 ? "0" : "");
    cardID += String(rfid.uid.uidByte[i], HEX);
  }
  cardID.toUpperCase();

  if (isLearningMode) {
    if (mqttClient.connected()) {
      StaticJsonDocument<256> doc; 
      doc["pending_id"] = cardID; 
      doc["online"] = true;
      String payload; serializeJson(doc, payload);
      mqttClient.publish(("smartlock/" + String(lockId) + "/status").c_str(), payload.c_str()); 
      // BỎ publishStatus ở đây để không hiện 2 lần
    }
    lcd.clear(); lcd.print("DA QUET THE!");
    isLearningMode = false; beepSuccess(); delay(2000); showIdle();
  } else {
    preferences.begin("rfid-cards", true);
    bool authorized = preferences.isKey(cardID.c_str()) || (cardID == "63CDA256");
    preferences.end();
    
    if (authorized) {
      failCountRFID = 0;
      unlock("rfid", "The Tu");
    } else {
      failCountRFID++;
      beepError();
      lcd.clear(); lcd.print("THE CHUA DK!");
      publishStatus(true, "warning", "The la xam nhap", true); 
      
      if (failCountRFID >= 3) {
        currentState = SYS_LOCKED;
        lockStartTime = millis();
        lcd.setCursor(0,1); lcd.print("TAM KHOA 30S!");
        publishStatus(true, "warning", "Khoa the 30s", true);
      } else {
        delay(2000); showIdle();
      }
    }
  }
  rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
}

void startInput(const char* line1) {
  lastActivityTime = millis(); wakeUpLCD();
  lcd.clear(); lcd.print(line1); lcd.setCursor(0,1); lcd.print("> "); 
  inputPassword = "";
}

void handleKeypad() {
  if (currentState == SYS_LOCKED) {
    if (millis() - lockStartTime > 30000) { 
      currentState = SYS_IDLE; failCount = 0; failCountRFID = 0; showIdle(); 
    }
    return;
  }
  char key = keypad.getKey();
  if (!key) {
    if (currentState != SYS_IDLE && (millis() - lastActivityTime > TIMEOUT_TIME)) showIdle();
    return;
  }
  wakeUpLCD(); lastActivityTime = millis(); beepStep();

  if (currentState == SYS_IDLE) {
    if (key == '*') { currentState = SYS_CHANGE_OLD; startInput("NHAP MK CU:"); }
    else { startInput("MAT KHAU:"); currentState = SYS_WAIT_PASSWORD; if (key >= '0' && key <= '9') { inputPassword += key; lcd.print("*"); } }
    return;
  }
  if (key == '*') { showIdle(); return; }
  if (key >= '0' && key <= '9' && inputPassword.length() < 4) {
    inputPassword += key;
    lcd.setCursor(inputPassword.length() + 1, 1); lcd.print("*");
  }
  if (key == '#') {
    if (inputPassword.length() < 4) return;
    if (currentState == SYS_WAIT_PASSWORD) {
      if (inputPassword == currentPass) { failCount = 0; unlock("password", "Ban Phim"); } 
      else {
        failCount++; beepError();
        publishStatus(true, "warning", "Sai mat khau", true); 
        if (failCount >= 3) { 
          currentState = SYS_LOCKED; lockStartTime = millis(); 
          lcd.clear(); lcd.print("TAM KHOA PHIM!"); 
          publishStatus(true, "warning", "Bi khoa 30s", true);
        } else { lcd.clear(); lcd.print("SAI MAT KHAU!"); delay(1500); startInput("MAT KHAU:"); }
      }
    }
    else if (currentState == SYS_CHANGE_OLD) {
      if (inputPassword == currentPass) { startInput("NHAP MK MOI:"); currentState = SYS_CHANGE_NEW; beepSuccess(); }
      else { 
        lcd.clear(); lcd.print("SAI MK CU!"); 
        publishStatus(true, "warning", "Doi MK fail", true);
        delay(1500); showIdle(); 
      }
    }
    else if (currentState == SYS_CHANGE_NEW) { tempPassword = inputPassword; startInput("XAC NHAN MK:"); currentState = SYS_CHANGE_CONFIRM; }
    else if (currentState == SYS_CHANGE_CONFIRM) {
      if (inputPassword == tempPassword) {
        currentPass = inputPassword;
        preferences.begin("lock-data", false); preferences.putString("password", currentPass); preferences.end();
        lcd.clear(); lcd.print("THANH CONG!"); 
        publishStatus(true, "change_password", "Ban Phim", true);
        beepSuccess(); delay(2000); showIdle();
      } else { lcd.clear(); lcd.print("KHONG KHOP!"); delay(1500); showIdle(); }
    }
  }
}

/* ================= SETUP ================= */
void setup() {
  Serial.begin(115200);
  pinMode(SOLENOID_PIN, OUTPUT); pinMode(BUZZER_PIN, OUTPUT); pinMode(BUTTON_PIN, INPUT_PULLUP);
  Wire.begin(21, 22); lcd.init(); lcd.backlight();
  preferences.begin("lock-data", true);
  currentPass = preferences.getString("password", "1236");
  preferences.end();
  SPI.begin(); rfid.PCD_Init();

  wifiMulti.addAP("NGUYEN ANH DUNG", "0378161956");
  wifiMulti.addAP("AnhMinh", "02060723");

  espClient.setInsecure();
  mqttClient.setServer(mqttServer, mqttPort);
  mqttClient.setCallback([](char* t, byte* p, unsigned int l){
    StaticJsonDocument<256> d; deserializeJson(d, p, l);
    String action = d["action"];
    
    if (action == "unlock") { 
      unlock("app", d["by"]); 
    }
    else if (action == "START_LEARNING") { 
      isLearningMode = true; 
      wakeUpLCD(); lcd.clear(); lcd.print("DANG CHO THE..."); beepSuccess(); 
    }
    else if (action == "ADD_CARD") {
        String cId = d["id"]; cId.toUpperCase();
        preferences.begin("rfid-cards", false); 
        preferences.putBool(cId.c_str(), true); 
        preferences.end();
        
        // Hiện duy nhất 1 thông báo: "đã thêm thẻ"
        publishAdminEvent("da_them_the", cId.c_str()); 
        beepSuccess(); showIdle();
    }
    else if (action == "REMOVE_CARD") {
        String cId = d["id"]; cId.toUpperCase();
        preferences.begin("rfid-cards", false); 
        preferences.remove(cId.c_str()); 
        preferences.end();
        
        // Hiện duy nhất 1 thông báo: "đã xóa thẻ"
        publishAdminEvent("da_xoa_the", cId.c_str()); 
        beepSuccess(); showIdle();
    }
  });
  showIdle(); 
}

/* ================= LOOP ================= */
void loop() {
  handleKeypad();
  handleRFID();
  if (digitalRead(BUTTON_PIN) == LOW) { delay(50); if(digitalRead(BUTTON_PIN) == LOW) unlock("button", "Nut Bam"); }
  maintainConnections();
  if (mqttClient.connected()) mqttClient.loop();
  if (isLCDBacklightOn && (millis() - lastLCDActivity > LCD_TIMEOUT)) { lcd.noBacklight(); isLCDBacklightOn = false; }
}