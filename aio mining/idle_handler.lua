local API = require("api")

local idleHandler = {
    startTime = 0,
    randomTime = 0,
    lastMemoryCheck = 0
}

function idleHandler.init()
    idleHandler.startTime = API.ScriptRuntime()
    idleHandler.randomTime = math.random(5*60, 9*60)
    idleHandler.lastMemoryCheck = collectgarbage("count")
end

function idleHandler.check()
    if API.GetGameState2() ~= 3 or API.GetLocalPlayerAddress() == 0 then
        API.logError("Invalid game state or player address - terminating")
        API.Write_LoopyLoop(false)
        return false
    end

    if (API.ScriptRuntime() - idleHandler.startTime) >= idleHandler.randomTime then
        idleHandler.randomTime = math.random(5*60, 9*60)
        idleHandler.startTime = API.ScriptRuntime()
        API.PIdle2()
        API.logInfo("Anti-idle triggered")
    end
    return true
end

function idleHandler.getTimeUntilNextIdle()
    local elapsed = API.ScriptRuntime() - idleHandler.startTime
    return math.max(0, idleHandler.randomTime - elapsed)
end

function idleHandler.collectGarbage()
    local currentMem = collectgarbage("count")
    local memDiff = currentMem - idleHandler.lastMemoryCheck

    if memDiff >= 1000 then
        collectgarbage("collect")
        local afterMem = collectgarbage("count")
        API.logInfo(string.format("Garbage cleanup - Memory: %.2f KB (freed: %.2f KB)", afterMem, idleHandler.lastMemoryCheck - afterMem))
        idleHandler.lastMemoryCheck = afterMem
    end
end

return idleHandler
