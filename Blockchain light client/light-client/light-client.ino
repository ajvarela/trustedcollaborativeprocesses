#include <ArduinoJson.h>
#include <BluetoothSerial.h>
#include <esp_bt_device.h>
#include <stdlib.h>
#include <time.h>
#include <Web3.h>
#include <WiFi.h>
#include "Contract.h"
#include "Util.h"

#define USE_SERIAL Serial

#define ENV_SSID "" // To define
#define ENV_WIFI_KEY "" // To define

#define ENDPOINT_HOST "" // To define
#define ENDPOINT_PATH "" // To define

#define CONTRACT_ADDRESS "" // To define
#define MY_ADDRESS "" // To define

BluetoothSerial BT;

bool busyBT = false;
int randomNum = 0;
const char* ntpServer = "pool.ntp.org";
unsigned epochTime;

const char PRIVATE_KEY[] = {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                            0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                            0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                            0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 }; // To define

const string vehicleId = "CC:50:E3:80:C8:3A"; // Example for testing

Web3 web3_client(new std::string(ENDPOINT_HOST), new std::string( ENDPOINT_PATH));

Contract setup_contract();
void get_function(Contract contract, string func, string funcParam);
void create_transaction(Contract contract, string dni, string vehicleId, int transactionType);

void setup() {
  USE_SERIAL.begin(115200);

  for (uint8_t t = 4; t > 0; t--) {
    USE_SERIAL.printf("[SETUP] WAIT %d...\n", t);
    USE_SERIAL.flush();
    delay(1000);
  }

  WiFi.mode(WIFI_STA);
 
  WiFi.begin(ENV_SSID, ENV_WIFI_KEY);
  
  while (WiFi.status() != WL_CONNECTED) {
    USE_SERIAL.print(".");
    delay(1000);
  }
  
  USE_SERIAL.println(F("Connected"));

  configTime(0, 0, ntpServer);

  if(!BT.begin("bicycle32")){
    USE_SERIAL.println(F("An error occurred initializing Bluetooth"));
  }
  else {
    USE_SERIAL.println(F("Bluetooth device is ready for pairing"));
    printDeviceAddress();
  }

  BT.flush();  
  BT.disconnect();
}

void loop() {
  if (BT.available()) {
    if (busyBT == false) {
      busyBT = true;
      
      String incoming = BT.readStringUntil('\n');
      USE_SERIAL.print(F("Received data: "));
      USE_SERIAL.println(incoming);
      
      const size_t capacity = JSON_OBJECT_SIZE(2) + 180;
      DynamicJsonDocument doc(capacity);
    
      deserializeJson(doc, incoming);
    
      bool dataValid = true;
      if (!doc["dni"].is<string>() || !doc["transactionType"].is<int>()) {
        dataValid = false;
      }
      
      string dni = "";
      int transactionType = 0;
    
      if (dataValid) {
        dni = doc["dni"].as<string>();
    
        transactionType = doc["transactionType"].as<int>();
        if (!(transactionType == 0 || transactionType == 1)) dataValid = false;
      }
    
      if (!dataValid) {
        USE_SERIAL.println(F("ERROR: Invalid data"));
        BT.println("ERROR: Invalid data");
      }
      else {
        const char* response = "OK";
        int localRandom = esp_random();

        if (localRandom < 0) {
          localRandom = localRandom * -1;
        }
      
        char *num;
        char responseBuffer[100];
      
        if (asprintf(&num, "[%d]", localRandom) == -1) {
            perror("asprintf");
        } else {
            strcat(strcpy(responseBuffer, response), num);
            free(num);
        }
        
        USE_SERIAL.println(responseBuffer);
        BT.println(responseBuffer);

        BT.flush();  
        BT.disconnect();
        BT.end();

        Contract contract = setup_contract();
        create_transaction(contract, dni, vehicleId, transactionType);

        randomNum = localRandom;
      }

      if (randomNum == 0) {
        BT.flush();  
        BT.disconnect();

        busyBT = false;
      }
      else {
        if(!BT.begin("bicycle32")){
          USE_SERIAL.println(F("An error occurred initializing Bluetooth"));
        }
        else {
          USE_SERIAL.println(F("Bluetooth device is ready for pairing"));
          printDeviceAddress();
        }
      }
    }
    else {
      if (randomNum == 0) {
        USE_SERIAL.println(F("ERROR: Service unavailable"));
        BT.println("ERROR: Service unavailable");
      }
      else {
        int incoming = atoi(BT.readStringUntil('\n').c_str());
        USE_SERIAL.printf("Received number: %d\n", incoming);

        if (incoming == randomNum) {
          USE_SERIAL.println(F("OK: The transaction has been sent successfully"));
          BT.println("OK: The transaction has been sent successfully");
  
          BT.flush();  
          BT.disconnect();
  
          randomNum = 0;
          busyBT = false;
        }
      }
    }
  }
}

Contract setup_contract() {
  Contract contract(&web3_client, new std::string(CONTRACT_ADDRESS));
  strcpy(contract.options.from, MY_ADDRESS);
  strcpy(contract.options.gasPrice, "2000000000000000");
  contract.options.gas = 5000000;

  return contract;
}

void create_transaction(Contract contract, string dni, string vehicleId, int transactionType) {
  contract.SetPrivateKey((uint8_t*)PRIVATE_KEY);
  uint32_t nonceVal = (uint32_t)web3_client.EthGetTransactionCount(new std::string(MY_ADDRESS));

  uint32_t gasPriceVal = 15000000000;
  uint32_t  gasLimitVal = 10000000;
  std::string toStr(CONTRACT_ADDRESS);
  std::string valueStr("0x00");
  uint8_t dataStr[100];
  memset(dataStr, 0, 100);

  epochTime = getTime();
  
  string func = "createTransaction(string,string,uint32,uint256)";
  string param = contract.SetupContractData(&func, &dni, &vehicleId, transactionType, epochTime);
  
  USE_SERIAL.println(F("Transaction:"));
  string result = contract.SendTransaction(nonceVal, gasPriceVal, gasLimitVal, &toStr, &valueStr, &param);
  USE_SERIAL.println(F("Result:"));
  USE_SERIAL.println(result.c_str());
}

void get_function(Contract contract, string func, string funcParam) {
  string param = "";
  
  if (funcParam == "") {
      param = contract.SetupContractData(&func);
  }
  else {
      param = contract.SetupContractData(&func, &funcParam);
  }
  
  string result = contract.Call(&param);
  
  USE_SERIAL.println("result");
  USE_SERIAL.println(result.c_str());
}

void printDeviceAddress() {
  const uint8_t* point = esp_bt_dev_get_address();
  USE_SERIAL.print(F("BT MAC address: "));
 
  for (int i = 0; i < 6; i++) {
    char str[3];
 
    sprintf(str, "%02X", (int)point[i]);
    USE_SERIAL.print(str);
 
    if (i < 5){
      USE_SERIAL.print(":");
    }
  }
  
  USE_SERIAL.print("\n");
}

unsigned long getTime() {
  time_t now;
  struct tm timeinfo;
  
  if (!getLocalTime(&timeinfo)) {
    USE_SERIAL.println(F("Failed to obtain time"));
    return(0);
  }
  
  time(&now);
  
  return now;
}

int hex_to_int(string hex) {
  char * pEnd;
  long int res;
  res = strtol (hex.c_str(), &pEnd, 0);

  return res;
}
