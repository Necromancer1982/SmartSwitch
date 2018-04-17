--------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
----- INI_Handling.lua             ---------------------------------------------------------------------------------------------------
----- INI-Handling for SmartSwitch ---------------------------------------------------------------------------------------------------
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
-- Example for INI-File:                                      ------------------------------------------------------------------------
--                                                            ------------------------------------------------------------------------
-- Timer1_ON#10:17:00                                         ------------------------------------------------------------------------
-- Timer1_OFF#10:17:05                                        ------------------------------------------------------------------------
-- Function#auto                                              ------------------------------------------------------------------------
-- Offset#30                                                  ------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------
-- Rules:                                                     ------------------------------------------------------------------------
--                                                            ------------------------------------------------------------------------
-- Delimiter between Key and Value: #                         ------------------------------------------------------------------------
-- No empty lines allowed!                                    ------------------------------------------------------------------------
-- Firs Key at first line!                                    ------------------------------------------------------------------------
-- Errorflags:                                                ------------------------------------------------------------------------
--   -2: File doesn't exist                                   ------------------------------------------------------------------------
--   -1: Key not found                                        ------------------------------------------------------------------------
--    0: Everything is OK                                     ------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------
-- Function to write to INI-File [INI-Name, INI-Key, Value] --------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function write_ini(ini_fn, key, value)
    errorflag = -2
    if not file.exists(ini_fn) then                                         -- Check if INI-File exists
        return errorflag                                                    -- If not => return errorflag = -2
    end
    errorflag = -1
    file.open(ini_fn, "r")                                                  -- Open file in Read-Mode
    count = 0                                                               -- Line Counter
    content = {}                                                            -- Array for INI-Content
    repeat                                                                  -- Read INI-Lines in Array
        count = count + 1
        content[count] = file.readline()
    until content[count] == nil
    loops = count - 1                                                       -- Number of Lines in INI-File
    file.close()                                                            -- Close file
    count = 1
    for i = 1, loops do                                                     -- Search Lines for Key
        if content[i] ~= nil then
            s, e = string.find(content[i], key)
            if s ~= nil then                                                -- If Key is found
                content[i] = string.sub(content[i], 1, e + 1)..value        -- Extract Key + delimiter and add new value
                errorflag = 0                                               -- no error
            end
        end
    end
    file.open(ini_fn, "w+")                                                 -- Open file in Edit-Mode
    for i = 1, loops do                                                     -- Write INI-File with new content
        file.writeline(content[i])                                                  
    end
    file.close()                                                            -- Close file
    ----- Handling of "Double-Carridge-Returns after Line-insertion -----
    file.open(ini_fn, "r")                                                -- Open INI-File
    f_c = file.read()                                                       -- Read File-Content into variable
    file.close()                                                            -- Close INI-File
    cr = string.char(10)                                                    -- Define Single-Carridge-Return
    cr2 = cr..cr                                                            -- Define Double-Carridge-Return
    f_c = string.gsub(f_c, cr2, cr)                                         -- Substitude all Double-Carridge-Return
    file.open(ini_fn, "w+")                                               -- Open INI-File
    file.write(f_c)                                                         -- Write corrected content into INI-File
    file.close()                                                            -- Close INI-File
    return errorflag                                                        -- 0: OK   -1: Key not found   -2: File not found
end

--------------------------------------------------------------------------------------------------------------------------------------
-- Function to read INI-File [INI-Name, Value]  --------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------
function read_ini(ini_fn, key)
    errorflag = -2
    if not file.exists(ini_fn) then
        return errorflag
    end
    value = -1
    file.open(ini_fn, "r")                                                  -- Open file in Read-Mode
    repeat
        line = file.readline()                                              -- Zeile für Zeile betrachten
        if line ~= nil then                                                 -- solange noch was in der Zeile steht
            s, e = string.find(line, key)                                   -- schauen, ob der Key in der Zeile vorhanden ist
            if s ~= nil then                                                -- falls ja
                e = e + 2                                                   -- Anfang des Values (Trennzeichen übergehen)
                value = string.sub(line, e)                                 -- Value extrahieren
                value = string.gsub(value, string.char(10), "")             -- Substitude all Double-Carridge-Return
            end
        end
    until line == nil
    file.close()                                                            -- Close file
    return value
end
