// ##############################################################################################################################################################################
// ##############################################################################################################################################################################
// ### ESP8266 SmartSwitch                 ######################################################################################    ############################################
// ### Program to control rollershutter    ######################################################################################  #  ###########################################
// ### Copyright © 2019, Andreas S. Köhler ######################################################################################  #  ###########################################
// ###                                                                        ##################################################  ###  ##########################################
// ### This program is free software: you can redistribute it and/or modify   ##################################################  ###  ##########################################
// ### it under the terms of the GNU General Public License as published by   ###################                     ###   ####  ####                        ###################
// ### the Free Software Foundation, either version 3 of the License, or      ######################################  ###    ###  ###############################################
// ### (at your option) any later version.                                    ###################  ########  #######  ###  #  #  ####       ###########  ########################
// ###                                                                        ###################  ######  ##################    ##  #######  #######  ##  ######################
// ### This program is distributed in the hope that it will be useful,        ###################  ####  ############     ####  ##  #########  ######  ##  ######################
// ### but WITHOUT ANY WARRANTY; without even the implied warranty of         ###################  ##  ###########  #######  ######  ###############  ####  #####################
// ### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          ###################    ############  #########  ########      ########  ####  #####################
// ### GNU General Public License for more details.                           ###################  ##  ##########  #########  ##############  #####          ####################
// ###                                                                        ###################  ####  ########  #########  ####  #########  ####  ######  ####################
// ### You should have received a copy of the GNU General Public License      ###################  ######  #######  #######  ######  #######  ####  ########  ###################
// ### along with this program.  If not, see <http://www.gnu.org/licenses/>.  ###################  ########  ########     ###########       ######  ########  ###################
// ##############################################################################################################################################################################
// ##############################################################################################################################################################################

// ##############################################################################################################################################################################
// ### Functions of SmartSwitch                                                                                                                                               ###
// ###                                                                                                                                                                        ###
// ###                                                                                                                                                                        ###
// ### + Built-in Enduser Setup to setup WiFi settings (initial operation)                                                                                                    ###
// ###   Configuration of MQTT-Broker-IP and Usage-Site also via Enduser Setup possible                                                                                       ###
// ###                                                                                                                                                                        ###
// ### + Built-in MQTT-Client                                                                                                                                                 ###
// ###   - MQTT-Topics:                                                                                                                                                       ###
// ###     * /SmartSwitch/<name/MAC>/status/position/      => Publish:   Actual position (in percent) of shutter                                                               ###
// ###     * /SmartSwitch/<name/MAC>/status/rssi/          => Publish:   RSSI of connected Accesspoint in dBm                                                                  ###
// ###     * /SmartSwitch/<name/MAC>/command/              => Subscribe: Subscribe-Topic of the Module                                                                         ###
// ###   - Instructionset:                                                                                                                                                    ###
// ###     * /UP:             => Opens the shutter completely                                                                                                                 ###
// ###     * /DOWN:           => Closes the shutter completely                                                                                                                ###
// ###     * /STOP:           => Stops the shutter at current position and publish act. position of shutter and RSSI of AP via MQTT                                           ###
// ###     * /TEACH:          => Starts Teaching-Mode to teach time to completely open/close shutter                                                                          ###
// ###     * /STATUS:         => Publishes act. position of shutter and RSSI of connected AP via MQTT                                                                         ###
// ###     * /MANUAL_START:   => Starts Manual-Mode (Shutter can be moved without any restictions                                                                             ###
// ###     * /MANUAL_STOP:    => Stops Manual-Mode                                                                                                                            ###
// ###     * /<%-Value>:      => Moves Shutter to percentage position                                                                                                         ###
// ###                                                                                                                                                                        ###
// ### + Operation via Push-Buttons                                                                                                                                           ###
// ###   - Short push:            Move shutter in corresponding End-Position                                                                                                  ###
// ###   - Long push:             Move shutter as long as button is pushed (> 1s)                                                                                             ###
// ###   - Push during movement:  Stops motor (also if MQTT-Instruction was received during motion)                                                                           ###
// ###                                                                                                                                                                        ###
// ### + Built-in Arduino OTA flashing interface (Firmwareupdate via WiFi)                                                                                                    ###
// ##############################################################################################################################################################################

// *** Needed Libraries *********************************************************************************************************************************************************
#include <ESP8266WiFi.h>                                                              // Library for ESP8266
#include <WiFiClient.h>                                                               // Library for WiFi-Client
#include <EEPROM.h>                                                                   // Library for EEPROM-Usage
#include <WiFiManager.h>                                                              // Library for WiFi-Manager
#include <ArduinoOTA.h>                                                               // Library for OTA-Updating
#include <ESP8266mDNS.h>                                                              // Library for mDNS-Usage
#include <WiFiUdp.h>                                                                  // Library for UDP-Communication
#include <PubSubClient.h>                                                             // Library for MQTT-Handling
extern "C" {
  #include "user_interface.h"                                                         // Include Espressif Library
}
// *** Needed Variables *********************************************************************************************************************************************************
String MQTT_name;                                                                     // Variable (String) to store name of MQTT-Client
char MQTT_name_char[128];                                                             // Name (Char) to connect MQTT-Client with broker
String hostname;                                                                      // Variable for Name of Module (part of MQTT-Topic, either IP of module or stored site) 
String topic = "/SmartSwitch/";                                                       // First part of MQTT-Topic for publishing                *** Part of MQTT-Topic for publishing ***
int WiFiManagerTimeout = 180;                                                         // Define Timeout for Wifi-Manager and set it to 180s     *** Timeout for WiFi-Manager          ***
char MQTT_BROKER[40] = "192.168.2.115";                                               // Preset IP of MQTT-Broker                               *** Preset-IP of MQTT-Broker          ***
bool wifiFirstConnected = false;                                                      // Flag for first WiFi connection
int cf = 0;                                                                           // WiFi Connection flag
String ausgabe;                                                                       // Variable for MQTT-Message
String top;                                                                           // Variable to combine Strings for Topic-String
char hostname_char[140];                                                              // Variable for MQTT-Hostname
bool shouldSaveConfig = false;                                                        // Flag for saving MQTT-Config
char site[128];                                                                       // Variable for Usage-Site
char broker[40];                                                                      // Variable for MQTT-Broker address
char MQTTget_message[128];                                                            // Variable for incoming MQTT-Messages
String MQTTget_topic;                                                                 // Variable for topic of incoming MQTT-Messages
unsigned long lastReconnectAttempt = 0;                                               // Timer-Variable for MQTT-Reconnection
bool newMQTTmessage = false;                                                          // Flag if new MQTT-Message is avaliable
bool drive = false;                                                                   // Flag if shutter is in motion 
bool manual_flag = false;                                                             // Flag for manual motion
unsigned int down_time = 0;                                                           // Variable for teached Down-Time
unsigned int up_time = 0;                                                             // Variable for teached Up-Time
float pos = 0;                                                                        // Variable for actual position
float pos_fb = 0;                                                                     // Variable to calculate position to be feedbacked to MQTT-Network
unsigned long MovedTime = 0;                                                          // Variable for time, beeing in motion
unsigned long StartMoveTime = 0;                                                      // Variable for Motion-Start-Time
unsigned long StartPosCalcTime = 0;                                                   // Variable for Start-Time to calcualte position
bool moving_up = false;                                                               // Flag for Up-Movement
bool moving_down = false;                                                             // Flag for Down-Movement
bool teach_flag = false;                                                              // Flag for Teaching-Mode
bool percentage = false;                                                              // Flag for motion according percentage target value
int delta = 0;                                                                        // Variable for Position-Delta (now/target)
int soll = 0;                                                                         // Variable for target position
bool up_pressed = false;                                                              // Flag if UP was pressed
bool down_pressed = false;                                                            // Flag if DOWN was pressed
unsigned long LastTime = 0;                                                           // Variable to store last time of meassurement
unsigned long CurrentTime = 0;                                                        // Variable to store actual time
unsigned long interval = 1000;                                                        // Variable to store interval of MQTT-Connection-Check    *** Interval of MQTT-Check   ***
// *** Needed IOs ***************************************************************************************************************************************************************
#define IO_I1 12                                                                      // Map IO_I1 (Input: UP) to GPIO12
#define IO_I2 13                                                                      // Map IO_I2 (Input: DOWN) to GPIO13
#define IO_O1 4                                                                       // Map IO_O1 (Relais: DIRECTION) to GPIO4
#define IO_O2 5                                                                       // Map IO_O2 (Relais: POWER) to GPIO5
// *** Needed Services **********************************************************************************************************************************************************
WiFiClient espClient;                                                                 // Create a WiFi-Client
PubSubClient client(espClient);                                                       // Create a PubSubClient-Object (MQTT)

// ##############################################################################################################################################################################
// ### Calback for Wifi got IP ##################################################################################################################################################
// ##############################################################################################################################################################################
void onSTAGotIP (WiFiEventStationModeGotIP ipInfo) {                                  // Callback if WiFi connection is established and IP gotten
  wifiFirstConnected = true;                                                          // Set flag
}

// ##############################################################################################################################################################################
// ### Callback for MQTT-Message get ############################################################################################################################################
// ##############################################################################################################################################################################
void mqtt_callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message arrived [");                                                  // Debug printing Topic
  Serial.print(topic);
  Serial.print("]: ");
  for (int i = 0; i < 128; i++) {                                                     // Initialize Char-Array for new message
    MQTTget_message[i] = 0;                                                           // Make it empty
  }
  for (int i = 0; i < length; i++) {                                                  // For lenght of new MQTT-Message
    MQTTget_message[i] = (char)payload[i];                                            // Get payload of MQTT-Message to Char-Array
    Serial.print((char)payload[i]);                                                   // Debug printing
  }
  Serial.println();
  MQTTget_topic = topic;                                                              // Store MQTT-Topic to variable
  newMQTTmessage = true;                                                              // Set flag for new MQTT-Message
}

// ##############################################################################################################################################################################
// ### If MQTT-Client isn't connected => reconnect! #############################################################################################################################
// ##############################################################################################################################################################################
boolean reconnect() {
  MQTT_name = "SmartSwitch_" + String(WiFi.macAddress());                             // Define name of MQTT-Client (SmartSwitch_XX:XX:XX:XX:XX:XX:XX:XX)
  if (client.connect(MQTT_name.c_str())) {                                            // Connect to MQTT-Broker
    ausgabe = "Connected";                                                            // Build strings to send to MQTT-Broker and send it
    top = topic + hostname_char + "/status/";                                         // Built topic to sent message to
    client.publish(top.c_str(), ausgabe.c_str());                                     // Publish MQTT-Message
    top = topic + hostname_char + "/command/";                                        // Built topic to sent message to
    Serial.println("TOPIC: " + top);                                                  // Debug printing
    client.subscribe(top.c_str());                                                    // Subscribe to MQTT-Topic
    return true;                                                                      // If connection is established, return true
  } else {
    Serial.print("failed, rc=");                                                      // In case of no connection:
    Serial.println(client.state());                                                   // Debug print
    return false;                                                                     // If connection isn't established, return false
  }
}

// ##############################################################################################################################################################################
// ### Callback for Wifi Config Mode ############################################################################################################################################
// ##############################################################################################################################################################################
void configModeCallback (WiFiManager *myWiFiManager) {                                // Callback if WiFi-Manager enters config mode
    Serial.println("Entered config mode");                                            // Debug printing
    Serial.println(WiFi.softAPIP());
    Serial.println(myWiFiManager->getConfigPortalSSID());
}

// ##############################################################################################################################################################################
// ### Callback for to save parameters from WIFI-Manager ########################################################################################################################
// ##############################################################################################################################################################################
void saveConfigCallback () {
  Serial.println("Should save config");                                               // Debug printing
  shouldSaveConfig = true;                                                            // Set flag to store config (MQTT)
}

// ##############################################################################################################################################################################
// ### Setup Routine ############################################################################################################################################################
// ##############################################################################################################################################################################
void setup() {
// *** Initialize IO-Pins *******************************************************************************************************************************************************
  pinMode(IO_I1, INPUT);                                                              // Set IO_I1 as Input-Pin
  pinMode(IO_I2, INPUT);                                                              // Set IO_I2 as Input-Pin
  pinMode(IO_O1, OUTPUT);                                                             // Set IO_O1 as Output-Pin
  pinMode(IO_O2, OUTPUT);                                                             // Set IO_O2 as Output-Pin
  digitalWrite(IO_O1, LOW);                                                           // Set IO_O1 LOW
  digitalWrite(IO_O2, LOW);                                                           // Set IO_O2 LOW
// *** Read initial values from EEPROM ******************************************************************************************************************************************  
  EEPROM.begin(4095);                                                                 // Define EEPROM
  EEPROM.get(50, site);                                                               // Get site from EEPROM
  EEPROM.get(1000, broker);                                                           // Get Broker-IP from EEPROM
  EEPROM.get(10, down_time);                                                          // Get Down-Time from EEPROM
  EEPROM.get(20, up_time);                                                            // Get UP-Time from EEPROM
  EEPROM.get(30, pos);                                                                // Get Position from EEPROM
  EEPROM.end();                                                                       // Free memory
  if (site == "" || (String(site).length() > 100)) {                                  // If EEPROM (site) empty or flushed with nonsence
    hostname = "SmartSwitch_" + String(WiFi.macAddress());                            // Networkname of Module (Identifier: MAC)
    String empty = "";                                                                // Initialize empty string
    empty.toCharArray(site, 128);                                                     // Store empty string to char "site"
    empty.toCharArray(broker, 40);                                                    // Store empty string to char "broker"
  } else {
    hostname = "SmartSwitch_" + String(site);                                         // Networkname of Module (Identifier: site)
  }
  if (isnan(down_time)) {                                                             // Check if EEPROM-Content "down_time" is not a number
    Serial.println("NAN: down_time!");                                                // Debug printing
    down_time = 0;                                                                    // Set down_time to 0
    EEPROM.begin(4095);                                                               // Define EEPROM
    EEPROM.put(10, down_time);                                                        // Write "down_time" to EEPROM
    delay(200);                                                                       // Delay
    EEPROM.commit();                                                                  // Only needed for ESP8266 to get data written
    EEPROM.end();                                                                     // Free RAM copy of structure
  }
  if (isnan(up_time)) {                                                               // Check if EEPROM-Content "up_time" is not a number
    Serial.println("NAN: up_time!");                                                  // Debug printing
    up_time = 0;                                                                      // Set up_time to 0
    EEPROM.begin(4095);                                                               // Define EEPROM
    EEPROM.put(20, up_time);                                                          // Write "up_time" to EEPROM
    delay(200);                                                                       // Delay
    EEPROM.commit();                                                                  // Only needed for ESP8266 to get data written
    EEPROM.end();                                                                     // Free RAM copy of structure
  }
  if (isnan(pos)) {                                                                   // Check if EEPROM-Content "pos" is not a number
    Serial.println("NAN: pos!");                                                      // Debug printing
    pos = 0.0;                                                                        // Set pos to 0.0
    EEPROM.begin(4095);                                                               // Define EEPROM
    EEPROM.put(30, pos);                                                              // Write "pos" to EEPROM
    delay(200);                                                                       // Delay
    EEPROM.commit();                                                                  // Only needed for ESP8266 to get data written
    EEPROM.end();                                                                     // Free RAM copy of structure
  }
  
// *** Initialize WiFi-Event-Handler ********************************************************************************************************************************************
  static WiFiEventHandler e1;                                                         // Define WiFi-Handler
  e1 = WiFi.onStationModeGotIP (onSTAGotIP);                                          // As soon WiFi is connected, start NTP Client
// *** Initialize serial comunication *******************************************************************************************************************************************
  Serial.begin(9600);                                                                 // Begin serial communication
// *** Initialize WiFi **********************************************************************************************************************************************************
  delay(3000);                                                                        // Delay 3s
  hostname.toCharArray(hostname_char, 140);                                           // Transfer string "hostname" to char
  //wifi_station_set_hostname(hostname_char);                                         // Set station hostname
  WiFiManagerParameter custom_site("site", "Einsatzort", site, 128);                  // Define WIFI-Manager parameter "site"
  WiFiManagerParameter custom_broker("boker", "MQTT-Borker", broker, 40);             // Define WIFI-Manager parameter "broker"
  WiFiManager wifiManager;                                                            // Define WiFi Manager
  wifiManager.setSaveConfigCallback(saveConfigCallback);                              // Set callback in case, parameters should be saved
  wifiManager.addParameter(&custom_site);                                             // Add parameters to WIFI-Manager
  wifiManager.addParameter(&custom_broker);
  wifiManager.setAPCallback(configModeCallback);                                      // Definition of callback for AP-Mode
  wifiManager.setConfigPortalTimeout(WiFiManagerTimeout);                             // Definition of timeout for AP-Mode
  if (!wifiManager.autoConnect(hostname_char)) {                                      // Start WiFi-Manager and check if connection is established, if not:
    Serial.println("Failed to connect and reboot");                                   // Debug printing
    delay(3000);                                                                      // Wait 3s
    ESP.restart();                                                                    // Software reset ESP
    delay(5000);                                                                      // Wait 5s
  }
  if (shouldSaveConfig) {                                                             // If config in WIFI-Manager has changed
    strcpy(site, custom_site.getValue());                                             // Get "site" from WIFI-Manager
    strcpy(broker, custom_broker.getValue());                                         // Get "broker" from WIFI-Manager
    EEPROM.begin(4095);                                                               // Define EEPROM
    EEPROM.put(50, site);                                                             // Write "site" to EEPROM
    EEPROM.put(1000, broker);                                                         // Write "broker" to EEPROM
    delay(200);                                                                       // Delay
    EEPROM.commit();                                                                  // Only needed for ESP8266 to get data written
    EEPROM.end();                                                                     // Free RAM copy of structure
    hostname = "SmartSwitch_" + String(site);                                         // Build hostname
    hostname.toCharArray(hostname_char, 140);                                         // Transfer string "hostname" to char
  }
  memcpy(MQTT_BROKER, broker, sizeof(broker));                                        // Transfer "broker" to "MQTT-BROKER"
  IPAddress addr;                                                                     // Declare variable for IP-Address
  if (!addr.fromString(MQTT_BROKER)) {                                                // Check if MQTT-BROKER is a valid IP
    String ip_string = "192.168.2.115";                                               // If not, switch to Standard-IP
    ip_string.toCharArray(MQTT_BROKER, 40);                                           // Store Standard-IP to Char-Array
  }
  wifi_station_set_hostname(hostname_char);                                           // Set station hostname
// *** Serial printing status ***************************************************************************************************************************************************
  Serial.print("\n  Connecting to WiFi ");                                            // Debug printing
  Serial.println("\n\nWiFi connected.");                                              // Debug printing
  cf = 1;                                                                             // Set WiFi Conection Flag
  Serial.print("  IP address: " + WiFi.localIP().toString() + "\n");                  // Debug printing
  Serial.print("  Host name:  " + String(hostname) + "\n");
  Serial.print("- - - - - - - - - - - - - - - - - - -\n\n");
  delay(3000);                                                                        // Wait 3s
// *** OTA-Initialisation *******************************************************************************************************************************************************  
  ArduinoOTA.setHostname(hostname_char);                                              // Set Hostname for OTA-Mode
  ArduinoOTA.onStart([]() {                                                           // OTA-Event onStart
    String type;                                                                      // Define string "type"
    if (ArduinoOTA.getCommand() == U_FLASH) {                                         // Dependent on flashtype
      type = "sketch";                                                                // Set type "sketch"
    } else { // U_SPIFFS
      type = "filesystem";                                                            // Set type "filesystem"
    }
    Serial.println("Start updating " + type);                                         // Debug print type
  });
  ArduinoOTA.onEnd([]() {                                                             // OTA-Event onEnd
    Serial.println("\nEnd");                                                          // Debug printing
  });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {               // OTA-Event onProgress
    Serial.printf("Progress: %u%%\r", (progress / (total / 100)));                    // Debug print
  });
  ArduinoOTA.onError([](ota_error_t error) {                                          // OTA-Event onError
    Serial.printf("Error[%u]: ", error);                                              // Debug print errornumber
    if (error == OTA_AUTH_ERROR) {                                                    // Dependent on errornumber
      Serial.println("Auth Failed");                                                  // Print error type
    } else if (error == OTA_BEGIN_ERROR) {
      Serial.println("Begin Failed");
    } else if (error == OTA_CONNECT_ERROR) {
      Serial.println("Connect Failed");
    } else if (error == OTA_RECEIVE_ERROR) {
      Serial.println("Receive Failed");
    } else if (error == OTA_END_ERROR) {
      Serial.println("End Failed");
    }
  });
  ArduinoOTA.begin();                                                                 // Start OTA
// *** Initialize MQTT ********************************************************************************************************************************************************
  client.setServer(MQTT_BROKER, 1883);                                                // Start MQTT-Client
  client.setCallback(mqtt_callback);                                                  // Set MQTT-Callback to handle incoming messages
  lastReconnectAttempt = 0;
}

// ##############################################################################################################################################################################
// ### Routine to check if a String contains only numbers #######################################################################################################################
// ##############################################################################################################################################################################
boolean isNumeric(String str) {
    unsigned int stringLength = str.length();                                         // Get length of String
    if (stringLength == 0) {                                                          // If length = 0 return FALSE
        return false;
    }
    boolean seenDecimal = false;                                                      // Flag, if ther is a decimal number
    for(unsigned int i = 0; i < stringLength; ++i) {                                  // Check whole string
        if (isDigit(str.charAt(i))) {                                                 // If character is digit
            continue;                                                                 // Continue
        }
        if (str.charAt(i) == '.') {                                                   // If character is "."
            if (seenDecimal) {                                                        // If already "." was seen, return FALSE
                return false;
            }
            seenDecimal = true;                                                       // If it's the first occurence of "." set sennDecimal flag
            continue;                                                                 // Continue
        }
        return false;                                                                 // If character is any other character return FALSE
    }
    return true;                                                                      // If string is a integer or float return TRUE
}

// ##############################################################################################################################################################################
// ### Move shutter up ##########################################################################################################################################################
// ##############################################################################################################################################################################
void moveUp() {
  MovedTime = millis();                                                               // Get Start-Time of movement
  digitalWrite(IO_O2, LOW);                                                           // Reset IO_O2 Relais (set direction UP)
  delay(200);                                                                         // Delay 200ms
  digitalWrite(IO_O1, HIGH);                                                          // Set IO_O1 Relais (power on motor)
}

// ##############################################################################################################################################################################
// ### Move shutter down ########################################################################################################################################################
// ##############################################################################################################################################################################
void moveDown() {
  MovedTime = millis();                                                               // Get Start-Time of movement
  digitalWrite(IO_O2, HIGH);                                                          // Set IO_O2 Relais (set direction DOWN)
  delay(200);                                                                         // Delay 200ms
  digitalWrite(IO_O1, HIGH);                                                          // Set IO_O1 Relais (power on motor)
}

// ##############################################################################################################################################################################
// ### Stop shutter movement ####################################################################################################################################################
// ##############################################################################################################################################################################
void motionStop() {
  digitalWrite(IO_O2, LOW);                                                           // Reset IO_O2 (power off relais)
  delay(200);                                                                         // Delay 200ms
  digitalWrite(IO_O1, LOW);                                                           // Reset IO_O1 (power off relais)
  MovedTime = MovedTime - millis();                                                   // Calculate, how long motor was moving
  if (pos_fb > 100) {                                                                 // Position will be calculated during complete motion
    pos_fb = 100;                                                                     // so values <0 and >100 are possible (time-safeness to open/close completely)
  }                                                                                   // but feedbacked position must between 0 and 100
  if (pos_fb < 0) {                                                                   // so if value out of range
    pos_fb = 0;                                                                       // set it into range
  }
  pos = pos_fb;                                                                       // Set actual position to calculated position
  ausgabe = String(pos);                                                              // Build strings to send to MQTT-Broker and send it
  top = topic + hostname_char + "/status/position/";                                  // Built topic to sent message to
  client.publish(top.c_str(), ausgabe.c_str());                                       // Publish MQTT-Message
  long rssi = WiFi.RSSI();                                                            // Get RSSI of WiFi-Connection
  ausgabe = String(rssi);                                                             // Build strings to send to MQTT-Broker and send it
  top = topic + hostname_char + "/status/rssi/";                                      // Built topic to sent message to
  client.publish(top.c_str(), ausgabe.c_str());                                       // Publish MQTT-Message
  EEPROM.begin(4095);                                                                 // Define EEPROM
  EEPROM.put(30, pos);                                                                // Write "pos" to EEPROM
  delay(200);                                                                         // Delay
  EEPROM.commit();                                                                    // Only needed for ESP8266 to get data written
  EEPROM.end();                                                                       // Free RAM copy of structure
}

// ##############################################################################################################################################################################
// ### Reconnect to MQTT-Broker #################################################################################################################################################
// ##############################################################################################################################################################################
void MQTT_reconnect() {
  unsigned long now = millis();                                                       // Get actual time
  if (now - lastReconnectAttempt > 5000) {                                            // If 5s passed after last reconnection attempt
    lastReconnectAttempt = now;                                                       // Set time of last reconnection attemp to now
    if (reconnect()) {                                                                // Try reconnection
      Serial.println("MQTT wieder verbunden!");
    } else {
      Serial.println("MQTT nicht verbunden!");
    }
  }
}

// ##############################################################################################################################################################################
// ### MQTT-Handling ############################################################################################################################################################
// ##############################################################################################################################################################################
void MQTT_Handling() {
  int value = 0;                                                                      // Initialize variable for percentage value
  if (drive) {                                                                        // If shutter is already moving
    motionStop();                                                                     // Stop motion
    drive = false;                                                                    // Reset Driving-Flag
    delay(500);                                                                       // Delay 500ms
  }
// *** MQTT-Command: UP *********************************************************************************************************************************************************    
  if (String(MQTTget_message) == "UP") {
    Serial.println("UP");                                                             // Debug printing
    if (pos <= 0) {                                                                   // If shutter is already completely opened
      pos = 0;                                                                        // Set position to 0
      return;                                                                         // Return
    }
    StartPosCalcTime = millis();                                                      // Set start time for Position-Calculation-Timer
    StartMoveTime = StartPosCalcTime;                                                 // Set start time for Movement-Timer
    moveUp();                                                                         // Open shutter
    drive = true;                                                                     // Set Motion-Flag
    moving_up = true;                                                                 // Set UP-Flag
    pos_fb = pos;                                                                     // Set calculated position to actual position
  }
// *** MQTT-Command: DOWN *******************************************************************************************************************************************************    
  if (String(MQTTget_message) == "DOWN") {
    Serial.println("DOWN");                                                           // Debug printing
    if (pos >= 100) {                                                                 // If shutter is already completely closed
      pos = 100;                                                                      // Set position to 100
      return;                                                                         // Return
    }
    StartPosCalcTime = millis();                                                      // Set start time for Position-Calculation-Timer
    StartMoveTime = StartPosCalcTime;                                                 // Set start time for Movement-Timer
    moveDown();                                                                       // Close shutter
    drive = true;                                                                     // Set Motion-Flag
    moving_down = true;                                                               // Set DOWN-Flag
    pos_fb = pos;                                                                     // Set calculated position to actual position
  }
// *** MQTT-Command: STOP *******************************************************************************************************************************************************    
  if (String(MQTTget_message) == "STOP") {
    Serial.println("STOP");                                                           // Debug printing
    motionStop();                                                                     // Stop motion
    drive = false;                                                                    // Reset Driving-Flag
    moving_up = false;                                                                // Reset UP-Flag
    moving_down = false;                                                              // Reset DOWN-FLAG
  }
// *** MQTT-Command: TEACH ******************************************************************************************************************************************************
  if (String(MQTTget_message) == "TEACH") {
    Serial.println("TEACH");                                                          // Debug printing
    teach_flag = true;                                                                // Set Teaching-Flag
  }
// *** MQTT-Command: STATUS *****************************************************************************************************************************************************    
  if (String(MQTTget_message) == "STATUS") {
    Serial.println("STATUS");                                                         // Debug printing
    ausgabe = String(pos);                                                            // Build strings to send to MQTT-Broker and send it
    top = topic + hostname_char + "/status/position/";                                // Built topic to sent message to
    client.publish(top.c_str(), ausgabe.c_str());                                     // Publish MQTT-Message
    long rssi = WiFi.RSSI();                                                          // Get RSSI of WiFi-Connection
    ausgabe = String(rssi);                                                           // Build strings to send to MQTT-Broker and send it
    top = topic + hostname_char + "/status/rssi/";                                    // Built topic to sent message to
    client.publish(top.c_str(), ausgabe.c_str());                                     // Publish MQTT-Message
  }
// *** MQTT-Command: MANUAL_START ***********************************************************************************************************************************************    
  if (String(MQTTget_message) == "MANUAL_START") {
    Serial.println("MANUAL_START");                                                   // Debug printing
    manual_flag = true;                                                               // Set Manual-Flag
  }
// *** MQTT-Command: MANUAL_STOP ************************************************************************************************************************************************    
  if (String(MQTTget_message) == "MANUAL_STOP") {
    Serial.println("MANUAL_STOP");                                                    // Debug printing
    manual_flag = false;                                                              // Reset Manual-Flag
  }
// *** MQTT-Command: <percentage value> *****************************************************************************************************************************************    
  if (isNumeric(String(MQTTget_message))) {
    if ((String(MQTTget_message).toInt() >= 0) && (String(MQTTget_message).toInt() <= 100)) {   // If MQTT-Message is numeric and between 0 and 100
      value = String(MQTTget_message).toInt();                                        // Get integer value of MQTT-Message
      Serial.println("Got percentage: " + String(MQTTget_message) + "%");             // Debug printing
      soll = value;                                                                   // Set Target-Value
      StartPosCalcTime = millis();                                                    // Set start time for Position-Calculation-Timer
      StartMoveTime = StartPosCalcTime;                                               // Set start time for Movement-Timer
      if (soll > pos) {                                                               // If Target-Position > as actual position
        delta = soll - pos;                                                           // Calculate delta
        drive = true;                                                                 // Set Motion-Flag
        moving_down = true;                                                           // Set DOWN-Flag
        pos_fb = pos;                                                                 // Set calculated position to actual position
        percentage = true;                                                            // Set Percentage-Flag
        moveDown();                                                                   // Start motion
      }
      if (pos > soll) {                                                               // If Target-Value < as actual position
        delta = pos - soll;                                                           // Calculate delta
        drive = true;                                                                 // Set Motion-Flag
        moving_up = true;                                                             // Set UP-Flag
        pos_fb = pos;                                                                 // Set calculated position to actual position
        percentage = true;                                                            // Set Percentage-Flag
        moveUp();                                                                     // Start motion
      }
    }
  }
}

// ##############################################################################################################################################################################
// ### Button-Handling ##########################################################################################################################################################
// ##############################################################################################################################################################################
void ButtonHandling() {
  if (!digitalRead(IO_I1) || !digitalRead(IO_I2)) {                                   // If one of both buttons is pressed
// *** Shutter already in motion ************************************************************************************************************************************************
    if (drive) {                                                                      // Check if motor is jet running
      motionStop();                                                                   // If so, stop motor
      drive = false;                                                                  // and reset all flags
      moving_up = false;
      moving_down = false;
      percentage = false;
      return;                                                                         // Return
    }
    delay(100);                                                                       // Delay for debouncing Buttons
// *** Manual control of shutter ************************************************************************************************************************************************
    if (manual_flag) {                                                                // If Manual-Movement-Flag is set
      if (!digitalRead(IO_I1)) {                                                      // And if UP is pressed
        moveUp();                                                                     // Start Up-Movement
        do {                                                                          // Do as long as button is pressed
          delay(100);                                                                 // Delay 100ms
        } while (!digitalRead(IO_I1));                                                // As long as button is pressed
        motionStop();                                                                 // If button is released, stop movement
        return;                                                                       // Return
      }
      if (!digitalRead(IO_I2)) {                                                      // And if DOWN is pressed
        moveDown();                                                                   // Start Down-Movement
        do {                                                                          // Do as long as button is pressed
          delay(100);                                                                 // Delay 100ms
        } while (!digitalRead(IO_I2));                                                // As long as button is pressed
        motionStop();                                                                 // If button is released, stop movement
        return;                                                                       // Return
      }
    }
// *** Teaching-Mode ************************************************************************************************************************************************************
    if (teach_flag) {                                                                 // If Teaching-Flag is set
      ausgabe = "Teach me...";                                                        // Build strings to send to MQTT-Broker and send it
      top = topic + hostname_char + "/status/teach/";                                 // Built topic to sent message to
      client.publish(top.c_str(), ausgabe.c_str());                                   // Publish MQTT-Message
      down_time = 0;                                                                  // Reset Down-Time
      up_time = 0;                                                                    // Reset Up-Time
      // *** STEP 1: Wait until button is pressed ***
      do {                                                                            // Wait until one of both buttons is pressed
        delay(100);                                                                   // Delay 100ms
      } while (digitalRead(IO_I1) && digitalRead(IO_I2));                             // As long as no button is pressed
      // *** STEP 2: Count Time for first movement ***
      if (!digitalRead(IO_I1)) {                                                      // If UP is pressed
        moveUp();                                                                     // Start Up-Movement
        do {                                                                          // Count time for UP-Movement
          delay(100);                                                                 // Intervall: every tenth of second
          up_time++;                                                                  // Increment up_time
        } while (!digitalRead(IO_I1));                                                // Until button is released
        up_pressed = true;                                                            // Set flag for firs meassured time
        motionStop();                                                                 // Stop motion
      } else {                                                                        // If down is pressed
        moveDown();                                                                   // Start Down-Movement
        do {                                                                          // Count time for DOWN-Movement
          delay(100);                                                                 // Intervall: every tenth of second
          down_time++;                                                                // Increment down_time
        } while (!digitalRead(IO_I2));                                                // Until button is released
        down_pressed = true;                                                          // Set flag for first meassured time
        motionStop();                                                                 // Stop motion
      }
      // *** STEP 3: Wait until other button is pressed and count time for second movement ***
      if (up_pressed) {                                                               // If first motion was UP
        up_pressed = false;                                                           // Reset flag for first measured time
        do {                                                                          // Wait until the other buttons is pressed
          delay(100);                                                                 // Delay 100 ms
        } while (digitalRead(IO_I2));                                                 // As long as button isn't pressed
        moveDown();                                                                   // Start Down-Movement
        do {                                                                          // Count seconds for DOWN-Movement
          delay(100);                                                                 // Intervall: every tenth of second
          down_time++;                                                                // Increment down time
        } while (!digitalRead(IO_I2));                                                // As long as button is still pressed
        motionStop();                                                                 // Stop motion
      }
      if (down_pressed) {                                                             // If first motion was DOWN
        down_pressed = false;                                                         // Reset flag for first measured time
        do {                                                                          // Wait until the other buttons is pressed
          delay(100);                                                                 // Delay 100ms
        } while (digitalRead(IO_I1));                                                 // As long as button isn't pressed
        moveUp();                                                                     // Start Up-Movement
        do {                                                                          // Count seconds for UP-Movement
          delay(100);                                                                 // Intervall: every tenth of second
          up_time++;                                                                  // Increment up_time
        } while (!digitalRead(IO_I1));                                                // As long as button is still pressed
        motionStop();                                                                 // Stop motion
      }
      teach_flag = false;                                                             // Reset Teaching-Flag
      ausgabe = String(down_time);                                                    // Build strings to send to MQTT-Broker and send it
      top = topic + hostname_char + "/status/teach/";                                 // Built topic to sent message to
      client.publish(top.c_str(), ausgabe.c_str());                                   // Publish MQTT-Message
      ausgabe = String(up_time);                                                      // Build strings to send to MQTT-Broker and send it
      top = topic + hostname_char + "/status/teach/";                                 // Built topic to sent message to
      client.publish(top.c_str(), ausgabe.c_str());                                   // Publish MQTT-Message
      EEPROM.begin(4095);                                                             // Define EEPROM
      EEPROM.put(10, down_time);                                                      // Write down_time to EEPROM
      EEPROM.put(20, up_time);                                                        // Write up_time to EEPROM
      delay(200);                                                                     // Delay
      EEPROM.commit();                                                                // Only needed for ESP8266 to get data written
      EEPROM.end();                                                                   // Free RAM copy of structure
      return;                                                                         // Return
    }
// *** Handling normal Button-Press *********************************************************************************************************************************************
    if(!teach_flag && !manual_flag) {                                                 // If no special flag (either teach or manual) is set
      if (!digitalRead(IO_I1)) {                                                      // If UP is pressed
        if (pos <= 0) {                                                               // If Shutter is already completly opened
          pos = 0;                                                                    // Position is 0
          return;                                                                     // Return
        }
        moveUp();                                                                     // Otherwise open shutter
        pos_fb = pos;                                                                 // Set calculated position to actual position
        float calc_time = float(up_time);                                             // Store UP-Time in temporary variable
        for (int i = 1; i <= 10; i++) {                                               // Do for one second
          delay(100);                                                                 // Every tenth of a second
          if (pos <= 0) {                                                             // If Shutter is already completly opened
            pos = 0;                                                                  // Position is 0
            motionStop();                                                             // Stop motion
            return;                                                                   // Return
          } else {                                                                    // Else
             pos_fb = pos_fb - (100 / calc_time);                                     // Calculate new position
          }
        }
        if (!digitalRead(IO_I1)) {                                                    // If UP is still pressed after 1s => manual movement according switch mode
          do {                                                                        // As long as button is still pressed do
            delay(100);                                                               // Delay for 100ms
            if (pos <= 0) {                                                           // If shutter is already totally opened
              pos = 0;                                                                // Position = 0
              motionStop();                                                           // Stop motion
              return;                                                                 // Return
            } else {                                                                  // If shutter isn't opened
              pos_fb = pos_fb - (100 / calc_time);                                    // Calculate new position
            }
          } while (!digitalRead(IO_I1));                                              // If button is released
          motionStop();                                                               // Stop motion
        } else {                                                                      // If UP isn't pressed after 1s => start semi automatic mode
          StartPosCalcTime = millis();                                                // Set start time for Position-Calculation-Timer
          StartMoveTime = StartPosCalcTime;                                           // Set start time for Movement-Timer
          moveUp();                                                                   // Open shutter
          drive = true;                                                               // Set Motion-Flag
          moving_up = true;                                                           // Set UP-Flag
        }
        return;                                                                       // Return
      }
      if (!digitalRead(IO_I2)) {                                                      // If DOWN is pressed
        if (pos >= 100) {                                                             // If shutter is already completly closed
          pos = 100;                                                                  // Position = 100
          return;                                                                     // Return
        }
        moveDown();                                                                   // Otherwise close shutter
        pos_fb = pos;                                                                 // Set calculated position to actual position
        float calc_time = float(down_time);                                           // Store DOWN-Time in temporary variable
        for (int i = 1; i <= 10; i++) {                                               // Do for one second:
          delay(100);                                                                 // Every tenth of a second
          if (pos >= 100) {                                                           // If shutter is already compleatly closed
            pos = 100;                                                                // Position = 100
            motionStop();                                                             // Stop Motion
            return;                                                                   // Return
          } else {                                                                    // Else
            pos_fb = pos_fb + (100 / calc_time);                                      // Calculate new position
          }
        }
        if (!digitalRead(IO_I2)) {                                                    // If DOWN is still pressed after 1s => manual movement according switch mode
          do {                                                                        // As long as button is still pressed do
            delay(100);                                                               // Delay for 100ms
            if (pos >= 100) {                                                         // If shutter is already totaly closed
              pos = 100;                                                              // Position = 100
              motionStop();                                                           // Stop motion
              return;                                                                 // Return
            } else {                                                                  // If shutter isn't closed
              pos_fb = pos_fb + (100 / calc_time);                                    // Calculate new position
            }
          } while (!digitalRead(IO_I2));                                              // If button is released
          motionStop();                                                               // Stop motion
        } else {                                                                      // If DOWN isn't pressed after 1s => start semi automatic mode
          StartPosCalcTime = millis();                                                // Set start time for Position-Calculation-Timer
          StartMoveTime = StartPosCalcTime;                                           // Set start time for Movement-Timer
          moveDown();                                                                 // Close shutter
          drive = true;                                                               // Set Motion-Flag
          moving_down = true;                                                         // Set DOWN-Flag
        }
      }
    }
  }
}

// ##############################################################################################################################################################################
// ### Move according actual position ###########################################################################################################################################
// ##############################################################################################################################################################################
void MoveNow() {
// *** If moving_up flag is set *************************************************************************************************************************************************
  if (moving_up) {                                                                    // If Move-UP-Flag is set
    unsigned long CurrentTime = millis();                                             // Get current time
    if (CurrentTime - StartPosCalcTime > 100) {                                       // Every 100ms
      StartPosCalcTime = CurrentTime;                                                 // Start new period of time
      float calc_time = float(up_time);                                               // Store UP-Time in temporary variable
      pos_fb = pos_fb - (100 / calc_time);                                            // Calculate new position
    }
    if (percentage) {                                                                 // If target value is a percentage value
      if (CurrentTime > StartMoveTime + (100 * (up_time / 100) * delta)) {            // Move as long as target value isn't reached
        pos = soll;                                                                   // If target value is reached, set new position
        motionStop();                                                                 // Stop motion
        drive = false;                                                                // Reset flags
        moving_up = false;
        percentage = false;
      }
    } else {                                                                          // If shutter should move to end position
      if (CurrentTime > StartMoveTime + ((100 * (up_time / 100) * pos) + 3000)){      // Move as long as end position isn't reached
        pos = 0;                                                                      // If end position is reached, set position to endposition
        motionStop();                                                                 // Stop motion
        drive = false;                                                                // Reset flags
        moving_up = false;
      }
    }
  }
// *** If moving_down flag is set ***********************************************************************************************************************************************
  if (moving_down) {                                                                  // If Move-DOWN-Flag is set
    unsigned long CurrentTime = millis();                                             // Get current time
    if (CurrentTime - StartPosCalcTime > 100) {                                       // Every 100ms
      StartPosCalcTime = CurrentTime;                                                 // Start new period of time
      float calc_time = float(down_time);                                             // Store DOWN-Time in temporary variable
      pos_fb = pos_fb + (100 / calc_time);                                            // Calculate new position
    }
    if (percentage) {                                                                 // If target value is a percentage value
      if (CurrentTime > StartMoveTime + (100 * (down_time / 100) * delta)) {          // Move as long as target value isn't reached
        pos = soll;                                                                   // If target value is reached, set new position
        motionStop();                                                                 // Stop motion
        drive = false;                                                                // Reset flags
        moving_down = false;
        percentage = false;
      }
    } else {                                                                          // If shutter should move to end position
      if (CurrentTime > StartMoveTime + ((100 * (down_time / 100) * (100 - pos)) + 3000)){   // Move as long as end position isn't reached
        pos = 100;                                                                    // If end position is reached, set position to endposition
        motionStop();                                                                 // Stop motion
        drive = false;                                                                // Reset flags
        moving_down = false;
      }
    }
  }
}

// ##############################################################################################################################################################################
// ### Main Routine #############################################################################################################################################################
// ##############################################################################################################################################################################
void loop() {
  ArduinoOTA.handle();                                                                // Start OTA-Handle
  if (!client.connected()) {                                                          // If MQTT-Client isn't conntected to broker
    MQTT_reconnect();                                                                 // Reconnect to MQTT-Broker
  } else {                                                                            // If connected to MQTT-Broker  
    if (newMQTTmessage) {                                                             // If new MQTT-Message avaliable
      newMQTTmessage = false;                                                         // Reset "New-MQTT-Message-Flag"
      MQTT_Handling();                                                                // Call MQTT-Handling
    }
  }
  ButtonHandling();                                                                   // Call Button-Handling Routine
  MoveNow();                                                                          // Call Move-According-Time Routine
  CurrentTime = millis();                                                             // Get current time
  if ((CurrentTime - LastTime) >= interval) {                                         // Wait interval-time until checking MQTT-Connection
    LastTime = CurrentTime;
    client.loop();
  }
}
