--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
----- init.lua              		--------------------------------------------------------------------------------------------------
----- INIT-File for SmartSwitch 	--------------------------------------------------------------------------------------------------
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

-- ws2812.init()                                                           -- WS2812 LED data pin at GPIO 02
-- ws2812.write(string.char(0, 0, 0))                                      -- LED off
-- ws2812.write(string.char(10, 0, 0))                                     -- Set status "red"

cnt = 0 							                                    -- Counter for connecting cycle to get IP
print("Starting Login AP and get IP")                                   
wifi.setmode(wifi.STATION)			                                    -- Set module to station mode
wifi.sta.autoconnect(1)				                                    -- Set auto connect
-- ws2812.write(string.char(10, 5, 0))                                     -- Set status "orange"

tmr.alarm(0, 2000, 1, function()                                        -- check every 2 second about IP
	if wifi.sta.getip()== nil then
    ssid, password, bssid_set, bssid=wifi.sta.getconfig()               -- Get actual Station-Configuration (SSID, PWD,...)
	cnt = cnt + 1				                                    	-- No ip received, increment counter
		print("(" .. cnt .. ") Waiting for IP...")
		if cnt == 6 then                                                -- If connection counter = 10
			-- ws2812.write(string.char(5,0,5))                            -- Set Status-LED pink
			wifi.setmode(wifi.STATIONAP)                                -- Set WIFI-Mode to StationAP
			wifi.ap.config({ssid="MyPersonalSSID", auth=wifi.OPEN})     -- Set AP-Config (SSID, no PWD)
			enduser_setup.start(                                        -- Start EnduserSetup
				function()
					print("Connected to wifi as:" .. wifi.sta.getip())
					node.restart()
				end,
				function(err, str)
					print("enduser_setup: Err #" .. err .. ": " .. str)
				end
			);
		end
		if cnt == 100 then                                              -- If Station-SSID = "none" then
			tmr.stop(0)					                            	-- stop timer to get IP
			-- ws2812.write(string.char(10, 0, 0))							-- Set status "red"
			tmr.delay(5000000)
			dofile("INI_Handling.lc")                                  -- Call INI-Library
			dofile("MQTT.lc")                                          -- Call MQTT-Library
			tmr.alarm(1, 3000, tmr.ALARM_SINGLE, function()             -- Wait 3 seconds (takes time to connect to broker)
				dofile("SmartSwitch.lc")                               -- start main programm 
			end)
		end
	else                                                                -- got IP, start Main Program
        print("Module IP = "..wifi.sta.getip() .. "  Start main Program")
	    tmr.stop(0)                                                     -- stop timer for IP address scann
        -- ws2812.write(string.char(0, 10, 0))                             -- Set staus "green"
        dofile("INI_Handling.lc")                                      -- Call INI-Library
        dofile("MQTT.lc")                                              -- Call MQTT-Library
        tmr.alarm(1, 3000, tmr.ALARM_SINGLE, function()                 -- Wait 3 seconds (takes time to connect to broker)
           dofile("SmartSwitch.lc")                                    -- start main programm 
        end)
    end
end)