if not isServer() then
    return
end
local PhunTools = PhunTools

local emptyServerTickCount = 0

local emptyServerCalculate = false

function PhunTools:RunOnceWhenServerEmpties(name, fn)
    PhunTools.hooks.emptyServerProcess[name] = fn
end

Events.EveryTenMinutes.Add(function()
    emptyServerCalculate = true
end)

Events.OnTickEvenPaused.Add(function()
    if emptyServerCalculate and emptyServerTickCount > 100 then
        if getOnlinePlayers():size() == 0 then
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
