--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
----- SmartSwitch.lua              ---------------------------------------------------------------------------------------------------
----- ESP-12F File for SmartSwitch ---------------------------------------------------------------------------------------------------
----- © A. Köhler 2018             ---------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------
-- MQTT-Handler ----------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function message_get(topic, data)
-- Handling to Stop during automatic drive -------------------------------------------------------------------------------------------
	if fahren == 1 then                                                 -- During movement, a interrupt should stop the motor
        motionStop()                                                    -- Stop shutter
        tmr.unregister(5)                                               -- Stop timer for half-automatic movement of shutter
		tmr.unregister(4)												-- Reset Movement-Flag
        fahren = 0                                                      -- Set movement-Flag "off"
        tmr.delay(500000)												-- Stop program for 500ms
    end 
-- Handling if "UP" was received -----------------------------------------------------------------------------------------------------
    if data == "UP" then
        if position <= 0 then                                           -- If shutter is already completely opened
            position = 0                                                -- Set position to 0%
            return                                                      -- Return
        end
        moveUp()
        fahren = 1                                                    	-- Set Movement-Flag
        tmr.alarm(4, 100, tmr.ALARM_AUTO, function()                	-- Calculate new position every 100ms
            position = position - (100 / up_time)
        end)
        tmr.alarm(5, 100 * (up_time / 100) * position, tmr.ALARM_SINGLE, function() -- move downward calculated time to reach position = 0%
            tmr.unregister(4)                                       	-- Stop calculation of position
            position = 0                                            	-- Set position to 0%
            motionStop()                                            	-- Stop movement
            fahren = 0                                              	-- Reset Movement-Flag
        end)
    end
-- Handling if "DOWN" was received ---------------------------------------------------------------------------------------------------
    if data == "DOWN" then
        if position >= 100 then                                         -- If shutter already completly closed 
            position = 100                                              -- Set position to 100 %
            return                                                      -- Return
        end
        moveDown()
        fahren = 1                                                    	-- Set Movement-Flag
        tmr.alarm(4, 100, tmr.ALARM_AUTO, function()                	-- Calculate new position every 100ms
            position = position + (100 / down_time)
        end)
        tmr.alarm(5, 100 * (down_time / 100) * (100 - position), tmr.ALARM_SINGLE, function()   -- move downward calculated time to reach position = 100 %
            tmr.unregister(4)                                       	-- Stop calculation of position
            position = 100                                          	-- Set position to 100%
            motionStop()                                            	-- Stop movement
            fahren = 0                                              	-- Reset Movement-Flag
        end)
    end
-- Handling if "STOP" was received ---------------------------------------------------------------------------------------------------    
	if data == "STOP" then
        motionStop()                                                    -- Stop shutter
        tmr.unregister(5)                                               -- Stop timer for half-automatic movement of shutter
		tmr.unregister(4)												-- Reset Movement-Flag
        fahren = 0                                                      -- Set movement-Flag "off"
    end
-- Handling if "TEACH" was received ---------------------------------------------------------------------------------------------------    
	if data == "TEACH" then
		teach_flag = 1
		isr()
	end
-- Handling if "MANUAL_START" was received --------------------------------------------------------------------------------------------
	if data == "MANUAL_START" then
		manual_flag = 1
	end
-- Handling if "MANUEL_STOP" was received ---------------------------------------------------------------------------------------------    
	if data == "MANUAL_STOP" then
		manual_flag = 0
	end
-- Handling if percentage was received ------------------------------------------------------------------------------------------------
    if data ~= "MANUAL_START" and data ~= "MANUAL_STOP" and data ~= "TEACH" and data ~= "UP" and data ~= "DOWN" and data ~= "STOP" then
		delta = 0
		soll = tonumber(data)
        if soll > position then											-- Received percentage > then position => move downward
			delta = soll - position										-- Calculate delta
			fahren = 1													-- Set Movement-Flag
			moveDown()			
			tmr.alarm(4, 100, tmr.ALARM_AUTO, function()                -- Calculate new position every 100ms
				position = position + (100 / down_time)
			end)
			tmr.alarm(5, 100 * (down_time / 100) * delta, tmr.ALARM_SINGLE, function()   -- move downward calculated time to reach position = 100 %
				tmr.unregister(4)                                       -- Stop calculation of position
				position = soll                                         -- Set position to percentage
				motionStop()                                            -- Stop movement
				fahren = 0                                              -- Reset Movement-Flag
			end)			
		end	
		if position > soll then											-- Received percentage < then position => move upwards
			delta = position - soll										-- Calculate delta
			fahren = 1													-- Set Movement-Flag
			moveUp()
			tmr.alarm(4, 100, tmr.ALARM_AUTO, function()                -- Calculate new position every 100ms
				position = position - (100 / up_time)
			end)
			tmr.alarm(5, 100 * (up_time / 100) * delta, tmr.ALARM_SINGLE, function() -- move downward calculated time to reach position = 0%
				tmr.unregister(4)                                       -- Stop calculation of position
				position = soll                                         -- Set position to received percentage
				motionStop()                                            -- Stop movement
				fahren = 0                                              -- Reset Movement-Flag
			end)
		end
    end
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Function to send Data to MQTT-Broker ----------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function sendData(data)
    if wifi.sta.getip()~= nil then                                      -- Check for IP again
        if MQTT_CONNECTION == 1 then                                    -- If MQTT-Connection avaliable
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
    gpio.trig(IO_I1, "down", int_delay)
    gpio.trig(IO_I2, "down", int_delay)
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Move shutter up -------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function moveUp()
    -- ws2812.write(string.char(0, 255, 255))
    gpio.write(IO_O2, gpio.LOW)											-- Set relais for direction "up"
    tmr.delay(200000)													-- Delay for 0.2s
    gpio.write(IO_O1, gpio.HIGH)										-- Set relais for power
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Move shutter down -----------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function moveDown()
    -- ws2812.write(string.char(255, 0, 255))
    gpio.write(IO_O2, gpio.HIGH)										-- Set relais for direction "down"
    tmr.delay(200000)													-- Delay for 0.2s
    gpio.write(IO_O1, gpio.HIGH)										-- Set relais for power
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Stop shutter movement -------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function motionStop()
    -- ws2812.write(string.char(0, 0, 0))
    gpio.write(IO_O1, gpio.LOW)											-- Reset relais for power
    tmr.delay(200000)													-- Delay for 0,2s
    gpio.write(IO_O2, gpio.LOW)											-- Reset relais for direction
    sendData(position)													-- Feedback and store position
    print("Position: "..position)
    write_ini("SmartSwitch.ini", "position", position)                  -- Write actual position to INI-File
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Interrupt Service Routine for Inputs ----------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function isr (level, when)
    gpio.trig(IO_I1)                                                    -- disable interrupts
    gpio.trig(IO_I2)

-- Routine to Stop during automatic drive --------------------------------------------------------------------------------------------
    if fahren == 1 then                                                 -- During movement, a interrupt should stop the motor
        print("STOP")
        motionStop()                                                    -- Stop shutter
        tmr.unregister(5)                                               -- Stop timer for half-automatic movement of shutter
		tmr.unregister(4)
        fahren = 0                                                      -- Set movement-Flag "off"
        setINT()                                                        -- enable interrupts
        return
    end    

-- Handling if "down" is pressed -----------------------------------------------------------------------------------------------------
    if gpio.read(IO_I1) == 1 and gpio.read(IO_I2) == 0 and fahren == 0 then
        print("DOWN")
        if manual_flag == 0 then										-- If not totally manual movement
			if position >= 100 then										-- If shutter already completly closed 
				position = 100											-- Set position to 100 %
				setINT()												-- Reenable interrupts
				return													-- Return
			end
			moveDown()													-- Otherwise start down-movement
			for a = 1, 10 do                                            -- Move 1s downward
				tmr.delay(100000)
				if position >= 100 then									-- If position gets 100%
					position = 100										-- Set position to 100%
					setINT()											-- Reenable interrupts
					motionStop()										-- Stop movement
					return												-- Return
				else
					position = position + (100 / down_time)				-- Otherwise calculate new possition dependent on Time for complete down-movement
				end 
			end
			if gpio.read(IO_I2) == 0 then                               -- if buttton is stll pressed => manual down movement
				repeat                                                  -- wait until Down-Button is released
					tmr.delay(100000)									-- Check every 100ms
					if position >= 100 then								-- if position gets 100%
						position = 100									-- If so, set position to 100%
						setINT()										-- Reenable interrupts
						motionStop()									-- Stop movement
						return											-- Return
					else
						position = position + (100 / down_time)			-- Otherwise calculate new possition dependent on Time for complete down-movement
					end 
					until (gpio.read(IO_I2) == 1)						-- Repeat until button is released
				motionStop()											-- Stop movement
				setINT()												-- Reenable interrupts
				return													-- Return
			else														-- If Button isn't pressed after 1s start half-automaitc movement
				fahren = 1												-- Set Movement-Flag
				setINT()												-- Reenable interrupts
				tmr.alarm(4, 100, tmr.ALARM_AUTO, function()			-- Calculate new position every 100ms
					position = position + (100 / down_time)
				end)
				tmr.alarm(5, 100 * (down_time / 100) * (100 - position), tmr.ALARM_SINGLE, function()	-- move downward calculated time to reach position = 100 %
					tmr.unregister(4)									-- Stop calculation of position
					position = 100										-- Set position to 100%
					motionStop()										-- Stop movement
					fahren = 0											-- Reset Movement-Flag
				end)
			end
			setINT()													-- Reenable interrupts
			return														-- Return
		else															-- If totally manual movement flag is set
			moveDown()														-- Otherwise start down-movement
			repeat                                                      -- wait until Down-Button is released
				tmr.delay(100000)										-- Check every 100ms
			until (gpio.read(IO_I2) == 1)								-- Repeat until button is released
			motionStop()												-- Stop movement
			setINT()													-- Reenable interrupts
			return														-- Return
		end
	end

-- Hangling if "up" is pressed -------------------------------------------------------------------------------------------------------
    if gpio.read(IO_I1) == 0 and gpio.read(IO_I2) == 1 and fahren == 0 then
        print("UP")
		if manual_flag == 0 then										-- If not totally manual movement
			if position <= 0 then										-- If shutter is already completely opened
				position = 0											-- Set position to 0%
				setINT()												-- Reenable interrupts 
				return													-- Return
			end
			moveUp()													-- Otherwise start Up-Movement
			for a = 1, 10 do											-- Move 1s upward
				tmr.delay(100000)
				if position <= 0 then									-- If position gets 0%
					position = 0										-- Set position to 0%
					setINT()											-- Reenable interrupts
					motionStop()										-- Stop movement
					return												-- return
				else
					position = position - (100 / up_time)				-- Otherwise calculate new possition dependent on Time for complete up-movement
				end 
			end
			if gpio.read(IO_I1) == 0 then								-- If Up-Botten is still pressed => manual movement mode
				repeat													-- Wait until Up-Botton is released
					tmr.delay(100000)									-- Check every 100ms
					if position <= 0 then								-- If position gets 0%
						position = 0									-- Set position to 0%
						setINT()										-- Reenable interrupts
						motionStop()									-- Stop movement
						return											-- Return
					else
						position = position - (100 / up_time)			-- Otherwise calculate new possition dependent on Time for complete up-movement
					end
				until (gpio.read(IO_I1) == 1)							-- Repeat until button is released
			motionStop()												-- Stop movement
			else														-- If Button isn't pressed after 1s start half-automaitc movement
				fahren = 1												-- Set Movement-Flag
				setINT()												-- Reenable interrupts
				tmr.alarm(4, 100, tmr.ALARM_AUTO, function()			-- Calculate new position every 100ms
					position = position - (100 / up_time)
				end)
				tmr.alarm(5, 100 * (up_time / 100) * position, tmr.ALARM_SINGLE, function()	-- move downward calculated time to reach position = 0%
					tmr.unregister(4)									-- Stop calculation of position
					position = 0										-- Set position to 0%
					motionStop()										-- Stop movement
					fahren = 0											-- Reset Movement-Flag
				end)
			end
			setINT()													-- Reenable interrupt
			return														-- Return
		else															-- If totally manual movement flag is set
			moveUp()													-- Otherwise start down-movement
			repeat                                                      -- wait until Down-Button is released
				tmr.delay(100000)										-- Check every 100ms
			until (gpio.read(IO_I1) == 1)								-- Repeat until button is released
			motionStop()												-- Stop movement
			setINT()													-- Reenable interrupts
			return														-- Return
		end
	end

-- Handling if both buttons are pressed (Teaching-Mode) ------------------------------------------------------------------------------
    if (gpio.read(IO_I1) == 0 and gpio.read(IO_I2) == 0 and fahren == 0) or teach_flag == 1 then
        print("TEACH")
        -- ws2812.write(string.char(255, 0, 0))                
        down_time = 0													-- Set Time for complete Down-Movement to 0s
        up_time = 0														-- Set Time for complete Up-Movement to 0s
        repeat                                                        	-- STEP 1: wait until both buttons released
            tmr.delay(1000)
        until (gpio.read(IO_I1) == 1 and gpio.read(IO_I2) == 1)
        -- ws2812.write(string.char(0, 0, 255))
        repeat                                                        	-- STEP 2: wait until "down" is pushed
            tmr.delay(1000)
        until (gpio.read(IO_I2) == 0)
        moveDown()
		repeat                                                          -- If "down" is pushed, count
            tmr.delay(100000)
            down_time = down_time + 1									-- Count Down-Time in steps of 0.1s
        until (gpio.read(IO_I2) == 1)
		motionStop()
        -- ws2812.write(string.char(0, 0, 255))
		repeat                                                        	-- STEP 3: wait until "up" is pushed
            tmr.delay(1000)
        until (gpio.read(IO_I1) == 0)
		moveUp()
        repeat                                                        	-- If "down" is pushed, count every 0.1s
            tmr.delay(100000)
            up_time = up_time + 1										-- Count Up-Time in steps of 0.1s
        until (gpio.read(IO_I1) == 1)
		motionStop()
		-- ws2812.write(string.char(0, 255, 0))
        tmr.delay(200000)
        print("Down-Time:", down_time, "Up-Time:", up_time)
        write_ini("SmartSwitch.ini", "down_time", down_time)			-- Write new Down-Time to INI-File
        write_ini("SmartSwitch.ini", "up_time", up_time)				-- Write new UP-Time to INI-File
        -- ws2812.write(string.char(0, 0, 0))
		teach_flag = 0
        setINT()														-- Reenable interrupts
        return															-- Return
    end
    setINT()															-- Reenable interrupts
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Main Program ----------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
I2C_SDA = 4                                                             -- Patching of IO-Pins
I2C_SCL = 5
GPIO16 = 0
IO_I1 = 6
IO_I2 = 7
IO_O1 = 2
IO_O2 = 1

gpio.mode(IO_I1, gpio.INT)                                              -- Definition of Interrupt-Pins
gpio.mode(IO_I2, gpio.INT)
gpio.mode(IO_O1, gpio.OUTPUT)											-- Definition of Output-Pins
gpio.mode(IO_O2, gpio.OUTPUT)
gpio.write(IO_O1, gpio.LOW)												-- Set Output-Pins low
gpio.write(IO_O2, gpio.LOW)

sensor_id = string.gsub(wifi.sta.getmac(), ":", "")                     -- Get MAC address for MQTT-ID

setINT()                                                                -- Enable Interrupt

-- ws2812.init()                                                           -- WS2812 LED data pin at GPIO 02
-- ws2812.write(string.char(0, 0, 0)) 

down_time = tonumber(read_ini("SmartSwitch.ini", "down_time"))          -- Variable for "down" duration time
up_time = tonumber(read_ini("SmartSwitch.ini", "up_time"))              -- Variable for "up" duration time
position = tonumber(read_ini("SmartSwitch.ini", "position"))            -- Variable for actual position of shutter

fahren = 0                                                              -- Flag for actual active movement
manual_flag = 0															-- Flag to move manual without calculation and storage of position