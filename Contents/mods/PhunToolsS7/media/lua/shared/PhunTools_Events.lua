if isClient() then
    return
end
require("PhunTools_Util")
local PhunTools = PhunTools
local emptyServerTickCount = 0
local emptyServerCalculate = false

function PhunTools:RunOnceWhenServerEmpties(name, fn)
    PhunTools.hooks.emptyServerProcess[name] = fn
end

Events.EveryTenMinutes.Add(function()
    local pt = PhunTools
    print("PhunTools: Checking for empty server " .. tostring(pt))
    if pt:onlinePlayers():size() > 0 then
        emptyServerCalculate = true
    end
end)

Events.OnTickEvenPaused.Add(function()
    if emptyServerCalculate and emptyServerTickCount > 100 then
        local players = PhunTools:onlinePlayers()
        if players:size() == 0 then
            emptyServerCalculate = false
            print("PhunTools: Server is now empty")
            triggerEvent(PhunTools.events.OnPhunServerEmpty, {})
            for k, v in pairs(PhunTools.hooks.emptyServerProcess) do
                print(" - Running hook for " .. k)
                v()
            end
            PhunTools:doLogs()
        end

    elseif emptyServerTickCount > 100 then
        emptyServerTickCount = 0
    else
        emptyServerTickCount = emptyServerTickCount + 1
    end
end)
