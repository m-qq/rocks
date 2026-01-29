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

    local maxTimeout = 30
    local stuckTimeout = 15
    local absoluteStart = os.time()
    local lastMovementTime = os.time()

    while API.Read_LoopyLoop() do
        local coord = API.PlayerCoord()
        if Utils.getDistance(coord.x, coord.y, waypoint.x, waypoint.y) <= threshold then
            return true
        end

        if os.difftime(os.time(), absoluteStart) >= maxTimeout then
            API.logWarn("Walk timed out after " .. maxTimeout .. " seconds")
            return false
        end

        if API.ReadPlayerMovin2() then
            lastMovementTime = os.time()
        elseif os.difftime(os.time(), lastMovementTime) >= stuckTimeout then
            API.logWarn("Player stuck for " .. stuckTimeout .. " seconds")
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

local ROUTE_CONDITION_CHECKS = {
    dungeoneeringCape = { skill = "DUNGEONEERING", capeName = "Dungeoneering cape" },
    slayerCape = { skill = "SLAYER", capeName = "Slayer cape" },
    archJournal = { itemName = "Archaeology journal" }
}

function Utils.validateRouteOptions(location)
    if not location.routeOptions then return true end

    local Teleports = require("aio mining/mining_teleports")
    local checkFns = {
        dungeoneeringCape = Teleports.hasDungeoneeringCape,
        slayerCape = Teleports.hasSlayerCape,
        archJournal = Teleports.hasArchJournal
    }

    local bestAvailable = nil
    for _, option in ipairs(location.routeOptions) do
        if not option.condition then break end
        for key, _ in pairs(option.condition) do
            local check = ROUTE_CONDITION_CHECKS[key]
            if not check then goto continue end

            local hasFn = checkFns[key]
            if hasFn and hasFn() then
                return true
            end

            if check.skill then
                local skillLevel = API.XPLevelTable(API.GetSkillXP(check.skill))
                if skillLevel >= 99 then
                    API.logError(check.skill:sub(1,1) .. check.skill:sub(2):lower() .. " level " .. skillLevel .. " detected but no " .. check.capeName .. " equipped.")
                    API.logError("A more efficient route is available using the " .. check.capeName .. ".")
                    API.logError("Please equip a " .. check.capeName .. " and restart the script.")
                    API.Write_LoopyLoop(false)
                    return nil
                end
            end

            if check.itemName and not bestAvailable then
                bestAvailable = check.itemName
            end

            ::continue::
        end
    end

    if bestAvailable then
        API.logWarn("No " .. bestAvailable .. " found. You can get to the mine quicker using one.")
    end

    return true
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

local GEM_BAG_INFO = {
    [18338] = { name = "Gem bag", capacity = 100, useVarbits = false },
    [31455] = { name = "Upgraded gem bag", perGemCapacity = 60, useVarbits = true }
}

local GEM_BAG_VARBITS = {
    sapphire = 22581,
    emerald = 22582,
    ruby = 22583,
    diamond = 22584,
    dragonstone = 22585
}

function Utils.getGemBagInfo(gemBagId)
    return GEM_BAG_INFO[gemBagId]
end

function Utils.findGemBag()
    for id, _ in pairs(GEM_BAG_INFO) do
        if Inventory:Contains(id) then
            return id
        end
    end
    return nil
end

function Utils.getGemBagExtraInt(gemBagId)
    local item = API.Container_Get_s(93, gemBagId)
    if not item then return 0 end
    return item.Extra_ints[2] or 0
end

function Utils.getGemCounts(gemBagId)
    local info = GEM_BAG_INFO[gemBagId]
    if info and info.useVarbits then
        return {
            sapphire = API.GetVarbitValue(GEM_BAG_VARBITS.sapphire),
            emerald = API.GetVarbitValue(GEM_BAG_VARBITS.emerald),
            ruby = API.GetVarbitValue(GEM_BAG_VARBITS.ruby),
            diamond = API.GetVarbitValue(GEM_BAG_VARBITS.diamond),
            dragonstone = API.GetVarbitValue(GEM_BAG_VARBITS.dragonstone)
        }
    end
    local val = Utils.getGemBagExtraInt(gemBagId)
    return {
        sapphire = val % 256,
        emerald = math.floor(val / 256) % 256,
        ruby = math.floor(val / 65536) % 256,
        diamond = math.floor(val / 16777216) % 256,
        dragonstone = 0
    }
end

function Utils.getGemBagTotal(gemBagId)
    local counts = Utils.getGemCounts(gemBagId)
    return counts.sapphire + counts.emerald + counts.ruby + counts.diamond + counts.dragonstone
end

function Utils.getGemBagCapacity(gemBagId)
    local info = GEM_BAG_INFO[gemBagId]
    if not info then return 0 end
    if info.useVarbits then
        return info.perGemCapacity * 5
    end
    return info.capacity
end

function Utils.isGemBagFull(gemBagId)
    if not gemBagId then return true end
    local info = GEM_BAG_INFO[gemBagId]
    if info and info.useVarbits then
        local counts = Utils.getGemCounts(gemBagId)
        return counts.sapphire >= info.perGemCapacity
            or counts.emerald >= info.perGemCapacity
            or counts.ruby >= info.perGemCapacity
            or counts.diamond >= info.perGemCapacity
            or counts.dragonstone >= info.perGemCapacity
    end
    return Utils.getGemBagTotal(gemBagId) >= Utils.getGemBagCapacity(gemBagId)
end

function Utils.fillGemBag(gemBagId)
    if not gemBagId then return false end
    if not Inventory:IsOpen() then
        local inventoryVarbit = API.GetVarbitValue(21816)
        if inventoryVarbit == 1 then
            API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 9, API.OFF_ACT_GeneralInterface_route)
        elseif inventoryVarbit == 0 then
            API.DoAction_Interface(0xc2, 0xffffffff, 1, 1432, 5, 1, API.OFF_ACT_GeneralInterface_route)
        end
        if not Utils.waitOrTerminate(function()
            return Inventory:IsOpen()
        end, 10, 100, "Failed to open inventory") then
            return false
        end
    end
    API.logInfo("Filling gem bag...")
    local totalBefore = Utils.getGemBagTotal(gemBagId)
    API.DoAction_Inventory1(gemBagId, 0, 1, API.OFF_ACT_GeneralInterface_route)
    Utils.waitOrTerminate(function()
        return Utils.getGemBagTotal(gemBagId) > totalBefore
    end, 5, 100, "Failed to fill gem bag")
    API.RandomSleep2(600, 200, 200)
    return true
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

function Utils.validateMiningSetup(selectedLocation, selectedOre, selectedBankingLocation, playerOreBox, useOreBox, dropOres)
    local LOCATIONS = require("aio mining/mining_locations")
    local ORES = require("aio mining/mining_ores")
    local Banking = require("aio mining/mining_banking")
    local Routes = require("aio mining/mining_routes")
    local Teleports = require("aio mining/mining_teleports")
    local OreBox = require("aio mining/mining_orebox")
    local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))

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

    if oreConfig.isGemRock then
        useOreBox = false
        playerOreBox = nil
    elseif useOreBox and not OreBox.validate(playerOreBox, oreConfig) then
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

    local bankLocation = nil
    if not dropOres then
        bankLocation = Banking.LOCATIONS[selectedBankingLocation]
        if not bankLocation then
            API.logError("Invalid banking location: " .. selectedBankingLocation)
            return nil
        end
    end

    if not dropOres and selectedBankingLocation == "player_owned_farm" then
        if API.GetVarbitValue(DATA.VARBIT_IDS.POF_BANK_UNLOCKED) == 0 then
            API.logError("Player Owned Farm bank chest is not unlocked")
            return nil
        end
    end

    if not dropOres and selectedBankingLocation == "max_guild" then
        local allSkills = {
            "ATTACK", "STRENGTH", "RANGED", "MAGIC", "DEFENCE", "CONSTITUTION",
            "PRAYER", "SUMMONING", "DUNGEONEERING", "AGILITY", "THIEVING", "SLAYER",
            "HUNTER", "SMITHING", "CRAFTING", "FLETCHING", "HERBLORE", "RUNECRAFTING",
            "COOKING", "CONSTRUCTION", "FIREMAKING", "WOODCUTTING", "FARMING",
            "FISHING", "MINING", "DIVINATION", "INVENTION", "ARCHAEOLOGY", "NECROMANCY"
        }
        for _, skill in ipairs(allSkills) do
            local level = API.XPLevelTable(API.GetSkillXP(skill))
            if level < 99 then
                API.logError("Max Guild requires all skills at level 99. " .. skill .. " is level " .. level)
                return nil
            end
        end

    end

    if not dropOres and selectedBankingLocation == "deep_sea_fishing_hub" then
        if not Teleports.hasGraceOfTheElves() then
            API.logError("Grace of the Elves necklace is not equipped")
            return nil
        end
        if API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_2) ~= 16 and API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_1) ~= 16 then
            API.logError("Deep Sea Fishing Hub is not set as a Max Guild portal destination. Please redirect a Max Guild portal to Deep Sea Fishing Hub.")
            return nil
        end
    end

    if not dropOres and selectedBankingLocation == "wars_retreat" then
        if API.GetVarbitValue(DATA.VARBIT_IDS.WARS_RETREAT_UNLOCKED) ~= 1 then
            API.logError("War's Retreat teleport is not unlocked")
            return nil
        end
    end

    if not Routes.validateLodestonesForDestination(location) then
        return nil
    end
    if not dropOres and not Routes.validateLodestonesForDestination(bankLocation) then
        return nil
    end

    Routes.checkLodestonesForDestination(location)
    if not dropOres then
        Routes.checkLodestonesForDestination(bankLocation)
    end

    if location.requiredLevels then
        for _, req in ipairs(location.requiredLevels) do
            local skillLevel = req.skill == "COMBAT" and Utils.getCombatLevel() or API.XPLevelTable(API.GetSkillXP(req.skill))
            if skillLevel < req.level then
                API.logError(req.skill .. " level " .. skillLevel .. " is below required level " .. req.level .. " for " .. location.name)
                return nil
            end
        end
    end

    local routeValid = Utils.validateRouteOptions(location)
    if routeValid == nil then return nil end

    if location.danger then
        local combatLevel = Utils.getCombatLevel()
        if not location.danger.minCombat or combatLevel < location.danger.minCombat then
            API.logWarn("You may be attacked at this location. Disabling auto-retaliate.")
            if not Utils.disableAutoRetaliate() then
                return nil
            end
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
