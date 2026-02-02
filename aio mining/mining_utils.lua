local API = require("api")
local DATA = require("aio mining/mining_data")

local Utils = {}

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
        API.printlua(errorMessage or "Condition failed - terminating script", 4, false)
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
    if seconds < 0 then return "0:00" end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function walkToWaypoint(waypoint, threshold)
    threshold = threshold or 6
    local randomX = waypoint.x + math.random(-2, 2)
    local randomY = waypoint.y + math.random(-2, 2)

    API.printlua("Walking to " .. randomX .. ", " .. randomY, 0, false)
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
            API.printlua("Walk timed out after " .. maxTimeout .. " seconds", 4, false)
            return false
        end

        if API.ReadPlayerMovin2() then
            lastMovementTime = os.time()
        elseif os.difftime(os.time(), lastMovementTime) >= stuckTimeout then
            API.printlua("Player stuck for " .. stuckTimeout .. " seconds", 4, false)
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
            API.printlua("Failed to reach waypoint " .. i, 4, false)
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
                    local msg = check.capeName .. " not equipped (level " .. skillLevel .. "). Using fallback route."
                    API.printlua(msg, 4, false)
                    local MiningGUI = require("aio mining/mining_gui")
                    MiningGUI.addWarning(msg)
                    goto continue
                end
            end

            if check.itemName and not bestAvailable then
                bestAvailable = check.itemName
            end

            ::continue::
        end
    end

    if bestAvailable then
        API.printlua("No " .. bestAvailable .. " found. You can get to the mine quicker using one.", 4, false)
    end

    return true
end

function Utils.disableAutoRetaliate()
    if API.GetVarbitValue(DATA.VARBIT_IDS.AUTO_RETALIATE) == 0 then
        API.printlua("Disabling auto-retaliate...", 5, false)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1430, 57, -1, API.OFF_ACT_GeneralInterface_route)
        return Utils.waitOrTerminate(function()
            return API.GetVarbitValue(DATA.VARBIT_IDS.AUTO_RETALIATE) == 1
        end, 10, 100, "Failed to disable auto-retaliate")
    end
    return true
end

local function getMiningStamina(miningLevel)
    if miningLevel < 15 then
        return 0
    end

    for _, milestone in ipairs(DATA.MINING_STAMINA_LEVELS) do
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

function Utils.getStaminaDrain()
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS)
end

function Utils.getStaminaPercent()
    local max = Utils.calculateMaxStamina()
    if max == 0 then return 0 end
    return (Utils.getStaminaDrain() / max) * 100
end

function Utils.getGemBagInfo(gemBagId)
    return DATA.GEM_BAG_INFO[gemBagId]
end

function Utils.findGemBag()
    for id, _ in pairs(DATA.GEM_BAG_INFO) do
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
    local info = DATA.GEM_BAG_INFO[gemBagId]
    if info and info.useVarbits then
        return {
            sapphire = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.sapphire),
            emerald = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.emerald),
            ruby = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.ruby),
            diamond = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.diamond),
            dragonstone = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.dragonstone)
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
    local info = DATA.GEM_BAG_INFO[gemBagId]
    if not info then return 0 end
    if info.useVarbits then
        return info.perGemCapacity * 5
    end
    return info.capacity
end

function Utils.isGemBagFull(gemBagId)
    if not gemBagId then return true end
    local info = DATA.GEM_BAG_INFO[gemBagId]
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
        local inventoryVarbit = API.GetVarbitValue(DATA.VARBIT_IDS.INVENTORY_STATE)
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
    API.printlua("Filling gem bag...", 5, false)
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
        API.printlua("Too far from ore location (distance: " .. math.floor(distance) .. ")", 4, false)
        return false
    end

    API.printlua("Not at ore yet (distance: " .. math.floor(distance) .. "), walking to ore location...", 0, false)
    if not Utils.walkThroughWaypoints({{x = oreCoord.x, y = oreCoord.y}}, 6) then
        API.printlua("Failed to walk to ore location", 4, false)
        return false
    end

    playerCoord = API.PlayerCoord()
    distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    if distance > 20 then
        API.printlua("Still not within 20 units after walking (distance: " .. math.floor(distance) .. ")", 4, false)
        return false
    end

    API.printlua("Reached ore location", 0, false)
    return true
end

function Utils.validateMiningSetup(selectedLocation, selectedOre, selectedBankingLocation, playerOreBox, useOreBox, skipBanking)
    local LOCATIONS = require("aio mining/mining_locations")
    local ORES = require("aio mining/mining_ores")
    local Banking = require("aio mining/mining_banking")
    local Routes = require("aio mining/mining_routes")
    local Teleports = require("aio mining/mining_teleports")
    local OreBox = require("aio mining/mining_orebox")
    local MiningGUI = require("aio mining/mining_gui")
    local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))

    local function fail(msg)
        API.printlua(msg, 4, false)
        MiningGUI.addWarning(msg)
        return nil
    end

    local location = LOCATIONS[selectedLocation]
    if not location then
        return fail("Invalid location: " .. selectedLocation)
    end

    local oreConfig = ORES[selectedOre]
    if not oreConfig then
        return fail("Invalid ore: " .. selectedOre)
    end

    local oreAvailable = false
    for _, ore in ipairs(location.ores) do
        if ore == selectedOre then
            oreAvailable = true
            break
        end
    end
    if not oreAvailable then
        local msg = oreConfig.name .. " is not available at " .. location.name
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
            msg = msg .. ". Available at: " .. table.concat(availableAt, ", ")
        end
        return fail(msg)
    end

    if miningLevel < oreConfig.tier then
        return fail("Mining level " .. miningLevel .. " is below required level " .. oreConfig.tier .. " for " .. oreConfig.name)
    end

    if oreConfig.isStackable then
        useOreBox = false
        playerOreBox = nil
        skipBanking = true
    elseif oreConfig.isGemRock or oreConfig.noOreBox then
        useOreBox = false
        playerOreBox = nil
    elseif useOreBox and not OreBox.validate(playerOreBox, oreConfig) then
        useOreBox = false
        playerOreBox = nil
    end

    for _, dungOre in ipairs(DATA.DUNGEONEERING_ORES) do
        if selectedOre == dungOre then
            if not Teleports.hasRingOfKinship() then
                return fail("Ring of Kinship required for Dungeoneering ores (not found in inventory or equipped)")
            end
            break
        end
    end

    local bankLocation = nil
    if not skipBanking then
        bankLocation = Banking.LOCATIONS[selectedBankingLocation]
        if not bankLocation then
            return fail("Invalid banking location: " .. selectedBankingLocation)
        end
    end

    if not skipBanking and selectedBankingLocation == "player_owned_farm" then
        if API.GetVarbitValue(DATA.VARBIT_IDS.POF_BANK_UNLOCKED) == 0 then
            return fail("Player Owned Farm bank chest is not unlocked")
        end
    end

    if not skipBanking and selectedBankingLocation == "max_guild" then
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
                return fail("Max Guild requires all skills at level 99. " .. skill .. " is level " .. level)
            end
        end
    end

    if not skipBanking and selectedBankingLocation == "deep_sea_fishing_hub" then
        if not Teleports.hasGraceOfTheElves() then
            return fail("Grace of the Elves necklace is not equipped")
        end
        if API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_2) ~= 16 and API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_1) ~= 16 then
            return fail("Deep Sea Fishing Hub is not set as a Max Guild portal destination. Please redirect a Max Guild portal to Deep Sea Fishing Hub.")
        end
    end

    if not skipBanking and selectedBankingLocation == "wars_retreat" then
        if API.GetVarbitValue(DATA.VARBIT_IDS.WARS_RETREAT_UNLOCKED) ~= 1 then
            return fail("War's Retreat teleport is not unlocked")
        end
    end

    if not skipBanking and selectedBankingLocation == "memorial_to_guthix" then
        if not Teleports.hasMemoryStrandFavorited() then
            return fail("Memorial to Guthix requires memory strands favorited in at least one slot")
        end
    end

    if not Routes.validateLodestonesForDestination(location) then
        MiningGUI.addWarning("Required lodestone is not unlocked for " .. location.name)
        return nil
    end
    if not skipBanking and not Routes.validateLodestonesForDestination(bankLocation) then
        MiningGUI.addWarning("Required lodestone is not unlocked for banking location")
        return nil
    end

    Routes.checkLodestonesForDestination(location)
    if not skipBanking then
        Routes.checkLodestonesForDestination(bankLocation)
    end

    if location.requiredVarbits then
        for _, req in ipairs(location.requiredVarbits) do
            if API.GetVarbitValue(req.varbit) ~= req.value then
                return fail(req.message or ("Required varbit " .. req.varbit .. " not met for " .. location.name))
            end
        end
    end

    if location.requiredLevels then
        for _, req in ipairs(location.requiredLevels) do
            local skillLevel = req.skill == "COMBAT" and Utils.getCombatLevel() or API.XPLevelTable(API.GetSkillXP(req.skill))
            if skillLevel < req.level then
                return fail(req.skill .. " level " .. skillLevel .. " is below required level " .. req.level .. " for " .. location.name)
            end
        end
    end

    local routeValid = Utils.validateRouteOptions(location)
    if routeValid == nil then return nil end

    if location.danger then
        local combatLevel = Utils.getCombatLevel()
        if not location.danger.minCombat or combatLevel < location.danger.minCombat then
            local msg = "You may be attacked at this location (combat level " .. combatLevel .. "). Auto-retaliate disabled."
            API.printlua(msg, 4, false)
            MiningGUI.addWarning(msg)
            if not Utils.disableAutoRetaliate() then
                return fail("Failed to disable auto-retaliate")
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

local cachedRocks = nil

function Utils.scanRocks(oreConfig)
    local targetRocks = API.ReadAllObjectsArray({0, 12}, {-1}, {oreConfig.name})
    cachedRocks = {}
    for _, rock in ipairs(targetRocks) do
        cachedRocks[#cachedRocks + 1] = {
            id = rock.Id,
            x = rock.Tile_XYZ.x,
            y = rock.Tile_XYZ.y,
        }
    end
    API.printlua("Scanned " .. #cachedRocks .. " " .. oreConfig.name .. " rocks", 0, false)
end

function Utils.clearRockCache()
    cachedRocks = nil
end

-- Juju potion functions

local jujuRefreshThresholds = {}
local jujuDrinkTime = {}
local jujuDrinkDuration = {}
local jujuLastBuffValue = {}

function Utils.getBuffTimeRemaining(buffId)
    local status = API.Buffbar_GetIDstatus(buffId, false)
    if status and status.found then
        return API.Bbar_ConvToSeconds(status)
    end
    return 0
end

function Utils.needsJujuRefresh(potionDef)
    local remaining = Utils.getBuffTimeRemaining(potionDef.buffId)
    if not jujuRefreshThresholds[potionDef.buffId] then
        jujuRefreshThresholds[potionDef.buffId] = math.random(potionDef.refreshMin, potionDef.refreshMax)
    end
    return remaining <= jujuRefreshThresholds[potionDef.buffId]
end

function Utils.drinkJuju(potionDef)
    local Banking = require("aio mining/mining_banking")
    local potion = Banking.findJujuInInventory(potionDef)
    if not potion then return false end

    local prevTime = Utils.getBuffTimeRemaining(potionDef.buffId)
    API.printlua("Drinking juju potion...", 0, false)
    API.DoAction_Inventory1(potion.id, 0, 1, API.OFF_ACT_GeneralInterface_route)

    if not waitForCondition(function()
        local newTime = Utils.getBuffTimeRemaining(potionDef.buffId)
        if newTime > prevTime then return true end
        if not API.Container_Check_Items(93, {potion.id}) then return true end
        return false
    end, 5, 100) then
        API.printlua("Failed to confirm potion was drunk", 4, false)
        return false
    end

    local newDuration = Utils.getBuffTimeRemaining(potionDef.buffId)
    jujuDrinkTime[potionDef.buffId] = API.ScriptRuntime()
    jujuDrinkDuration[potionDef.buffId] = newDuration
    jujuRefreshThresholds[potionDef.buffId] = nil
    return true
end

function Utils.getJujuTimeUntilRefresh(potionDef)
    if not potionDef then return 0 end

    local buffId = potionDef.buffId
    local buffValue = Utils.getBuffTimeRemaining(buffId)

    -- Detect buff bar updates to sync real-time tracking
    local lastValue = jujuLastBuffValue[buffId]
    if buffValue > 0 and lastValue and lastValue ~= buffValue then
        -- Buff bar just updated, sync our tracking to this moment
        jujuDrinkTime[buffId] = API.ScriptRuntime()
        jujuDrinkDuration[buffId] = buffValue
    end
    jujuLastBuffValue[buffId] = buffValue

    local drinkTime = jujuDrinkTime[buffId]
    local drinkDuration = jujuDrinkDuration[buffId]

    if not drinkTime or not drinkDuration then
        if buffValue <= 0 then return 0 end
        return buffValue
    end

    local elapsed = API.ScriptRuntime() - drinkTime
    local remaining = drinkDuration - elapsed

    local threshold = jujuRefreshThresholds[buffId] or potionDef.refreshMin
    return math.max(0, remaining - threshold)
end

function Utils.forceIdle()
    if API.ReadPlayerAnim() == 0 and not API.ReadPlayerMovin2() then
        return
    end
    local coord = API.PlayerCoord()
    API.DoAction_WalkerW(WPOINT.new(coord.x, coord.y, 0))
    waitForCondition(function()
        return API.ReadPlayerAnim() == 0 and not API.ReadPlayerMovin2()
    end, 5, 100)
    API.RandomSleep2(300, 150, 100)
end

-- Summoning familiar functions

local familiarRefreshThresholds = {}
local familiarSummonTime = {}
local familiarSummonDuration = {}
local familiarLastBuffValue = {}

function Utils.getSummoningPoints()
    local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.SUMMONING_POINTS)
    if result and result[1] and result[1].textids then
        local current, max = result[1].textids:match("^(%d+)/(%d+)$")
        if current then
            return tonumber(current), tonumber(max)
        end
    end
    return 0, 0
end

function Utils.isFamiliarActive(familiarDef)
    local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.SUMMONING_FAMILIAR)
    if result and result[1] and result[1].textids then
        return result[1].textids:lower() == familiarDef.name:lower()
    end
    return false
end

function Utils.needsFamiliarRefresh(familiarDef)
    if Utils.isFamiliarActive(familiarDef) then
        local remaining = Utils.getBuffTimeRemaining(familiarDef.buffId)
        if remaining <= 0 then
            return false
        end
        if not familiarRefreshThresholds[familiarDef.buffId] then
            familiarRefreshThresholds[familiarDef.buffId] = math.random(familiarDef.refreshMin, familiarDef.refreshMax)
        end
        return remaining <= familiarRefreshThresholds[familiarDef.buffId]
    end
    return true
end

function Utils.summonFamiliar(familiarDef)
    if Utils.getSummoningPoints() < familiarDef.pointsCost then
        API.printlua("Not enough summoning points", 4, false)
        return false
    end

    if not API.Container_Check_Items(93, {familiarDef.pouchId}) then
        API.printlua("No summoning pouch in inventory", 4, false)
        return false
    end

    API.printlua("Summoning " .. familiarDef.name .. "...", 0, false)
    API.DoAction_Inventory1(familiarDef.pouchId, 0, 1, API.OFF_ACT_GeneralInterface_route)

    local expectedName = familiarDef.name:lower()
    if not waitForCondition(function()
        local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.SUMMONING_FAMILIAR)
        return result and result[1] and result[1].textids and result[1].textids:lower() == expectedName
    end, 10, 100) then
        API.printlua("Failed to confirm familiar was summoned", 4, false)
        return false
    end

    API.RandomSleep2(600, 300, 300)

    local newDuration = Utils.getBuffTimeRemaining(familiarDef.buffId)
    familiarSummonTime[familiarDef.buffId] = API.ScriptRuntime()
    familiarSummonDuration[familiarDef.buffId] = newDuration
    familiarRefreshThresholds[familiarDef.buffId] = nil
    return true
end

function Utils.getFamiliarTimeUntilRefresh(familiarDef)
    if not familiarDef then return 0 end

    local buffId = familiarDef.buffId
    local buffValue = Utils.getBuffTimeRemaining(buffId)

    local lastValue = familiarLastBuffValue[buffId]
    if buffValue > 0 and lastValue and lastValue ~= buffValue then
        familiarSummonTime[buffId] = API.ScriptRuntime()
        familiarSummonDuration[buffId] = buffValue
    end
    familiarLastBuffValue[buffId] = buffValue

    local summonTime = familiarSummonTime[buffId]
    local summonDuration = familiarSummonDuration[buffId]

    if not summonTime or not summonDuration then
        if buffValue <= 0 then return 0 end
        return buffValue
    end

    local elapsed = API.ScriptRuntime() - summonTime
    local remaining = summonDuration - elapsed

    local threshold = familiarRefreshThresholds[buffId] or familiarDef.refreshMin
    return math.max(0, remaining - threshold)
end

function Utils.canRefreshSummoningPoints(refreshLocation)
    if not refreshLocation then return false end
    if refreshLocation.unlockChecks then
        for _, check in ipairs(refreshLocation.unlockChecks) do
            if API.GetVarbitValue(check.varbit) ~= check.value then
                return false
            end
        end
    end
    return true
end

function Utils.refreshSummoningPoints(miningLocation, selectedOre, familiarDef, oreBoxId, oreConfig, gemBagId, refreshLocation)
    if not Utils.canRefreshSummoningPoints(refreshLocation) then
        if refreshLocation and refreshLocation.unlockChecks then
            for _, check in ipairs(refreshLocation.unlockChecks) do
                if API.GetVarbitValue(check.varbit) ~= check.value then
                    API.printlua(check.message, 4, false)
                    break
                end
            end
        else
            API.printlua("No summoning refresh location configured", 4, false)
        end
        return false, false
    end

    local Routes = require("aio mining/mining_routes")
    local Banking = require("aio mining/mining_banking")

    -- Build destination from refresh location data
    local route = Routes[refreshLocation.routeKey]
    if not route then
        API.printlua("No route found for " .. refreshLocation.name .. " (key: " .. tostring(refreshLocation.routeKey) .. ")", 4, false)
        return false, false
    end

    local destination = {
        name = refreshLocation.name,
        route = route,
        skip_if = refreshLocation.skip_if,
        bank = refreshLocation.bank,
    }

    Utils.forceIdle()

    if not Routes.travelTo(destination) then
        API.printlua("Failed to travel to " .. refreshLocation.name, 4, false)
        return false, false
    end

    -- Wait for refresh object to load
    local obj = refreshLocation.refreshObject
    if obj and obj.id then
        if not waitForCondition(function()
            local objects = API.GetAllObjArray1({obj.id}, 50, {obj.type or 0})
            return #objects > 0
        end, 10, 100) then
            API.printlua(obj.name .. " not found after arriving", 4, false)
            return false, false
        end
    end

    API.RandomSleep2(600, 300, 300)

    local currentPoints, maxPoints = Utils.getSummoningPoints()
    API.printlua("Summoning points: " .. currentPoints .. "/" .. maxPoints, 0, false)
    if maxPoints > 0 and currentPoints >= maxPoints then
        API.printlua("Summoning points already full, skipping " .. obj.name, 0, false)
    else
        API.printlua("Using " .. obj.name .. "...", 0, false)
        Interact:Object(obj.name, obj.action)

        local prevPoints = currentPoints
        if not waitForCondition(function()
            local pts = Utils.getSummoningPoints()
            return pts > prevPoints
        end, 10, 100) then
            API.printlua("Summoning points did not increase", 4, false)
            return false, false
        end

        local restoredPoints = Utils.getSummoningPoints()
        API.printlua("Summoning points restored: " .. restoredPoints, 0, false)
    end
    API.RandomSleep2(600, 300, 300)

    if not Banking.openBank(destination) then
        API.printlua("Failed to open bank at " .. refreshLocation.name, 4, false)
        return false, false
    end

    if not Banking.depositAllItems(oreBoxId, oreConfig, gemBagId) then
        API.printlua("Failed to deposit items", 4, false)
        return false, false
    end

    local hasMorePouches = false
    if familiarDef then
        if Banking.withdrawSummoningPouch(familiarDef) then
            hasMorePouches = API.Container_Check_Items(95, {familiarDef.pouchId})
            local bankItem = API.Container_Get_s(95, familiarDef.pouchId)
            local remaining = bankItem and bankItem.item_stack or 0
            API.printlua(familiarDef.name .. " pouches remaining in bank: " .. remaining, 0, false)
        else
            API.printlua("No " .. familiarDef.name .. " pouches in bank", 4, false)
        end
    end

    if API.BankOpen2() then
        API.KeyboardPress2(0x1B, 60, 100)
        Utils.waitOrTerminate(function()
            return not API.Compare2874Status(24, true)
        end, 5, 100, "Bank did not close")
        API.RandomSleep2(600, 600, 300)
    end

    if familiarDef and Banking.findSummoningPouchInInventory(familiarDef) then
        Utils.summonFamiliar(familiarDef)
    end

    if miningLocation then
        if not Routes.travelTo(miningLocation, selectedOre) then
            API.printlua("Failed to return to mining area after summoning refresh", 4, false)
            return false, hasMorePouches
        end
    end

    return true, hasMorePouches
end

-- Shared mining functions (used by both script and script_gui)

function Utils.isMiningActive(state)
    if state.noStamina or state.miningLevel < 15 then
        return API.ReadPlayerAnim() ~= 0
    end
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0 and API.ReadPlayerAnim() ~= 0
end

local lastNonZeroAnimTime = 0

function Utils.isRecentlyActive(state)
    if API.ReadPlayerAnim() ~= 0 then
        lastNonZeroAnimTime = os.time()
        return true
    end
    return os.difftime(os.time(), lastNonZeroAnimTime) < 10
end

function Utils.canInteract(state)
    return os.time() - state.lastInteractTime >= 3
end

function Utils.shouldThreeTick(cfg, state)
    if not cfg.threeTickMining then return false end
    if API.ReadPlayerMovin2() then return false end

    local currentTick = API.Get_tick()
    local ticksSinceLastInteract = currentTick - state.lastInteractTick

    if state.lastInteractTick == 0 then
        state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
        return true
    end

    return ticksSinceLastInteract >= state.nextTickTarget
end

function Utils.findRockertunity(oreConfig)
    local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, {4})
    if #rockertunities == 0 then return nil end

    if not cachedRocks or #cachedRocks == 0 then return nil end

    for _, rockertunity in ipairs(rockertunities) do
        for _, rock in ipairs(cachedRocks) do
            local customDist = oreConfig.rockertunityDist and oreConfig.rockertunityDist[rock.id]
            local distance = Utils.getDistance(rock.x, rock.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y)
            local match = customDist and (distance <= customDist) or (distance < 1)
            if match then
                return {
                    id = rock.id,
                    x = rock.x,
                    y = rock.y
                }
            end
        end
    end
    return nil
end

function Utils.mineRockertunity(oreConfig, rockTarget, state)
    API.printlua("Mining rockertunity at " .. rockTarget.x .. ", " .. rockTarget.y, 5, false)

    API.RandomSleep2(600, 400, 200)

    local tile = WPOINT.new(rockTarget.x, rockTarget.y, 0)
    API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, {rockTarget.id}, 40, tile)
    state.lastInteractTime = os.time()

    local function isGone()
        local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, {4})
        for _, rockertunity in ipairs(rockertunities) do
            local distance = Utils.getDistance(rockTarget.x, rockTarget.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y)
            if distance <= math.sqrt(2) then
                return false
            end
        end
        return true
    end

    return Utils.waitOrTerminate(isGone, 30, 100, "Rockertunity did not disappear")
end

function Utils.isNearOreLocation(loc, selectedOre)
    if not loc.oreCoords or not loc.oreCoords[selectedOre] then
        return false
    end

    local oreCoord = loc.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    local distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    return distance <= 20
end

function Utils.mineRock(oreConfig, state)
    API.printlua("Mining " .. oreConfig.name .. "...", 5, false)
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    if not Utils.waitOrTerminate(function() return Utils.isMiningActive(state) or Inventory:IsFull() end, 30, 50, "Failed to start mining") then
        return false
    end
    state.lastInteractTime = os.time()
    lastNonZeroAnimTime = os.time()
    API.RandomSleep2(300, 150, 100)
    return true
end

function Utils.threeTickInteract(oreConfig, state)
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    state.lastInteractTick = API.Get_tick()
    state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
    API.RandomSleep2(50, 25, 25)
end

function Utils.hasOresInInventory(ore)
    for _, oreId in ipairs(ore.oreIds) do
        if Inventory:Contains(oreId) then
            return true
        end
    end
    return false
end

function Utils.needsBanking(cfg, ore, state)
    if ore.isStackable then return false end
    if cfg.dropOres then return false end
    if ore.isGemRock and (cfg.dropGems or cfg.cutAndDrop) then return false end
    local invFull = Inventory:IsFull()
    if cfg.useGemBag and state.gemBagId and ore.isGemRock then
        return invFull and Utils.isGemBagFull(state.gemBagId)
    end
    if cfg.useOreBox and state.playerOreBox then
        local OreBox = require("aio mining/mining_orebox")
        if invFull and (OreBox.isFull(state.playerOreBox, ore) or not Utils.hasOresInInventory(ore)) then
            return true
        end
        return false
    end
    return invFull
end

function Utils.waitForMiningToStop(state)
    if Utils.isMiningActive(state) then
        API.printlua("Waiting for mining to stop...", 0, false)
        if not Utils.waitOrTerminate(function()
            return not Utils.isMiningActive(state)
        end, 10, 100, "Mining did not stop") then
            return false
        end
        API.RandomSleep2(300, 150, 100)
    end
    return true
end

function Utils.dropItemById(oreId, displayName, useHotkey)
    local startCount = Inventory:GetItemAmount(oreId)
    if startCount == 0 then return end

    API.printlua("Dropping " .. startCount .. " of " .. displayName .. " (ID: " .. oreId .. ")", 0, false)

    if useHotkey then
        local oreAB = API.GetABs_name(displayName, true)
        if oreAB and oreAB.hotkey and oreAB.hotkey > 0 then
            API.printlua("Found hotkey " .. oreAB.hotkey .. " - holding to drop all", 0, false)
            API.KeyboardDown(oreAB.hotkey)

            local dropStartTime = os.time()
            while Inventory:GetItemAmount(oreId) > 0 and os.difftime(os.time(), dropStartTime) < 15 do
                API.printlua("Dropping... " .. Inventory:GetItemAmount(oreId) .. " remaining", 0, false)
                API.RandomSleep2(300, 100, 100)
            end

            API.KeyboardUp(oreAB.hotkey)
            if Inventory:GetItemAmount(oreId) == 0 then return end
            API.printlua("Failed to drop all via hotkey, switching to manual drop", 4, false)
        end
    end

    while Inventory:GetItemAmount(oreId) > 0 do
        local countBefore = Inventory:GetItemAmount(oreId)
        API.DoAction_Inventory1(oreId, 0, 8, API.OFF_ACT_GeneralInterface_route2)
        if not Utils.waitOrTerminate(function()
            return Inventory:GetItemAmount(oreId) < countBefore
        end, 3, 50, "Failed to drop") then
            break
        end
    end
end

function Utils.dropItemsBySlotOrder(itemIds)
    local idSet = {}
    for _, id in ipairs(itemIds) do idSet[id] = true end

    local totalCount = 0
    for id in pairs(idSet) do
        totalCount = totalCount + Inventory:GetItemAmount(id)
    end
    if totalCount == 0 then return end

    API.printlua("Dropping " .. totalCount .. " gems in slot order", 0, false)

    local allItems = Inventory:GetItems()
    local items = {}
    for _, item in ipairs(allItems) do
        if idSet[item.id] and item.slot then
            items[#items + 1] = item
        end
    end
    table.sort(items, function(a, b) return a.slot < b.slot end)

    for _, item in ipairs(items) do
        if Inventory:GetItemAmount(item.id) > 0 then
            local countBefore = Inventory:GetItemAmount(item.id)
            API.DoAction_Inventory1(item.id, 0, 8, API.OFF_ACT_GeneralInterface_route2)
            if not Utils.waitOrTerminate(function()
                return Inventory:GetItemAmount(item.id) < countBefore
            end, 3, 50, "Failed to drop") then
                break
            end
        end
    end
end

function Utils.dropAllOres(ore, state)
    if not Utils.waitForMiningToStop(state) then return end

    if ore.isGemRock then
        Utils.dropItemsBySlotOrder(ore.oreIds)
    else
        for _, oreId in ipairs(ore.oreIds) do
            local displayName = ore.oreNames and ore.oreNames[oreId] or ore.name:gsub(" rock$", " ore")
            Utils.dropItemById(oreId, displayName, true)
        end
    end
end

function Utils.isGemCuttingInterfaceOpen()
    local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.GEM_CUTTING)
    return result[1] and result[1].textids == "Gem Cutting"
end

function Utils.cutGemType(gemId, gemName, cutName)
    local count = Inventory:GetItemAmount(gemId)
    if count == 0 then return end

    API.printlua("Cutting " .. count .. " " .. gemName .. "...", 0, false)
    API.DoAction_Inventory1(gemId, 0, 1, API.OFF_ACT_GeneralInterface_route)

    API.RandomSleep2(600, 100, 0)

    if Inventory:GetItemAmount(gemId) == 0 then return end

    if not waitForCondition(function()
        return Utils.isGemCuttingInterfaceOpen() or API.isProcessing()
    end, 2, 100) then return end

    if API.isProcessing() then
        Utils.waitOrTerminate(function()
            return Inventory:GetItemAmount(gemId) == 0 and not API.isProcessing()
        end, 6, 100, "Cutting timed out")
    elseif Utils.isGemCuttingInterfaceOpen() then
        API.printlua("Confirming " .. cutName .. " cutting", 0, false)
        API.KeyboardPress2(32, 60, 100)

        if not waitForCondition(function()
            return API.isProcessing()
        end, 10, 100) then return end

        Utils.waitOrTerminate(function()
            return Inventory:GetItemAmount(gemId) == 0 and not API.isProcessing()
        end, 30, 100, "Cutting timed out")
    end

    API.RandomSleep2(300, 200, 100)
end

function Utils.cutAndDropGems(ore, state)
    if not Utils.waitForMiningToStop(state) then return end

    local gemCutMap = {
        [1623] = "Sapphire",
        [1621] = "Emerald",
        [1619] = "Ruby",
        [1617] = "Diamond",
        [1631] = "Dragonstone"
    }

    for _, gemId in ipairs(ore.oreIds) do
        local gemName = ore.oreNames and ore.oreNames[gemId] or ("Gem " .. gemId)
        local cutName = gemCutMap[gemId] or gemName
        Utils.cutGemType(gemId, gemName, cutName)
    end

    Utils.dropItemsBySlotOrder(ore.cutIds)
end

return Utils
