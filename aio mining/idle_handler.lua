local API = require("api")

local idleHandler = {
    startTime = 0,
    randomTime = 0,
}

local function bellRandom(min, max)
    return math.floor((math.random(min, max) + math.random(min, max)) / 2)
end

function idleHandler.init()
    idleHandler.startTime = API.ScriptRuntime()
    idleHandler.randomTime = bellRandom(4*60, 10*60)
end

function idleHandler.check()
    if API.GetGameState2() ~= 3 or API.GetLocalPlayerAddress() == 0 then
        API.printlua("Invalid game state or player address - terminating", 4, false)
        API.Write_LoopyLoop(false)
        return false
    end

    if (API.ScriptRuntime() - idleHandler.startTime) >= idleHandler.randomTime then
        idleHandler.randomTime = bellRandom(4*60, 10*60)
        idleHandler.startTime = API.ScriptRuntime()
        API.PIdle2()
        API.printlua("Anti-idle triggered", 0, false)
    end
    return true
end

function idleHandler.getTimeUntilNextIdle()
    local elapsed = API.ScriptRuntime() - idleHandler.startTime
    return math.max(0, idleHandler.randomTime - elapsed)
end

local lastGCTime = 0

function idleHandler.collectGarbage()
    local now = os.clock()
    if now - lastGCTime >= 5 then
        collectgarbage("step", 500)
        lastGCTime = now
    end
end

return idleHandler
