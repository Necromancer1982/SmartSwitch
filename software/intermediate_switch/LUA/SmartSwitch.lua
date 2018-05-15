--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
----- SmartSwitch.lua              ---------------------------------------------------------------------------------------------------
----- Mainprogram for SmartSwitch  ---------------------------------------------------------------------------------------------------
----- Copyright © 2018 A. Köhler   ---------------------------------------------------------------------------------------------------
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
-- MQTT-Handler ----------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function message_get(topic, data)
-- Handling if "ON" was received -----------------------------------------------------------------------------------------------------
    if (data == "ON" and LightOnOff == "OFF" )then                      -- If "ON" received and light is actual off
        if dimmable == 1 then                                           -- If light is dimmable
            if brightness == 15 then                                    -- If stored brightness is 15%
                for x = 1, 7, 1 do
                    toggle()                                            -- Toggle Relays 7x => on, off, on, off, on, off, on => results in switch light to 15%
                end
            end
            if brightness == 40 then                                    -- If stored brightness is 40%
                for x = 1, 5, 1 do
                    toggle()                                            -- Toggle Relays 5x => on, off, on, off, on => results in switch light to 40%
                end
            end
            if brightness == 60 then                                    -- If stored brightness is 60%
                for x = 1, 3, 1 do
                    toggle()                                            -- Toggle Relays 3x => on, off, on => results in switch light to 60%
                end
            end
            if brightness == 100 then                                   -- If stored brightness is 100%
                toggle()                                                -- Toggle Relays 1x => switch light on
            end
        else
            toggle()                                                    -- If light isn't dimmable, simple switch light on
        end
        write_ini("SmartSwitch.ini", "LightOnOff", "ON")                -- Write actual Light-Status to INI-File
    end
-- Handling if "OFF" was received ----------------------------------------------------------------------------------------------------
    if (data == "OFF" and LightOnOff == "ON") then                      -- If "OFF" received and light is actual on
        toggle()                                                        -- Toggle Relays
        write_ini("SmartSwitch.ini", "LightOnOff", "OFF")               -- Write actual Light-Status to INI-File
    end
-- Handling if "STATUS" was received -------------------------------------------------------------------------------------------------    
	if data == "STATUS" then
		sendData(LightOnOff.."#"..brightness)                           -- Feedback and store position
	end
-- Handling if percentage was received -----------------------------------------------------------------------------------------------
    if data ~= "ON" and data ~= "OFF" and data ~= "STATUS" then         -- If percentage is received
        if dimmable == 1 then                                           -- If light is dimmable
            if tonumber(data) == 100 then state_soll = 1 end            -- Get Stateitem correspondent to percentage for data
            if tonumber(data) == 60 then state_soll = 2 end
            if tonumber(data) == 40 then state_soll = 3 end
            if tonumber(data) == 15 then state_soll = 4 end
            if brightness == 100 then state_ist = 1 end                 -- Get Stateitem correspondent to percentage for actual brightness
            if brightness == 60 then state_ist = 2 end
            if brightness == 40 then state_ist = 3 end
            if brightness == 15 then state_ist = 4 end
            if state_ist < state_soll then                              -- If actual state index < new state index
                delta = state_soll - state_ist                          -- Calculate delta between old and new state index
                if LightOnOff == "OFF" then                             -- If light is actual off
                    for x = 1, (1 + delta * 2), 1 do
                        toggle()                                        -- Toggle Relays 1 + 2 * delta times
                    end
                else                                                    -- Else...
                    for x = 1, (delta * 2), 1 do
                        toggle()                                        -- Toggle Relays 2 * delta times
                    end
                end
            end
            if state_ist > state_soll then                              -- If actual state index > new state index
                delta = 4 - state_ist + state_soll                      -- Calculate delta between old and new state index
                if LightOnOff == "OFF" then                             -- If light is actual off
                    for x = 1, (1 + delta * 2), 1 do
                        toggle()                                        -- Toggle Relays 1 + 2 * delta times
                    end
                else                                                    -- Else...
                    for x = 1, (delta * 2), 1 do
                        toggle()                                        -- Toggle Relays 2 * delta times
                    end
                end
            end
            brightness = tonumber(data)                                 -- Set value "brightness" to actual received brightness (data)
            write_ini("SmartSwitch.ini", "LightOnOff", "ON")            -- Write actual Light-Status to INI-File
            write_ini("SmartSwitch.ini", "brightness", tonumber(data))  -- Write actual brightness to INI-File
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Function to send Data to MQTT-Broker ----------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function sendData(data)
    if wifi.sta.getip()~= nil then                                      -- Check for IP again
        if MQTT_Connection == 1 then                                    -- If MQTT-Connection avaliable
            fire("/SmartSwitch/"..sensor_id.."/status", data)           -- Fire MQTT-Message
            print("MQTT: "..data)
        else
            print("MQTT: nicht verbunden")
        end 
    else
        print("No IP")
    end
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Delay for debouncing interrupt ----------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function int_delay()
    tmr.alarm(0, 100, 0, function() isr() end)                          -- Interrupt calls ISR after 100ms
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Enable interrupt ------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function setINT()                                                       -- Define IOs as Interrupt-Pins
    gpio.trig(IO_S1, "both", int_delay)                                 -- Both edges triggers interruppts
    gpio.trig(IO_S2, "both", int_delay)
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Toggle Relais ---------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function toggle()
    if SwitchState == 0 then
        gpio.write(IO_O2, gpio.HIGH)									-- Toggle Relay 1
        tmr.delay(50000)												-- Delay for 50ms
        gpio.write(IO_O1, gpio.HIGH)									-- Toggle Relay 2
        tmr.delay(50000)                                                -- Delay for 50ms
        SwitchState = 1
        return
    end
    if SwitchState == 1 then
        gpio.write(IO_O2, gpio.LOW)                                     -- Toggle Relay 1
        tmr.delay(50000)                                                -- Delay for 50ms
        gpio.write(IO_O1, gpio.LOW)                                     -- Toggle Relay 2
        tmr.delay(50000)                                                -- Delay for 50ms
        SwitchState = 0
        return
    end
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Interrupt Service Routine for Inputs ----------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function isr (level, when)
    gpio.trig(IO_S1)                                                    -- Disable interrupts
    gpio.trig(IO_S2)
    pin = gpio.read(IO_S1)                                              -- Get temporary value of Sense-Input 1 (230V => 0   0V => 1)
    tmr_zeit = 2050                                                     -- Variable to rise time for timer 1
    if brightness == 100 then state_ist = 1 end                         -- Get state correspondent to percentage for actual brightness
    if brightness == 60 then state_ist = 2 end
    if brightness == 40 then state_ist = 3 end
    if brightness == 15 then state_ist = 4 end
    tmr.alarm(5, 2000, tmr.ALARM_SINGLE, function()                     -- Timer 1: Deadtime after last detected edge (Switch was pushed or released)
        tmr.stop(4)                                                     -- Stop sensing timer
        max = 4 - state_ist                                             -- Calculate max. steps to lower brightness before overflow (change from 15% to 100% brightness)
        steps = SwitchCounter % 4                                       -- Calculate steps to switch (overflow => repeat every four steps)
        if steps <= max then                                            -- If steps to do <= max. steps then...
            state_neu = steps + state_ist                               -- Calculate new state by adding steps to actual state
        else                                                            -- else...
            state_neu = steps - max                                     -- Calculate new state by substracting steps to overflow from steps to do
        end
        if state_neu == 1 then brightness = 100 end                     -- Translate state to brightness
        if state_neu == 2 then brightness = 60 end
        if state_neu == 3 then brightness = 40 end
        if state_neu == 4 then brightness = 15 end
        write_ini("SmartSwitch.ini", "brightness", brightness)          -- Write actual brightness to INI-File
        if gpio.read(IO_S1) == 0 then
            write_ini("SmartSwitch.ini", "LightOnOff", "ON")            -- Write actual Light-Status to INI-File
        else
            write_ini("SmartSwitch.ini", "LightOnOff", "OFF")           -- Write actual Light-Status to INI-File
        end
        SwitchCounter = 0                                               -- Reset counted edges
        setINT()                                                        -- Enable interrupts
        return                                                          -- Return
    end)
    tmr.alarm(4, 50, tmr.ALARM_AUTO, function()  						-- Timer 2: Check state of Sense-Input 1 every 50ms
        if gpio.read(IO_S1) ~= pin then                                 -- If level of S1 has chaged
            tmr.interval(5, tmr_zeit)                                   -- Rise time of timer 2 regarding done time (50ms)
            tmr_zeit = tmr_zeit + 50                                    -- Rise variable for rising timer 1
            if gpio.read(IO_S1) == 0 then                               -- If S1 detect rising edge
                SwitchCounter = SwitchCounter + 1                       -- Rise counted edges
            end
            pin = gpio.read(IO_S1)                                      -- Strore level of S1 for comparison
        end
    end)
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Main Program ----------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
I2C_SDA = 4     -- GPIO02                                               -- Patching of IO-Pins
I2C_SCL = 5     -- GPIO14
GPIO16 = 0      -- GPIO16
IO_S1 = 6       -- GPIO12
IO_S2 = 7       -- GPIO13
IO_O1 = 2       -- GPIO04
IO_O2 = 1       -- GPIO05
LevelS1 = 0                                                             -- Variable for Voltage-Level on IO S1
LevelS2 = 0                                                             -- Variable for Voltage-Level on IO S2
SwitchState = 0                                                         -- Variable for Toggle-State of relays
SwitchCounter = 0                                                       -- Variable to count edges (Switch)
-- Setup IO-Pins ---------------------------------------------------------------------------------------------------------------------
gpio.mode(IO_S1, gpio.INT)                                              -- Definition of Interrupt-Pins
gpio.mode(IO_S2, gpio.INT)
gpio.mode(IO_O1, gpio.OUTPUT)											-- Definition of Output-Pins
gpio.mode(IO_O2, gpio.OUTPUT)
gpio.write(IO_O1, gpio.LOW)												-- Set Output-Pins low
gpio.write(IO_O2, gpio.LOW)
setINT()                                                                -- Enable Interrupt
-- Get MAC-Address -------------------------------------------------------------------------------------------------------------------
sensor_id = string.gsub(wifi.sta.getmac(), ":", "")                     -- Get MAC address for MQTT-ID
-- Get values form INI-File ----------------------------------------------------------------------------------------------------------
LightOnOff = read_ini("SmartSwitch.ini", "LightOnOff")                  -- Variable for Light-State (ON of OFF)
brightness = tonumber(read_ini("SmartSwitch.ini", "brightness"))        -- Variable for Brightness (15, 40, 60 or 100)
dimmable = tonumber(read_ini("SmartSwitch.ini", "dimmable"))            -- Variable if Lamp is dimmable or not
-- Handling after Module was started (e.g. get correct Switchstate after blackout) ---------------------------------------------------
if (LightOnOff == "OFF" and LevelS1 == 1) then                          -- If light was off and now detected on 
    toggle()                                                            -- Toggle Relays
end
if (LightOnOff == "ON" and LevelS1 == 0) then                           -- If light was on and now detected off
    if dimmable == 1 then                                               -- If light is dimmable
        if brightness == 15 then                                        -- If brightness was 15%
            for x = 1, 7, 1 do
                toggle()                                                -- Toggle Relays 7x => on, off, on, off, on, off, on => results in switch light to 15%
            end
        end
        if brightness == 40 then                                        -- If brightness was 40%
            for x = 1, 5, 1 do
                toggle()                                                -- Toggle Relays 5x => on, off, on, off, on => results in switch light to 40%
            end
        end
        if brightness == 60 then                                        -- If brightness was 60%
            for x = 1, 3, 1 do
                toggle()                                                -- Toggle Relays 3x => on, off, on => results in switch light to 60%
            end
        end
        if brightness == 100 then                                       -- If brightness was 100%
            toggle()                                                    -- Toggle Relays 1x => switch light on
        end
    else
        toggle()                                                        -- If light isn't dimmable, siple toggle relays and switch light on
    end
end
