--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
----- MQTT.lua              		--------------------------------------------------------------------------------------------------
----- MQTT-Handling for SmartSwitch --------------------------------------------------------------------------------------------------
----- Copyright © 2018 A. Köhler   	--------------------------------------------------------------------------------------------------
-----																		----------------------------------------------------------
----- This program is free software: you can redistribute it and/or modify	----------------------------------------------------------
----- it under the terms of the GNU General Public License as published by	----------------------------------------------------------
----- the Free Software Foundation, either version 3 of the License, or		----------------------------------------------------------
----- (at your option) any later version.									----------------------------------------------------------
-----																		----------------------------------------------------------
----- This program is distributed in the hope that it will be useful,		----------------------------------------------------------
----- but WITHOUT ANY WARRANTY; without even the implied warranty of		----------------------------------------------------------
----- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the			----------------------------------------------------------
----- GNU General Public License for more details.							----------------------------------------------------------
-----																		----------------------------------------------------------
----- You should have received a copy of the GNU General Public License		----------------------------------------------------------
----- along with this program.  If not, see <http://www.gnu.org/licenses/>.	----------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------
-- Get Values from MQTT.ini ----------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
MQTT_Broker = read_ini("MQTT.ini", "IP")									-- Get Broker-IP from INI-File
MQTT_Broker_Port = read_ini("MQTT.ini", "Port")								-- Get Broker-Port from INI-File
MQTT_Topic = read_ini("MQTT.ini", "Topic")									-- Get Subscribe Topic from INI-File

print("****************************************************************************")
print("BROKER: "..MQTT_Broker..", PORT: "..MQTT_Broker_Port..", TOPIC: "..MQTT_Topic)
print("****************************************************************************")

--------------------------------------------------------------------------------------------------------------------------------------
-- Set Variables ---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
MQTT_Broker_Secure = 0														-- Set Security-Level
MQTT_Publish_Topic_QoS = 1													-- Set Publish QoS-Level
MQTT_Publish_Topic_Retain = 1												-- Set Retain-Level
MQTT_Subscribe_Topic_QoS = 1												-- Set Subscribe QoS-Level
MQTT_Client_ID = string.gsub(wifi.sta.getmac(), ":", "")					-- Get MAC-Address as Client-ID
MQTT_Client_KeepAlive_Time = 120											-- Set Keep Alive Time
MQTT_Connection = 0															-- Set Connection-Status

--------------------------------------------------------------------------------------------------------------------------------------
-- Initiate MQTT Client --------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
MQTT_Client = mqtt.Client(MQTT_Client_ID, MQTT_Client_KeepAlive_Time)		-- Start MQTT-Client

-- On Connect Event ------------------------------------------------------------------------------------------------------------------
MQTT_Client:on("connect", function(con) 									-- Handling if connection is established
    print ("connected")
    tmr.stop(3)																-- Stop connecting
    MQTT_Connection = 1 													-- Set Connection-Status "connected"
    listen()																-- Listen to subscribed topic
end)

-- On Offline Event ------------------------------------------------------------------------------------------------------------------
MQTT_Client:on("offline", function(con) 									-- Handling if broker is offline
    print ("offline")
    MQTT_Connection = 0														-- Set Connection-Status "offline"
    connect()																-- Start reconnecting
end)

-- On Message Recieve Event ----------------------------------------------------------------------------------------------------------
MQTT_Client:on("message", function(conn, topic, data)						-- Handling if message is received
    print("MQTT Message Received...")
    print("Topic: " .. topic)
    if data ~= nil then														-- If message isn't empty
        print("Message: " .. data)
        message_get(topic, data)											-- Message-Handling function in Main Program
    end
end)

--------------------------------------------------------------------------------------------------------------------------------------
-- Connect to MQTT Broker ------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function connect()
    cnt = 0																	-- Reset counter for connection trials
    tmr.alarm(3, 2000, 1, function()										-- Set Timer for reconnection trials
        cnt = cnt + 1                                                       -- Increment counter
        print("(" .. cnt .. ") Waiting for MQTT-Broker...")
        if MQTT_Connection == 1 then										-- If connection is established
            return															-- return
        end
        MQTT_Client:connect(MQTT_Broker, MQTT_Broker_Port, MQTT_Broker_Secure, function(conn) 	-- Try to connect
            print("now connected")
            MQTT_Connection = 1												-- Set Connection-Status "connected"
            listen()														-- Listen to subscribed topic
            tmr.stop(3)														-- Stop connecting
        end,
        function(client, reason)											-- If no connection is possible
            print("failed reason: " .. reason)
        end)
    end)
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Subscribe to MQTT Topic -----------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function listen()
 MQTT_Client:subscribe(MQTT_Topic, MQTT_Subscribe_Topic_QoS, function(conn) 
 end)
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Close MQTT-Client -----------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function MQTT_close()
 MQTT_Client:close()
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Publish MQTT-Message --------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function fire(topic, text)
    MQTT_Client:publish(topic, text, MQTT_Publish_Topic_QoS, MQTT_Publish_Topic_Retain, function(conn) 
        print(text) 
    end)
end

connect()
