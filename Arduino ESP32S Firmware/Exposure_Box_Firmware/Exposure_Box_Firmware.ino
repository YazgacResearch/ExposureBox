//
//  Exposure Box
//

//  Following includes requried for ESP Brownout Control
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

#include <esp_int_wdt.h>
#include <esp_task_wdt.h>


#include <Time.h>

//  Bluetooth Serial
#include "BluetoothSerial.h"

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif

BluetoothSerial SBT;

//  Heart beat period 1 minutes
#define HEARTBEAT_RESET_PERIOD 60000

unsigned long StartTime;
unsigned long ElapsedTime;

#define SBT_BUFFER_WAIT_DELAY  150
#define SBT_TRANSMIT_DELAY  10
#define SBT_SEND_RECEIVE_DELAY 1

#define EXPOSURE_BOX_FIRMWARE_VERSION "1.0.1"

//
//  Protocol
//    Host ---> <Send Command> ---> Client
//    Host <--- <Received Response> <--- Client
//
//  Command Format:
//  <Command> ::= @<OpCode>;<Operand>
//  <OpCode>  ::= {Integer}
//  <Operand> ::= nil
//              | "<String>;
//              | #<Integer>;
//              | $<Float>;
//
//  Received Response Format
//  <Received Response> ::= !<String><Command Completed>
//  <String>            ::= nil
//                        | {Strring}
//  <Command Completed> ::= ;
//

#define COMMAND_PREFIX    "@"
#define UNKNOWN_PREFIX    "?"
#define UNKNOWN_RESPONSE  "?;"
#define RESPONSE_PREFIX   "!"
#define STRING_PREFIX     "\""
#define INTEGER_PREFIX    "#"
#define FLOAT_PREFIX      "$"
#define CMD_NOP       0
#define CMD_ECHO      1
#define CMD_RESET     2
#define CMD_VERSION   3
#define CMD_TOPBLACKLIGHT_ON     4
#define CMD_TOPBLACKLIGHT_OFF    5
#define CMD_BOTTOMBLACKLIGHT_ON  6
#define CMD_BOTTOMBLACKLIGHT_OFF 7
#define CMD_BOTTOMWHITELIGHT_ON  8
#define CMD_BOTTOMWHITELIGHT_OFF 9
#define CMD_TOPREDLIGHT_ON       10
#define CMD_TOPREDLIGHT_OFF      11
#define CMD_TOPANDBOTTOMBLACKLIGHT_ON     12
#define CMD_TOPANDBOTTOMBLACKLIGHT_OFF    13

String ReceivedString = "";
String CommandString = "";
unsigned int Command = 0;

const int BlueLedPin = 2;
const int TopLivePin = 33;
const int TopReturnPin = 32;
const int BottomLivePin = 13;
const int BottomReturnPin = 12;

const int BottomWhitePin = 26;
const int TopRedPin = 27;


void SBTClearBuffer() {
  while (SBT.available() > 0) {
    SBT.read();
  }
}

void SBTWaitBuffer() {
  while (SBT.available() == 0) {
    delayMicroseconds(SBT_BUFFER_WAIT_DELAY);
  }
}

String SBTReceiveString() {
  String S = "";

  SBTWaitBuffer();
  if (SBT.available() > 0) {
    do {
      S += (char)SBT.read(); //gets the string from serial buffer
      delayMicroseconds(SBT_BUFFER_WAIT_DELAY);
    } while (SBT.available() > 0);
  }
  return S;
}

void SBTSendString(String S) {
  SBTClearBuffer();
  SBT.print(S);
  SBT.flush();
  delay(SBT_SEND_RECEIVE_DELAY);
}

void TopBlackLightOn()
{
  digitalWrite(TopReturnPin, LOW);
//  delay(50);
  digitalWrite(TopLivePin, LOW);
//  delay(50);
}

void TopBlackLightOff()
{
  digitalWrite(TopReturnPin, HIGH);
//  delay(10);
  digitalWrite(TopLivePin, HIGH);
//  delay(10);
}

void BottomBlackLightOn()
{
  digitalWrite(BottomReturnPin, LOW);
//  delay(50);
  digitalWrite(BottomLivePin, LOW);
//  delay(50);
}

void BottomBlackLightOff()
{
  digitalWrite(BottomReturnPin, HIGH);
//  delay(10);
  digitalWrite(BottomLivePin, HIGH);
//  delay(10);
}

void TopAndBottomBlackLightOn()
{
  TopBlackLightOn();
  BottomBlackLightOn();
}

void TopAndBottomBlackLightOff()
{
  TopBlackLightOff();
  BottomBlackLightOff();
}

void BottomWhiteLightOn()
{
  digitalWrite(BottomWhitePin, LOW);
//  delay(10);
}

void BottomWhiteLightOff()
{
  digitalWrite(BottomWhitePin, HIGH);
//  delay(10);
}

void TopRedLightOn()
{
  digitalWrite(TopRedPin, LOW);
//  delay(10);
}

void TopRedLightOff()
{
  digitalWrite(TopRedPin, HIGH);
//  delay(10);
}

void ESP_hard_restart() {
  esp_task_wdt_init(1, true);
  esp_task_wdt_add(NULL);
  while (true);
}

void ESP_reset_pins()
{
  pinMode(BlueLedPin, INPUT);

  pinMode(TopLivePin, INPUT);
  pinMode(TopReturnPin, INPUT);
  pinMode(BottomLivePin, INPUT);
  pinMode(BottomReturnPin, INPUT);
  pinMode(BottomWhitePin, INPUT);
  pinMode(TopRedPin, INPUT);
}

void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0); //disable brownout detector
  //  system_update_cpu_freq(SYS_CPU_160MHZ);
  Serial.begin(115200);
  SBT.begin("Exposure Box"); //Bluetooth device name
  Serial.println("The device started, now you can pair it with bluetooth!");
  Serial.println("Brown out Enabled!");

  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 1); //enable brownout detector

  //  Wait for Pairing
  while (!SBT.hasClient()) {
    delay(1000);
  }
  //  Set Bluetooth Ready
  if (SBT.hasClient()) {
    pinMode(BlueLedPin, OUTPUT);
    digitalWrite(BlueLedPin, HIGH); // Bluetooth Ready
  }

  pinMode(TopLivePin, OUTPUT);
  pinMode(TopReturnPin, OUTPUT);
  pinMode(BottomLivePin, OUTPUT);
  pinMode(BottomReturnPin, OUTPUT);
  pinMode(BottomWhitePin, OUTPUT);
  pinMode(TopRedPin, OUTPUT);

  digitalWrite(TopLivePin, HIGH);
  digitalWrite(TopReturnPin, HIGH);
  digitalWrite(BottomLivePin, HIGH);
  digitalWrite(BottomReturnPin, HIGH);
  digitalWrite(BottomWhitePin, HIGH);
  digitalWrite(TopRedPin, HIGH);

  //  Heartbeat
  StartTime = millis();
}

void DropCommand()
{
  ReceivedString.remove(0, ReceivedString.indexOf(';') + 1);
}

unsigned int ParseCommand()
{
  if ( ReceivedString.startsWith(COMMAND_PREFIX) ) {
    CommandString = ReceivedString.substring(1,  ReceivedString.indexOf(';'));
    if (CommandString.length() > 0) {
      return CommandString.toInt();
    } else {
      return 0;
    }
  }
}

void Response(String RS)
{
  SBTSendString(RESPONSE_PREFIX + RS + ";");
}

void loop() {
  //  Check HeartBeat
  ElapsedTime = millis();
  ElapsedTime -= StartTime;
  if (ElapsedTime > HEARTBEAT_RESET_PERIOD) {
    Serial.println("Heartbeat Lost.. Reseting..");
    ESP_reset_pins();
    ESP_hard_restart();
    delay(20);
  }
  if (ReceivedString.length() > 0) {
    if ( ReceivedString.startsWith(COMMAND_PREFIX) ) {
      Command = ParseCommand();
      switch (Command ) {
        case CMD_NOP:
          // HeartBeat Signal
          // Reset HeartBeat Period
          StartTime = millis();
          Response("");
          break;
        case CMD_ECHO:
          //  Echo : Send to Bluetooth
          Response("<" + ReceivedString + ">");
          break;
        case CMD_RESET:
          // Restarts & Socket Closed
          Serial.println("RESET SENS");
          Response("");
          ESP_reset_pins();
          ESP_hard_restart();
          delay(20);
          //        ESP.restart();
          break;
        case CMD_VERSION:
          //  Send Version String
          Response(EXPOSURE_BOX_FIRMWARE_VERSION);
          break;
        case CMD_TOPBLACKLIGHT_ON:
          TopBlackLightOn();
          Response("");
          break;
        case CMD_TOPBLACKLIGHT_OFF:
          TopBlackLightOff();
          Response("");
          break;
        case CMD_BOTTOMBLACKLIGHT_ON:
          BottomBlackLightOn();
          Response("");
          break;
        case CMD_BOTTOMBLACKLIGHT_OFF:
          BottomBlackLightOff();
          Response("");
          break;
        case CMD_BOTTOMWHITELIGHT_ON:
          BottomWhiteLightOn();
          Response("");
          break;
        case CMD_BOTTOMWHITELIGHT_OFF:
          BottomWhiteLightOff();
          Response("");
          break;
        case CMD_TOPREDLIGHT_ON:
          TopRedLightOn();
          Response("");
          break;
        case CMD_TOPREDLIGHT_OFF:
          TopRedLightOff();
          Response("");
          break;        
        case CMD_TOPANDBOTTOMBLACKLIGHT_ON:
          TopAndBottomBlackLightOn();
          Response("");
          break;
        case CMD_TOPANDBOTTOMBLACKLIGHT_OFF:
          TopAndBottomBlackLightOff();
          Response("");
          break;
        default:
          // invalid Command, Ignore & Continue
          SBTSendString(UNKNOWN_RESPONSE);
          break;
      }
      ReceivedString = "";
      CommandString = "";
    } else {
      ReceivedString = "";
      CommandString = "";
      SBTSendString(UNKNOWN_RESPONSE);
    }
  } else {
    if (SBT.available()) {
      ReceivedString = SBTReceiveString();
      if ( !ReceivedString.endsWith(";") ) {
        ReceivedString += ";";
      }
    } else {
      delay(10);
    }
  }
}
