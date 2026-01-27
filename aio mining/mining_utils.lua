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
    local startTime = nil

    while API.Read_LoopyLoop() do
        local coord = API.PlayerCoord()
        if Utils.getDistance(coord.x, coord.y, waypoint.x, waypoint.y) <= threshold then
            return true
        end

        if API.ReadPlayerMovin2() then
            if not startTime then
                startTime = os.time()
            end
            startTime = os.time()
        elseif startTime and os.difftime(os.time(), startTime) >= timeout then
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

-- Mining stamina levels (total stamina at each level threshold)
-- Stamina unlocks at level 15 with 30 base stamina
local MINING_STAMINA_LEVELS = {
    {level = 88, stamina = 110},
    {level = 71, stamina = 100},
    {level = 67, stamina = 90},
    {level = 57, stamina = 80},
    {level = 46, stamina = 70},
    {level = 33, stamina = 60},
    {level = 26, stamina = 50},
    {level = 19, stamina = 40},
    {level = 15, stamina = 30}
}

local function getMiningStamina(miningLevel)
    if miningLevel < 15 then
        return 0
    end

    for _, milestone in ipairs(MINING_STAMINA_LEVELS) do
        if miningLevel >= milestone.level then
            return milestone.stamina
        end
    end

    return 0
end

function Utils.calculateMaxStamina()
    local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
    local agilityLevel = API.XPLevelTable(API.GetSkillXP("AGILITY"))

    local miningStamina = getMiningStamina(miningLevel)
    local agilityBonus = agilityLevel
    local maxStamina = miningStamina + agilityBonus

    return maxStamina
end

function Utils.getCurrentStamina()
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS)
end

function Utils.getStaminaPercent()
    local current = Utils.getCurrentStamina()
    local max = Utils.calculateMaxStamina()

    if max == 0 then
        return 0
    end

    return (current / max) * 100
end

function Utils.ensureAtOreLocation(location, selectedOre)
    if not location.oreCoords or not location.oreCoords[selectedOre] then
        return true
    end

    local oreCoord = location.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    local distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)

    if distance <= 20 then
        return true
    end

    if distance > 50 then
        API.logWarn("Too far from ore location (distance: " .. math.floor(distance) .. ")")
        return false
    end

    API.logInfo("Not at ore yet (distance: " .. math.floor(distance) .. "), walking to ore location...")
    if not Utils.walkThroughWaypoints({{x = oreCoord.x, y = oreCoord.y}}, 6) then
        API.logError("Failed to walk to ore location")
        return false
    end

    playerCoord = API.PlayerCoord()
    distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    if distance > 20 then
        API.logError("Still not within 20 units after walking (distance: " .. math.floor(distance) .. ")")
        return false
    end

    API.logInfo("Reached ore location")
    return true
end

function Utils.validateMiningSetup(selectedLocation, selectedOre, selectedBankingLocation, playerOreBox, useOreBox, LOCATIONS, ORES, Banking, Routes, Teleports, OreBox, DATA)
    local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
    if miningLevel < 15 then
        API.logError("Mining level " .. miningLevel .. " is below 15. This script requires level 15+ Mining (stamina system).")
        return nil
    end

    local location = LOCATIONS[selectedLocation]
    if not location then
        API.logError("Invalid location: " .. selectedLocation)
        return nil
    end

    local oreConfig = ORES[selectedOre]
    if not oreConfig then
        API.logError("Invalid ore: " .. selectedOre)
        return nil
    end

    local oreAvailable = false
    for _, ore in ipairs(location.ores) do
        if ore == selectedOre then
            oreAvailable = true
            break
        end
    end
    if not oreAvailable then
        API.logError(oreConfig.name .. " is not available at " .. location.name)
        local availableAt = {}
        for locKey, loc in pairs(LOCATIONS) do
            for _, ore in ipairs(loc.ores) do
                if ore == selectedOre then
                    table.insert(availableAt, loc.name)
                    break
                end
            end
        end
        if #availableAt > 0 then
            API.logInfo("Available at: " .. table.concat(availableAt, ", "))
        end
        return nil
    end

    if miningLevel < oreConfig.tier then
        API.logError("Mining level " .. miningLevel .. " is below required level " .. oreConfig.tier .. " for " .. oreConfig.name)
        return nil
    end

    if useOreBox and not OreBox.validate(playerOreBox, oreConfig) then
        useOreBox = false
        playerOreBox = nil
    end

    for _, dungOre in ipairs(DATA.DUNGEONEERING_ORES) do
        if selectedOre == dungOre then
            if not Teleports.hasRingOfKinship() then
                API.logError("Ring of Kinship required for Dungeoneering ores (not found in inventory or equipped)")
                return nil
            end
            break
        end
    end

    local bankLocation = Banking.LOCATIONS[selectedBankingLocation]
    if not bankLocation then
        API.logError("Invalid banking location: " .. selectedBankingLocation)
        return nil
    end

    if selectedBankingLocation == "player_owned_farm" then
        if API.GetVarbitValue(DATA.VARBIT_IDS.POF_BANK_UNLOCKED) == 0 then
            API.logError("Player Owned Farm bank chest is not unlocked")
            return nil
        end
    end

    Routes.checkLodestonesForDestination(location)
    Routes.checkLodestonesForDestination(bankLocation)

    if location.requiredLevels then
        for _, req in ipairs(location.requiredLevels) do
            local skillLevel = API.XPLevelTable(API.GetSkillXP(req.skill))
            if skillLevel < req.level then
                API.logError(req.skill .. " level " .. skillLevel .. " is below required level " .. req.level .. " for " .. location.name)
                return nil
            end
        end
    end

    if selectedLocation == "dwarven_mine" or selectedLocation == "dwarven_resource_dungeon" then
        local combatLevel = Utils.getCombatLevel()
        if combatLevel < 45 then
            API.logWarn("Combat level " .. combatLevel .. " is below 45. You may be attacked by scorpions.")
            if not Utils.disableAutoRetaliate() then
                return nil
            end
        end
    elseif selectedLocation == "wilderness_south_west" then
        API.logWarn("Skeletons will attack players of any combat level at this location.")
        if not Utils.disableAutoRetaliate() then
            return nil
        end
    end

    return {
        location = location,
        oreConfig = oreConfig,
        bankLocation = bankLocation,
        useOreBox = useOreBox,
        playerOreBox = playerOreBox
    }
end

return Utils
