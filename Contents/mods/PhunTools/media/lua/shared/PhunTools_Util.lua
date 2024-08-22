local Json = require("PhunToolsJson");
local sandbox = SandboxVars
local string = string

PhunTools = {
    EvoDays = 0,
    events = {
        OnPhunServerEmpty = "OnPhunServerEmpty"
    },
    hooks = {
        emptyServerProcess = {}
    }
}

for _, event in pairs(PhunTools.events) do
    if not Events[event] then
        LuaEventManager.AddEvent(event)
    end
end

--- Returns if the xyz coordinates are powered or not
--- @param xyz table<x=number, y=number, z=number>
--- @return boolean
function PhunTools:isPowered(xyz)
    if xyz and xyz.x and xyz.y then
        local square = getSquare(xyz.x, xyz.y, xyz.z or 0)
        if square and square.haveElectricity and square:haveElectricity() then
            return true
        end
        return sandbox.ElecShutModifier > -1 and GameTime:getInstance():getNightsSurvived() < sandbox.ElecShutModifier
    end
    return false
end

--- prints a table to the consoles
--- @param t table
--- @param indent string
function PhunTools:printTable(t, indent)
    indent = indent or ""
    for key, value in pairs(t or {}) do
        if type(value) == "table" then
            print(indent .. key .. ":")
            PhunTools:printTable(value, indent .. "  ")
        elseif type(value) ~= "function" then
            print(indent .. key .. ": " .. tostring(value))
        end
    end
end

--- checks to see if a string starts with a specific substring
--- @param str string
--- @param start string
function PhunTools:startsWith(str, start)
    return string.sub(str or "", 1, string.len(start or "")) == (start or "")
end

--- checks to see if a string ends with a specific substring
--- @param str string
--- @param char string
function PhunTools:endsWith(str, char)
    return string.sub(str, string.len(char) * -1) == char
end

--- shuffles a table
--- @param originalTable table
--- @return table<string>
function PhunTools:shuffleTable(originalTable)
    local tbl = self:shallowCopyTable(originalTable)
    local n = #tbl
    for i = n, 2, -1 do
        local j = ZombRand(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

--- returns a shallow copy of a table
--- @param original table
--- @return table
function PhunTools:shallowCopyTable(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

--- returns a deep copy of a table
--- @param original table
--- @return table
function PhunTools:deepCopyTable(original)
    local orig_type = type(original)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(original) do
            copy[self:deepCopyTable(orig_key)] = self:deepCopyTable(orig_value)
        end
        setmetatable(copy, self:deepCopyTable(getmetatable(original)))
    else -- number, string, boolean, etc
        copy = original
    end
    return copy
end

-- Function to merge two tables without mutating the originals
function PhunTools:mergeTables(tableA, tableB)
    local mergedTable = {}

    -- Copy entries from tableA to mergedTable
    for k, v in pairs(tableA or {}) do
        if type(v) == "table" then
            mergedTable[k] = self:mergeTables(v, {}) -- Ensure nested tables are copied as well
        else
            mergedTable[k] = v
        end
    end

    -- Copy entries from tableB to mergedTable, overwriting duplicates from tableA
    for k, v in pairs(tableB or {}) do
        if type(v) == "table" then
            mergedTable[k] = self:mergeTables(v, mergedTable[k] or {}) -- Ensure nested tables are copied as well
        else
            mergedTable[k] = v
        end
    end

    return mergedTable
end

--- returns a string representation of a table
--- @param tbl table
--- @param nokeys boolean
--- @param depth number
function PhunTools:serializeTable(tbl, nokeys, depth)
    res = res or {}
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any non-string and non-number key)
        if type(k) == "string" or type(k) == "number" then
            -- Serialize the key
            if type(k) == "string" then
                k = string.format("%q", k)
            end

            -- Serialize the value
            if type(v) == "table" then
                v = serialize(v)
            elseif type(v) == "string" then
                v = string.format("%q", v)
            else
                v = tostring(v)
            end

            result = result .. string.rep("\t", (depth or 0) + 1)
            -- Combine key and value
            if nokeys then
                result = result .. v .. ",\n"
            else
                result = result .. "[" .. k .. "]=" .. v .. ",\n"
            end
        end
    end
    -- Remove the last comma and close the table
    if result ~= "{" then
        result = result:sub(1, -2)
    end
    result = result .. "}"
    return result
end

--- returns a table where each entry is a line within the file
--- @param filename string path to the file contained in Lua folder of server
--- @return table<string>
function PhunTools:loadLinesIntoTable(filename)
    local data = {}
    local fileReaderObj = getFileReader(filename, false)
    if not fileReaderObj then
        return nil
    end
    local line = fileReaderObj:readLine()
    while line do
        data[#data + 1] = line
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()
    return data
end

--- transforms and returns an array of strings into a table
--- @param tableOfStrings table<string>
--- @return table
local function tableOfStringsToTable(tableOfStrings)
    -- Error handling for accessing the first element
    if not tableOfStrings or type(tableOfStrings) ~= "table" or #tableOfStrings == 0 then
        return nil, " - Invalid input: file contents are not a valid table"
    end

    local startsWithReturn = string.sub(tableOfStrings[1], 1, string.len("return")) == "return"
    local res = nil
    local status, loadstringResult

    if startsWithReturn == true then
        status, loadstringResult = pcall(loadstring, table.concat(tableOfStrings, "\n"))
    else
        status, loadstringResult = pcall(loadstring, "return {" .. table.concat(tableOfStrings, "\n") .. "}")
    end

    if not status then
        return nil, " - Error in loadstring: " .. loadstringResult
    end

    status, res = pcall(loadstringResult)
    if not status then
        return nil, " - Error executing loadstring result: " .. res
    end

    return res, nil
end

--- loads a table from a file
--- @param filename string path to the file contained in Lua folder of server
--- @return table
function PhunTools:loadTable(filename, createIfNotExists)
    local res
    local data = {}
    local fileReaderObj = getFileReader(filename, createIfNotExists == true)
    if not fileReaderObj then
        return nil
    end
    local line = fileReaderObj:readLine()
    local startsWithReturn = nil
    while line do
        if startsWithReturn == nil then
            startsWithReturn = PhunTools:startsWith(line, "return")
        end
        data[#data + 1] = line
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()

    local result, err = tableOfStringsToTable(data)

    if err then
        print("Error loading file " .. filename .. ": " .. err)
    else
        return result
    end

end

local logQueue = {}

function PhunTools:addLogEntry(...)
    local filename = "Phun.log"
    self:addLogEntryToFile(filename, ...)
end

function PhunTools:addLogEntryToFile(filename, ...)
    if not logQueue[filename] then
        logQueue[filename] = {}
    end
    local entry = os.date("%Y-%m-%d %H:%M:%S") .. "\t" .. table.concat({...}, "\t")
    table.insert(logQueue[filename], entry)

end

function PhunTools:doLogs()
    for filename, entries in pairs(logQueue) do
        if #entries > 0 then
            self:appendToFile(filename, entries, true)
            logQueue[filename] = {}
        end
    end
end

function PhunTools:appendToFile(filename, line, createIfNotExist)
    if not line then
        return
    end
    local ls = {}
    if type(line) == "table" then
        ls = line
    else
        ls[1] = line
    end
    local fileWriterObj = getFileWriter(filename, createIfNotExist ~= false, true)
    for _, l in ipairs(ls) do
        if l and l ~= "" then
            fileWriterObj:write(l .. "\r\n")
        end
    end
    fileWriterObj:close()
end

--- saves a table to a file
--- @param fname string path to the file contained in Lua folder of server
--- @param data table
function PhunTools:saveTable(fname, data)
    if not data then
        return
    end
    local fileWriterObj = getFileWriter(fname, true, false)
    local serialized = self:serializeTable(data, true)
    fileWriterObj:write("return " .. serialized .. "")
    fileWriterObj:close()
end

--- loads json from file and transforms it into a table
--- @param path string path to the file contained in Lua folder of server
--- @return table
function PhunTools:loadJsonToTable(path)
    print("Loading json from " .. path)
    local fileReaderObj = getFileReader(path, false);

    if fileReaderObj then
        print("File reader object found")
        local json = "";
        while true do
            local line = fileReaderObj:readLine();
            if not line then
                fileReaderObj:close();
                break
            end
            print("Read line: " .. line)
            json = json .. line;
        end

        return Json.Decode(json);
    else
        print("-------- " .. path .. " NOT FOUND ----------------")
    end
    return nil
end

function PhunTools:timeDifference(time1, time2)
    local diff = (time1 or 0) - (time2 or 0)
    if diff < 0 then
        return 0, 0, 0, 0
    end
    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    local minutes = math.floor((diff % 3600) / 60)
    local seconds = math.floor(diff % 60)
    return days, hours, minutes, seconds
end

function PhunTools:timeDifferenceAsText(time1, time2)
    local days, hours, minutes, seconds = self:timeDifference(time1, time2)
    local result = {}
    if days > 1 then
        table.insert(result, days .. " " .. getText("UI_PhunTools_Days"))
    elseif days > 0 then
        table.insert(result, days .. " " .. getText("UI_PhunTools_Day"))
    end
    if hours > 1 then
        table.insert(result, hours .. " " .. getText("UI_PhunTools_Hours"))
    elseif hours > 0 then
        table.insert(result, hours .. " " .. getText("UI_PhunTools_Hour"))
    end
    if minutes > 1 then
        table.insert(result, minutes .. " " .. getText("UI_PhunTools_Minutes"))
    elseif minutes > 0 then
        table.insert(result, minutes .. " " .. getText("UI_PhunTools_Minute"))
    end

    if #result then
        return table.concat(result, " ")
    else
        return getText("UI_PhunTools_LessThanHour")
    end

end

function PhunTools:timeAgo(fromTime, toTime)
    -- Default to current time if toTime is not provided
    toTime = toTime or os.time()

    -- Calculate the difference in seconds
    local diff = os.difftime(toTime, fromTime)

    -- Define time intervals in seconds
    local secondsInMinute = 60
    local secondsInHour = 3600
    local secondsInDay = 86400
    local secondsInMonth = 2592000 -- Approximate (30 days)
    local secondsInYear = 31536000 -- Approximate (365 days)

    -- Calculate time components
    local years = math.floor(diff / secondsInYear)
    diff = diff % secondsInYear
    local months = math.floor(diff / secondsInMonth)
    diff = diff % secondsInMonth
    local days = math.floor(diff / secondsInDay)
    diff = diff % secondsInDay
    local hours = math.floor(diff / secondsInHour)
    diff = diff % secondsInHour
    local minutes = math.floor(diff / secondsInMinute)
    local seconds = diff % secondsInMinute

    -- Build the result string
    local timeAgo = {}

    if years > 0 then
        table.insert(timeAgo, years .. (years == 1 and " year" or " years"))
    end

    if months > 0 then
        table.insert(timeAgo, months .. (months == 1 and " month" or " months"))
    end

    if days > 0 then
        table.insert(timeAgo, days .. (days == 1 and " day" or " days"))
    end

    if hours > 0 then
        table.insert(timeAgo, hours .. (hours == 1 and " hour" or " hours"))
    end

    if minutes > 0 then
        table.insert(timeAgo, minutes .. (minutes == 1 and " minute" or " minutes"))
    end

    if seconds > 0 and #timeAgo == 0 then
        -- Only include seconds if no larger units are present
        table.insert(timeAgo, seconds .. (seconds == 1 and " second" or " seconds"))
    end

    if #timeAgo == 0 then
        return "Just now"
    else
        return table.concat(timeAgo, ", ") .. " ago"
    end

end

function PhunTools:differenceInMs(startTime, endTime)
    local differenceInMillis = endTime - startTime
    local differenceInSeconds = differenceInMillis
    return string.format("%.2f", differenceInSeconds)
end

function PhunTools:differenceInSeconds(startTime, endTime)
    local differenceInMillis = endTime - startTime
    local differenceInSeconds = differenceInMillis / 1000
    return string.format("%.2f", differenceInSeconds)
end

function PhunTools:getWorldAgeDiffAsString(value)

    local hoursAgo = getGameTime():getWorldAgeHours() - value

    if hoursAgo < 1 then
        return getText("UI_PhunTools_LessThanHour")
    elseif hoursAgo < 24 then
        return getText("UI_PhunTools_HoursAgo", math.floor(hoursAgo))
    else
        local days = math.floor(hoursAgo / 24)
        -- local hours = math.floor(hoursAgo % 24)
        return getText("UI_PhunTools_DaysAgo", days, hours)
    end

    return
        self:timeDifferenceAsText(math.floor(getGameTime():getWorldAgeHours() * 60 * 60), math.floor(value * 60 * 60))
end

function PhunTools:daysAndHoursSince(since)
    local aged = getGameTime():getWorldAgeHours()
    local total_hours = aged - since
    local hours_per_day = 24
    local total_days, _ = math.modf(total_hours / hours_per_day)
    local remaining_hours, _ = math.modf(total_hours % hours_per_day)

    return {
        days = total_days,
        hours = remaining_hours
    }
end

function PhunTools:inArray(value, arr)
    for _, v in ipairs(arr) do
        if v == value then
            return true
        end
    end
    return false
end

function PhunTools:formatWholeNumber(number)
    number = number or 0
    -- Round the number to remove the decimal part
    local roundedNumber = math.floor(number + 0.5)
    -- Convert to string and format with commas
    local formattedNumber = tostring(roundedNumber):reverse():gsub("(%d%d%d)", "%1,")
    formattedNumber = formattedNumber:reverse():gsub("^,", "")
    return formattedNumber
end

function PhunTools:trimString(s)
    return s:match("^%s*(.-)%s*$")
end

function PhunTools:splitString(v, sep)
    sep = sep or ","
    local t = {}
    -- print("Splitting " .. tostring(v) .. " with " .. sep)
    for str in string.gmatch(v or "", "([^" .. sep .. "]+)") do
        table.insert(t, self:trimString(str))
    end
    return t
end

function PhunTools:debug(...)
    if isDebugEnabled() or isAdmin() or isServer() then
        local args = {...}
        for i, v in ipairs(args) do
            if type(v) == "table" then
                self:printTable(v)
            else
                print(tostring(v))
            end
        end
    end
end

local dayLengthsList = {{
    mins = 15,
    hours = .25
}, {
    mins = 30,
    hours = .5
}, {
    mins = 60,
    hours = 1
}, {
    mins = 120,
    hours = 2
}, {
    mins = 180,
    hours = 3
}, {
    mins = 240,
    hours = 4
}, {
    mins = 300,
    hours = 5
}, {
    mins = 360,
    hours = 6
}, {
    mins = 420,
    hours = 7
}, {
    mins = 480,
    hours = 8
}, {
    mins = 540,
    hours = 9
}, {
    mins = 600,
    hours = 10
}, {
    mins = 660,
    hours = 11
}, {
    mins = 720,
    hours = 12
}, {
    mins = 780,
    hours = 13
}, {
    mins = 840,
    hours = 14
}, {
    mins = 900,
    hours = 15
}, {
    mins = 960,
    hours = 16
}, {
    mins = 1020,
    hours = 17
}, {
    mins = 1080,
    hours = 18
}, {
    mins = 1140,
    hours = 19
}, {
    mins = 1200,
    hours = 20
}, {
    mins = 1260,
    hours = 21
}, {
    mins = 1320,
    hours = 22
}, {
    mins = 1380,
    hours = 23
}, {
    mins = 1440,
    hours = 24
}}

function PhunTools:gameHoursToRealHours(gameHours)
    local oneHour = dayLengthsList[SandboxVars.DayLength].mins
    return math.floor(gameHours / oneHour)
end

local function getTime(year, month, day, hour, minute)
    return os.time {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute
    }
end

function PhunTools:calculateEvoDays()
    local monthsAfterApo = getSandboxOptions():getTimeSinceApo() - 1
    -- no months to count, go away
    if monthsAfterApo <= 0 then
        return 0
    end

    local gameTime = getGameTime()
    local startYear = gameTime:getStartYear()
    -- months of the year start at 0
    local apocStartMonth = (gameTime:getStartMonth() + 1) - monthsAfterApo
    -- roll the year back if apocStartMonth is negative
    if apocStartMonth <= 0 then
        apocStartMonth = 12 + apocStartMonth
        startYear = startYear - 1
    end
    local apocDays = 0
    -- count each month at a time to get correct day count
    for month = 0, monthsAfterApo do
        apocStartMonth = apocStartMonth + 1
        -- roll year forward if needed, reset month
        if apocStartMonth > 12 then
            apocStartMonth = 1
            startYear = startYear + 1
        end
        -- months of the year start at 0
        local daysInM = gameTime:daysInMonth(startYear, apocStartMonth - 1)
        -- if this is the first month being counted subtract starting day date
        if month == 0 then
            daysInM = daysInM - gameTime:getStartDay() + 1
        end
        apocDays = apocDays + daysInM
    end

    return apocDays
end

Events.OnGameStart.Add(function()
    PhunTools.EvoDays = PhunTools:calculateEvoDays()
end)

Events.EveryHours.Add(function()
    PhunTools.EvoDays = PhunTools:calculateEvoDays()
end)

Events.EveryTenMinutes.Add(function()
    PhunTools:doLogs()
end)

