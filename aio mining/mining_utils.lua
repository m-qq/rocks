local API = require("api")
local DATA = require("aio mining/mining_data")

local Utils = {}

function Utils.toBool(value)
    if type(value) == "boolean" then return value end
    if type(value) == "string" then return value == "true" end
    return false
end

local function waitForCondition(condition, timeout, checkInterval)
    timeout = timeout or 10
    checkInterval = checkInterval or 50
    local startTime = os.time()
    while os.difftime(os.time(), startTime) < timeout and API.Read_LoopyLoop() do
        if condition() then return true end
        API.RandomSleep2(checkInterval, 50, 0)
    end
    return false
end

function Utils.waitOrTerminate(condition, timeout, checkInterval, errorMessage)
    if not waitForCondition(condition, timeout, checkInterval) then
        API.logError(errorMessage or "Condition failed - terminating script")
        API.Write_LoopyLoop(false)
        return false
    end
    return true
end

function Utils.isAtRegion(region)
    local playerRegion = API.PlayerRegion()
    return playerRegion.x == region.x and
           playerRegion.y == region.y and
           playerRegion.z == region.z
end

function Utils.getDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

function Utils.formatTime(seconds)
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function walkToWaypoint(waypoint, threshold)
    threshold = threshold or 6
    local randomX = waypoint.x + math.random(-2, 2)
    local randomY = waypoint.y + math.random(-2, 2)

    API.logInfo("Walking to " .. randomX .. ", " .. randomY)
    API.DoAction_WalkerW(WPOINT.new(randomX, randomY, 0))

    local timeout = 15
    local startTime = os.time()

    while API.Read_LoopyLoop() do
        local coord = API.PlayerCoord()
        if Utils.getDistance(coord.x, coord.y, waypoint.x, waypoint.y) <= threshold then
            return true
        end

        if API.ReadPlayerMovin2() then
            startTime = os.time()
        elseif os.difftime(os.time(), startTime) >= timeout then
            return false
        end

        API.RandomSleep2(100, 50, 50)
    end

    return false
end

function Utils.walkThroughWaypoints(waypoints, threshold)
    if not waypoints or #waypoints == 0 then
        return true
    end

    for i, waypoint in ipairs(waypoints) do
        if not walkToWaypoint(waypoint, threshold or 6) then
            API.logWarn("Failed to reach waypoint " .. i)
            return false
        end
    end

    return true
end

function Utils.getCombatLevel()
    return API.VB_FindPSettinOrder(DATA.VARBIT_IDS.COMBAT_LEVEL).state
end

function Utils.disableAutoRetaliate()
    if API.GetVarbitValue(DATA.VARBIT_IDS.AUTO_RETALIATE) == 0 then
        API.logInfo("Disabling auto-retaliate...")
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1430, 57, -1, API.OFF_ACT_GeneralInterface_route)
        return Utils.waitOrTerminate(function()
            return API.GetVarbitValue(DATA.VARBIT_IDS.AUTO_RETALIATE) == 1
        end, 10, 100, "Failed to disable auto-retaliate")
    end
    return true
end

return Utils
