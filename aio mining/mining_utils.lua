local API = require("api")
local DATA = require("aio mining/mining_data")
local ORES = require("aio mining/mining_ores")
local idleHandler = require("aio mining/idle_handler")

local Utils = {}

-- Reusable single-element buffers to avoid throwaway table allocations
local containerCheckBuf = {0}
Utils.containerCheckBuf = containerCheckBuf
local objIdBuf = {0}
local objTypeBuf = {0}
local rockertunityTypeBuf = {4}

-- Static lookup table for gem cutting
local gemCutMap = {
    [1625] = "Opal",
    [1627] = "Jade",
    [1629] = "Red topaz",
    [21345] = "Lapis lazuli",
    [1623] = "Sapphire",
    [1621] = "Emerald",
    [1619] = "Ruby",
    [1617] = "Diamond",
    [1631] = "Dragonstone"
}

local gemCraftingReq = {
    [1625] = 1,   -- Opal
    [1627] = 13,  -- Jade
    [1629] = 16,  -- Red topaz
    [21345] = 1,  -- Lapis lazuli
    [1633] = 999, -- Crushed gem (always drop)
    [1623] = 20,  -- Sapphire
    [1621] = 27,  -- Emerald
    [1619] = 34,  -- Ruby
    [1617] = 43,  -- Diamond
    [1631] = 55   -- Dragonstone
}

-- Get the locator target ore from a location's route options
-- Returns the ore key (e.g., "silver") that the locator should teleport to
function Utils.getLocatorOreForLocation(locationKey)
    local LOCATIONS = require("aio mining/mining_locations")
    local location = LOCATIONS[locationKey]
    if not location or not location.routeOptions then return nil end
    for _, option in ipairs(location.routeOptions) do
        if option.condition and option.condition.resourceLocator then
            return option.condition.resourceLocator
        end
    end
    return nil
end

local function waitForCondition(condition, timeout, checkInterval)
    timeout = timeout or 10
    checkInterval = checkInterval or 50
    local startTime = os.clock()
    while (os.clock() - startTime) < timeout and API.Read_LoopyLoop() do
        idleHandler.check()
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

function Utils.isWithinDistance(x1, y1, x2, y2, threshold)
    return (x2 - x1)^2 + (y2 - y1)^2 <= threshold * threshold
end

function Utils.clearTable(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function Utils.checkInterfaceText(interfacePath, expectedText)
    local result = API.ScanForInterfaceTest2Get(false, interfacePath)
    return #result > 0 and result[1].textids == expectedText
end

local chatDialogPath = DATA.RESOURCE_LOCATOR.INTERFACES.CHAT_DIALOG

function Utils.dismissChatDialog()
    local result = API.ScanForInterfaceTest2Get(false, chatDialogPath)
    if #result > 0 and result[1].textids and result[1].textids:find("You found entry") then
        API.printlua("Dismissing dialog...", 0, false)
        API.KeyboardPress2(0x20, 60, 100)
        waitForCondition(function()
            return #API.ScanForInterfaceTest2Get(false, chatDialogPath) == 0
        end, 5, 100)
    end
end

function Utils.waitForAnimCycle(label)
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() > 0 end, 10, 100, label .. " animation did not start")
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, label .. " animation did not finish")
end

function Utils.formatTime(seconds)
    if seconds < 0 then return "0:00" end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

local function walkToWaypoint(waypoint, threshold, waypointIndex)
    threshold = threshold or 6
    local maxTimeout = 30
    local stuckTimeout = 15

    local randomX = waypoint.x + math.random(-2, 2)
    local randomY = waypoint.y + math.random(-2, 2)

    API.DoAction_WalkerW(WPOINT.new(randomX, randomY, 0))

    local absoluteStart = os.clock()
    local lastMovementTime = os.clock()

    while API.Read_LoopyLoop() do
        idleHandler.check()
        local coord = API.PlayerCoord()
        if Utils.isWithinDistance(coord.x, coord.y, waypoint.x, waypoint.y, threshold) then
            return true
        end

        if (os.clock() - absoluteStart) >= maxTimeout then
            local idx = waypointIndex and (" at waypoint " .. waypointIndex) or ""
            API.printlua("Walk timed out" .. idx, 4, false)
            return false
        end

        if API.ReadPlayerMovin2() then
            lastMovementTime = os.clock()
        elseif (os.clock() - lastMovementTime) >= stuckTimeout then
            local idx = waypointIndex and (" at waypoint " .. waypointIndex) or ""
            API.printlua("Player stuck" .. idx, 4, false)
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
        if not walkToWaypoint(waypoint, threshold or 6, i) then
            return false
        end
    end

    return true
end

function Utils.getCombatLevel()
    local vb = API.VB_FindPSettinOrder(DATA.VARBIT_IDS.COMBAT_LEVEL)
    return vb and vb.state or 3
end

function Utils.hasMagicGolemOutfit()
    local outfit = DATA.MAGIC_GOLEM_OUTFIT
    local container = API.Container_Get_all(94)
    if not container then return false end

    local equipped = {}
    for _, slot in ipairs(container) do
        if slot.item_id > 0 then
            equipped[slot.item_id] = true
        end
    end

    return equipped[outfit.head] and equipped[outfit.torso] and equipped[outfit.legs]
        and equipped[outfit.gloves] and equipped[outfit.boots]
end

function Utils.climbLRCRope()
    API.printlua("Climbing rope to Living Rock Caverns...", 0, false)
    Interact:Object("Rope", "Climb", 25)

    -- Wait for warning dialog or climbing animation
    if not Utils.waitOrTerminate(function()
        return Utils.checkInterfaceText(DATA.INTERFACES.LRC_ROPE_WARNING, "Warning")
            or API.ReadPlayerAnim() == 12217
    end, 15, 100, "Failed to interact with LRC rope") then
        return false
    end

    -- Handle warning dialog if present
    if Utils.checkInterfaceText(DATA.INTERFACES.LRC_ROPE_WARNING, "Warning") then
        -- Check if "Don't ask me again" is already checked via varbits
        local dontAskChecked = API.GetVarbitValue(1167) == 7 or API.GetVarbitValue(7417) == 15
        if not dontAskChecked then
            API.printlua("Clicking 'Don't ask me this again'...", 0, false)
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1262, 5, -1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(600, 100, 100)
        end
        API.printlua("Clicking 'Proceed regardless'...", 0, false)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1262, 2, -1, API.OFF_ACT_GeneralInterface_route)
    end

    -- Wait for climbing animation to start
    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 12217
    end, 10, 100, "Rope climbing animation did not start") then
        return false
    end

    -- Wait for climbing to complete
    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 0
    end, 15, 100, "Rope climbing animation did not complete") then
        return false
    end

    API.printlua("Arrived in Living Rock Caverns", 0, false)
    return true
end

local ROUTE_CONDITION_CHECKS = {
    dungeoneeringCape = { skill = "DUNGEONEERING", capeName = "Dungeoneering cape" },
    slayerCape = { skill = "SLAYER", capeName = "Slayer cape" },
    archJournal = { itemName = "Archaeology journal" }
}

function Utils.validateRouteOptions(location, suppressWarnings)
    if not location.routeOptions then return true, nil end

    local Routes = require("aio mining/mining_routes")
    local Teleports = require("aio mining/mining_teleports")
    local checkFns = {
        dungeoneeringCape = Teleports.hasDungeoneeringCape,
        slayerCape = Teleports.hasSlayerCape,
        archJournal = Teleports.hasArchJournal
    }

    local warning = nil
    local bestAvailable = nil
    for _, option in ipairs(location.routeOptions) do
        if not option.condition then break end

        if option.condition.resourceLocator and Routes.useLocator then
            return true, nil
        end

        for key, _ in pairs(option.condition) do
            local check = ROUTE_CONDITION_CHECKS[key]
            if not check then goto continue end

            local hasFn = checkFns[key]
            if hasFn and hasFn() then
                return true, nil
            end

            if check.skill and not suppressWarnings then
                local skillLevel = API.XPLevelTable(API.GetSkillXP(check.skill))
                if skillLevel >= 99 then
                    warning = check.capeName .. " not equipped (level " .. skillLevel .. "). Using fallback route."
                    API.printlua(warning, 4, false)
                    goto continue
                end
            end

            if check.itemName and not bestAvailable then
                bestAvailable = check.itemName
            end

            ::continue::
        end
    end

    if bestAvailable and not suppressWarnings then
        API.printlua("No " .. bestAvailable .. " found. You can get to the mine quicker using one.", 4, false)
    end

    return true, warning
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

local cachedMaxStamina = nil
local cachedMaxStaminaLevel = nil

function Utils.calculateMaxStamina()
    local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
    if miningLevel == cachedMaxStaminaLevel and cachedMaxStamina then
        return cachedMaxStamina
    end
    cachedMaxStaminaLevel = miningLevel
    local agilityLevel = API.XPLevelTable(API.GetSkillXP("AGILITY"))
    cachedMaxStamina = getMiningStamina(miningLevel) + agilityLevel
    return cachedMaxStamina
end

function Utils.getStaminaDrain()
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS)
end

function Utils.getStaminaDrainPercent()
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

local gemCountsBuf = { sapphire = 0, emerald = 0, ruby = 0, diamond = 0, dragonstone = 0 }

function Utils.getGemCounts(gemBagId, out)
    out = out or gemCountsBuf
    local info = DATA.GEM_BAG_INFO[gemBagId]
    if info and info.useVarbits then
        out.sapphire = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.sapphire)
        out.emerald = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.emerald)
        out.ruby = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.ruby)
        out.diamond = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.diamond)
        out.dragonstone = API.GetVarbitValue(DATA.GEM_BAG_VARBITS.dragonstone)
    else
        local val = Utils.getGemBagExtraInt(gemBagId)
        out.sapphire = val % 256
        out.emerald = math.floor(val / 256) % 256
        out.ruby = math.floor(val / 65536) % 256
        out.diamond = math.floor(val / 16777216) % 256
        out.dragonstone = 0
    end
    return out
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

function Utils.ensureInventoryOpen()
    if Inventory:IsOpen() then return true end
    local inventoryVarbit = API.GetVarbitValue(DATA.VARBIT_IDS.INVENTORY_STATE)
    if inventoryVarbit == 1 then
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 9, API.OFF_ACT_GeneralInterface_route)
    elseif inventoryVarbit == 0 then
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1432, 5, 1, API.OFF_ACT_GeneralInterface_route)
    end
    return Utils.waitOrTerminate(function()
        return Inventory:IsOpen()
    end, 10, 100, "Failed to open inventory")
end

function Utils.fillGemBag(gemBagId)
    if not gemBagId then return false end
    if not Utils.ensureInventoryOpen() then return false end
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

--- Check if all skills are at least the given level.
--- Returns (true) or (false, skillName, skillLevel) for the first failing skill.
function Utils.checkAllSkillLevels(minLevel)
    for _, skill in ipairs(DATA.ALL_SKILLS) do
        local level = API.XPLevelTable(API.GetSkillXP(skill))
        if level < minLevel then
            return false, skill, level
        end
    end
    return true
end

-- Bank reachability checks - each returns (ok) or (false, failMsg)
local function getBankReachabilityChecks()
    local Teleports = require("aio mining/mining_teleports")
    return {
        player_owned_farm = function()
            if API.GetVarbitValue(DATA.VARBIT_IDS.POF_BANK_UNLOCKED) == 0 then
                return false, "Player Owned Farm bank chest is not unlocked"
            end
            return true
        end,
        max_guild = function()
            local ok, skill, level = Utils.checkAllSkillLevels(99)
            if not ok then
                return false, "Max Guild requires all skills at level 99. " .. skill .. " is level " .. level
            end
            return true
        end,
        deep_sea_fishing_hub = function()
            if not Teleports.hasGraceOfTheElves() then
                return false, "Grace of the Elves necklace is not equipped"
            end
            if API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_2) ~= 16 and API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_1) ~= 16 then
                return false, "Deep Sea Fishing Hub is not set as a Max Guild portal destination"
            end
            return true
        end,
        wars_retreat = function()
            if API.GetVarbitValue(DATA.VARBIT_IDS.WARS_RETREAT_UNLOCKED) ~= 1 then
                return false, "War's Retreat teleport is not unlocked"
            end
            return true
        end,
        memorial_to_guthix = function()
            if not Teleports.hasMemoryStrandFavorited() then
                return false, "Memorial to Guthix requires memory strands favorited in at least one slot"
            end
            return true
        end,
        archaeology_campus = function()
            if not Teleports.hasArchJournal() then
                return false, "Archaeology Campus bank requires Archaeology journal (not found in inventory or equipped)"
            end
            return true
        end,
        daemonheim_banker = function()
            if not Teleports.hasRingOfKinship() then
                return false, "Daemonheim bank requires Ring of Kinship (not found in inventory or equipped)"
            end
            return true
        end
    }
end

-- Check if a bank location is reachable. Returns (ok, failMsg).
-- If silent is true, does not print to console (for GUI filtering).
function Utils.isBankReachable(bankKey, silent)
    local checks = getBankReachabilityChecks()
    local checkFn = checks[bankKey]
    if not checkFn then return true, nil end

    local ok, failMsg = checkFn()
    if not ok and failMsg and not silent then
        API.printlua(failMsg, 4, false)
    end
    return ok, failMsg
end

function Utils.validateBankReachability(selectedBankingLocation)
    return Utils.isBankReachable(selectedBankingLocation)
end

function Utils.validateMiningSetup(selectedLocation, selectedOre, selectedBankingLocation, playerOreBox, useOreBox, skipBanking)
    -- Lazy requires: these modules depend on mining_utils, so require at call time to avoid circular loads
    local LOCATIONS = require("aio mining/mining_locations")
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

    if not skipBanking then
        local bankOk, bankFailMsg = Utils.validateBankReachability(selectedBankingLocation)
        if not bankOk then
            if bankFailMsg then MiningGUI.addWarning(bankFailMsg) end
            return nil
        end

        if bankLocation.levelReq then
            local level = API.XPLevelTable(API.GetSkillXP(bankLocation.levelReq.skill))
            if level < bankLocation.levelReq.level then
                return fail(bankLocation.levelReq.skill .. " level " .. level .. " is below required level " .. bankLocation.levelReq.level .. " for " .. bankLocation.name)
            end
        end

        if bankLocation.requiredLevels then
            for _, req in ipairs(bankLocation.requiredLevels) do
                local skillLevel = req.skill == "COMBAT" and Utils.getCombatLevel() or API.XPLevelTable(API.GetSkillXP(req.skill))
                if skillLevel < req.level then
                    return fail(req.skill .. " level " .. skillLevel .. " is below required level " .. req.level .. " for " .. bankLocation.name)
                end
            end
        end

        if bankLocation.requiredVarbits then
            for _, req in ipairs(bankLocation.requiredVarbits) do
                if API.GetVarbitValue(req.varbit) ~= req.value then
                    return fail(req.message or ("Required unlock not met for " .. bankLocation.name))
                end
            end
        end

        if bankLocation.noOreBox and useOreBox then
            useOreBox = false
            playerOreBox = nil
            MiningGUI.addWarning(bankLocation.name .. " does not support ore box (Deposit-All will deposit it)")
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

    if location.requiresMagicGolemOutfit then
        if not Utils.hasMagicGolemOutfit() then
            return fail("Magic Golem outfit required for " .. location.name .. " to prevent Living Rock Creature aggression")
        end
    end

    local routeValid, routeWarning = Utils.validateRouteOptions(location, false)
    if routeWarning then MiningGUI.addWarning(routeWarning) end
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
local cachedRockertunityResult = { id = 0, x = 0, y = 0 }
local hasRockertunityResult = false
local lastRockertunityTime = 0

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
    hasRockertunityResult = false
    lastRockertunityTime = 0
end

-- Generic buff tracker factory for juju and summoning
local function createBuffTracker()
    return {
        refreshThresholds = {},
        activateTime = {},
        activateDuration = {},
        lastBuffValue = {},
        locked = {},
    }
end

local jujuTracker = createBuffTracker()
local familiarTracker = createBuffTracker()

function Utils.resetTimerState()
    jujuTracker = createBuffTracker()
    familiarTracker = createBuffTracker()
end

function Utils.getBuffTimeRemaining(buffId)
    local status = API.Buffbar_GetIDstatus(buffId, false)
    if status and status.found then
        return API.Bbar_ConvToSeconds(status)
    end
    return 0
end

local function getTimeUntilRefresh(tracker, buffId, defaultThreshold)
    local buffValue = Utils.getBuffTimeRemaining(buffId)

    if not tracker.locked[buffId] then
        local last = tracker.lastBuffValue[buffId]
        if buffValue > 0 and last and last ~= buffValue then
            tracker.activateTime[buffId] = API.ScriptRuntime()
            tracker.activateDuration[buffId] = buffValue
            tracker.locked[buffId] = true
        end
        tracker.lastBuffValue[buffId] = buffValue
    end

    local activateTime = tracker.activateTime[buffId]
    local activateDuration = tracker.activateDuration[buffId]

    if not activateTime or not activateDuration then
        if buffValue <= 0 then return 0 end
        return buffValue
    end

    local elapsed = API.ScriptRuntime() - activateTime
    local remaining = activateDuration - elapsed
    local threshold = tracker.refreshThresholds[buffId] or defaultThreshold
    return math.max(0, remaining - threshold)
end

local function recordActivation(tracker, buffId, newDuration)
    tracker.activateTime[buffId] = API.ScriptRuntime()
    tracker.activateDuration[buffId] = newDuration
    tracker.refreshThresholds[buffId] = nil
    tracker.locked[buffId] = false
    tracker.lastBuffValue[buffId] = newDuration
end

function Utils.needsJujuRefresh(potionDef)
    local buffId = potionDef.buffId
    if not jujuTracker.refreshThresholds[buffId] then
        jujuTracker.refreshThresholds[buffId] = math.random(potionDef.refreshMin, potionDef.refreshMax)
    end
    return Utils.getJujuTimeUntilRefresh(potionDef) <= 0
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
        containerCheckBuf[1] = potion.id
        if not API.Container_Check_Items(93, containerCheckBuf) then return true end
        return false
    end, 5, 100) then
        API.printlua("Failed to confirm potion was drunk", 4, false)
        return false
    end

    local newDuration = Utils.getBuffTimeRemaining(potionDef.buffId)
    recordActivation(jujuTracker, potionDef.buffId, newDuration)
    return true
end

function Utils.getJujuTimeUntilRefresh(potionDef)
    if not potionDef then return 0 end
    return getTimeUntilRefresh(jujuTracker, potionDef.buffId, potionDef.refreshMin)
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
    local buffId = DATA.SUMMONING_BUFF_ID
    if Utils.isFamiliarActive(familiarDef) then
        local remaining = Utils.getBuffTimeRemaining(buffId)
        if remaining <= 0 then
            return false
        end
        if not familiarTracker.refreshThresholds[buffId] then
            familiarTracker.refreshThresholds[buffId] = math.random(DATA.SUMMONING_REFRESH_MIN, DATA.SUMMONING_REFRESH_MAX)
        end
        return Utils.getFamiliarTimeUntilRefresh(familiarDef) <= 0
    end
    return true
end

function Utils.summonFamiliar(familiarDef)
    if Utils.getSummoningPoints() < familiarDef.pointsCost then
        API.printlua("Not enough summoning points", 4, false)
        return false
    end

    containerCheckBuf[1] = familiarDef.pouchId
    if not API.Container_Check_Items(93, containerCheckBuf) then
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

    local buffId = DATA.SUMMONING_BUFF_ID
    local newDuration = Utils.getBuffTimeRemaining(buffId)
    recordActivation(familiarTracker, buffId, newDuration)
    return true
end

function Utils.getFamiliarTimeUntilRefresh(familiarDef)
    if not familiarDef then return 0 end
    return getTimeUntilRefresh(familiarTracker, DATA.SUMMONING_BUFF_ID, DATA.SUMMONING_REFRESH_MIN)
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

function Utils.refreshSummoningPoints(config)
    local miningLocation = config.miningLocation
    local selectedOre = config.selectedOre
    local familiarDef = config.familiarDef
    local oreBoxId = config.oreBoxId
    local oreConfig = config.oreConfig
    local gemBagId = config.gemBagId
    local refreshLocation = config.refreshLocation

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
        objIdBuf[1] = obj.id
        objTypeBuf[1] = obj.type or 0
        if not waitForCondition(function()
            local objects = API.GetAllObjArray1(objIdBuf, 50, objTypeBuf)
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
            local remaining = Banking.getBankItemCount(familiarDef.pouchId)
            hasMorePouches = remaining > 0
            API.printlua(familiarDef.name .. " pouches remaining in bank: " .. remaining, 0, false)
        end
    end

    Banking.closeBank()

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

local RL = DATA.RESOURCE_LOCATOR

local function isRechargeDialogOpen()
    local result = API.ScanForInterfaceTest2Get(false, RL.INTERFACES.RECHARGE_DIALOG)
    if #result > 0 and result[1].textids then
        return result[1].textids:find("how many charges do you wish to add") ~= nil, result[1].textids
    end
    return false, nil
end

local function typeNumber(num)
    local digits = tostring(num)
    for i = 1, #digits do
        API.KeyboardPress2(digits:byte(i), 40, 60)
        API.RandomSleep2(200, 200, 200)
    end
    API.KeyboardPress2(0x0D, 50, 80)
    API.RandomSleep2(500, 300, 300)
end

-- Opens recharge dialog, adds charges from energy already in inventory.
-- Returns (success, hasMoreEnergy).
function Utils.doRechargeDialog(locator, isEquipped)
    local energyCount = Inventory:GetItemAmount(locator.energyId)
    if energyCount <= 0 then
        API.printlua("No energy in inventory to recharge locator", 4, false)
        return false, false
    end

    -- Unequip locator if currently equipped so we can interact with it in inventory
    if isEquipped then
        API.printlua("Unequipping locator to recharge...", 0, false)
        API.DoAction_Interface(0xffffffff, locator.id, 1, 1464, 15, 3, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 300, 300)
        if not waitForCondition(function()
            return Inventory:Contains(locator.id)
        end, 10, 100) then
            API.printlua("Failed to unequip locator", 4, false)
            return false, false
        end
    end

    API.printlua("Opening recharge dialog for " .. locator.name .. "...", 0, false)
    API.DoAction_Inventory1(locator.id, 0, 7, API.OFF_ACT_GeneralInterface_route2)
    API.RandomSleep2(600, 300, 300)

    local dialogText = nil
    if not waitForCondition(function()
        local open, text = isRechargeDialogOpen()
        if open then dialogText = text end
        return open
    end, 10, 100) then
        API.printlua("Recharge dialog did not open", 4, false)
        return false, false
    end

    local currentCharges = tonumber(dialogText:match("has (%d+)/50"))
    if not currentCharges then
        API.printlua("Could not parse current charges from dialog", 4, false)
        return false, false
    end

    local chargesToAdd = RL.MAX_CHARGES - currentCharges
    local maxFromEnergy = math.floor(energyCount / locator.energyPerCharge)
    local actualAdd = math.min(chargesToAdd, maxFromEnergy)

    if actualAdd <= 0 then
        API.KeyboardPress2(0x1B, 60, 100)
        return false, false
    end

    API.printlua("Adding " .. actualAdd .. " charges (" .. actualAdd * locator.energyPerCharge .. " energy)", 0, false)
    typeNumber(actualAdd)
    API.RandomSleep2(600, 300, 300)

    if not waitForCondition(function()
        local result = API.ScanForInterfaceTest2Get(false, RL.INTERFACES.RECHARGE_CONFIRM)
        return #result > 0 and result[1].textids and result[1].textids:find("This will add")
    end, 10, 100) then
        API.printlua("Recharge confirmation dialog did not appear", 4, false)
        return false, false
    end
    API.KeyboardPress2(0x20, 60, 100)
    API.RandomSleep2(600, 300, 300)

    if not waitForCondition(function()
        local result = API.ScanForInterfaceTest2Get(false, RL.INTERFACES.RECHARGE_CONFIRM2)
        return #result > 0 and result[1].textids and result[1].textids:find("energy to add")
    end, 10, 100) then
        API.printlua("Second recharge confirmation did not appear", 4, false)
        return false, false
    end
    API.KeyboardPress2(0x31, 60, 100)
    API.RandomSleep2(600, 300, 300)

    local Teleports = require("aio mining/mining_teleports")
    waitForCondition(function()
        return Teleports.getLocatorCharges(locator, false) > currentCharges
    end, 5, 100)

    local newCharges = Teleports.getLocatorCharges(locator, false)
    API.printlua("Recharged: " .. currentCharges .. " -> " .. math.floor(newCharges) .. "/" .. RL.MAX_CHARGES, 0, false)

    -- Re-equip if it was originally equipped
    if isEquipped then
        API.printlua("Re-equipping locator...", 0, false)
        API.DoAction_Inventory1(locator.id, 0, 2, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 300, 300)
        waitForCondition(function()
            return not Inventory:Contains(locator.id)
        end, 10, 100)
    end

    return newCharges > currentCharges, maxFromEnergy > actualAdd
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
        lastNonZeroAnimTime = os.clock()
        return true
    end
    return (os.clock() - lastNonZeroAnimTime) < 10
end

function Utils.canInteract(state)
    return os.clock() - state.lastInteractTime >= 3
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
    if not cachedRocks or #cachedRocks == 0 then return nil end

    local now = os.clock()
    if now - lastRockertunityTime < 0.6 then
        return hasRockertunityResult and cachedRockertunityResult or nil
    end
    lastRockertunityTime = now
    hasRockertunityResult = false

    local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, rockertunityTypeBuf)
    if #rockertunities == 0 then return nil end

    for _, rockertunity in ipairs(rockertunities) do
        for _, rock in ipairs(cachedRocks) do
            local customDist = oreConfig.rockertunityDist and oreConfig.rockertunityDist[rock.id]
            local distance = Utils.getDistance(rock.x, rock.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y)
            local match = customDist and (distance <= customDist) or (distance < 1)
            if match then
                cachedRockertunityResult.id = rock.id
                cachedRockertunityResult.x = rock.x
                cachedRockertunityResult.y = rock.y
                hasRockertunityResult = true
                return cachedRockertunityResult
            end
        end
    end
    return nil
end

function Utils.mineRockertunity(oreConfig, rockTarget, state)
    API.printlua("Mining rockertunity at " .. rockTarget.x .. ", " .. rockTarget.y, 0, false)

    API.RandomSleep2(600, 400, 200)

    local tile = WPOINT.new(rockTarget.x, rockTarget.y, 0)
    API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, {rockTarget.id}, 40, tile)
    state.lastInteractTime = os.clock()

    local function isGone()
        local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, rockertunityTypeBuf)
        for _, rockertunity in ipairs(rockertunities) do
            if Utils.isWithinDistance(rockTarget.x, rockTarget.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y, 1.42) then
                return false
            end
        end
        return true
    end

    local success = Utils.waitOrTerminate(isGone, 30, 100, "Rockertunity did not disappear")
    if success then
        hasRockertunityResult = false
        lastRockertunityTime = 0
    end
    return success
end

function Utils.isNearOreLocation(loc, selectedOre)
    if not loc.oreCoords or not loc.oreCoords[selectedOre] then
        return false
    end

    local oreCoord = loc.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    return Utils.isWithinDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y, 20)
end

function Utils.mineRock(oreConfig, state)
    local reason = state.hasInteracted and "Stamina refresh" or "Initial interaction"
    API.printlua("Mining " .. oreConfig.name .. " (" .. reason .. ")", 0, false)
    local tile = nil
    if not oreConfig.interactClosest and not state.hasInteracted and cachedRocks and #cachedRocks > 0 then
        local rock = cachedRocks[math.random(#cachedRocks)]
        tile = WPOINT.new(rock.x, rock.y, 0)
    end
    Interact:Object(oreConfig.name, oreConfig.action, tile, 35)
    if not Utils.waitOrTerminate(function() return Utils.isMiningActive(state) or Inventory:IsFull() end, 30, 50, "Failed to start mining") then
        return false
    end
    state.lastInteractTime = os.clock()
    lastNonZeroAnimTime = os.clock()
    API.RandomSleep2(300, 150, 100)
    return true
end

function Utils.threeTickInteract(oreConfig, state)
    Interact:Object(oreConfig.name, oreConfig.action, 35)
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

-- Recharge locator on-site if we have energy and charges are empty
-- Returns true if recharged, false if no recharge needed or couldn't recharge
function Utils.tryRechargeLocatorOnSite(locationKey)
    local Routes = require("aio mining/mining_routes")
    if not Routes.useLocator then return false end

    local locatorTargetOre = Utils.getLocatorOreForLocation(locationKey)
    if not locatorTargetOre then return false end

    local Teleports = require("aio mining/mining_teleports")
    local locatorDef, locatorEquipped = Teleports.scanForLocator(locatorTargetOre)
    if not locatorDef then return false end

    local charges = Teleports.getLocatorCharges(locatorDef, locatorEquipped)
    if charges > 0 then return false end

    local energyInInventory = Inventory:GetItemAmount(locatorDef.energyId)
    if energyInInventory < locatorDef.energyPerCharge then return false end

    API.printlua("Recharging locator on-site with " .. energyInInventory .. " energy...", 0, false)
    return Utils.doRechargeDialog(locatorDef, locatorEquipped)
end

-- Returns true if we need to bank specifically for locator energy
function Utils.needsLocatorRecharge(locationKey)
    local Routes = require("aio mining/mining_routes")
    if not Routes.useLocator then return false end

    local locatorTargetOre = Utils.getLocatorOreForLocation(locationKey)
    if not locatorTargetOre then return false end

    local Teleports = require("aio mining/mining_teleports")
    local locatorDef, locatorEquipped = Teleports.scanForLocator(locatorTargetOre)
    if not locatorDef then return false end

    local charges = Teleports.getLocatorCharges(locatorDef, locatorEquipped)
    if charges > 0 then return false end

    local energyInInventory = Inventory:GetItemAmount(locatorDef.energyId)
    return energyInInventory < locatorDef.energyPerCharge
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

            local dropStartTime = os.clock()
            while Inventory:GetItemAmount(oreId) > 0 and (os.clock() - dropStartTime) < 15 do
                API.RandomSleep2(300, 100, 100)
            end

            API.KeyboardUp(oreAB.hotkey)
            if Inventory:GetItemAmount(oreId) == 0 then return end
            API.printlua("Hotkey drop incomplete, using manual drop", 4, false)
        end
    end

    -- Fast drop using direct slot targeting
    local allItems = Inventory:GetItems()
    for _, item in ipairs(allItems) do
        if item.id == oreId and item.slot then
            API.DoAction_Interface(0x24, item.id, 8, 1473, 5, item.slot, API.OFF_ACT_GeneralInterface_route2)
            API.RandomSleep2(70, 80, 40)
        end
    end

    -- Wait for drops to complete
    waitForCondition(function()
        return Inventory:GetItemAmount(oreId) == 0
    end, 10, 100)
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

    -- Fast drop using direct slot targeting
    for _, item in ipairs(items) do
        API.DoAction_Interface(0x24, item.id, 8, 1473, 5, item.slot, API.OFF_ACT_GeneralInterface_route2)
        API.RandomSleep2(70, 80, 40)
    end

    -- Wait for all drops to complete
    waitForCondition(function()
        for id in pairs(idSet) do
            if Inventory:GetItemAmount(id) > 0 then return false end
        end
        return true
    end, 10, 100)
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
    if Utils.checkInterfaceText(DATA.INTERFACES.GEM_CUTTING, "Gem Cutting") then
        return true
    end
    if Utils.checkInterfaceText(DATA.INTERFACES.LAPIS_LAZULI_CUTTING, "Lapis Lazuli") then
        return true
    end
    return false
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

    local craftingLevel = API.XPLevelTable(API.GetSkillXP("CRAFTING"))
    local toDrop = {}

    -- Cut what we can, track uncuttable for dropping
    for _, gemId in ipairs(ore.oreIds) do
        local reqLevel = gemCraftingReq[gemId] or 1
        if craftingLevel >= reqLevel then
            local gemName = ore.oreNames and ore.oreNames[gemId] or ("Gem " .. gemId)
            local cutName = gemCutMap[gemId] or gemName
            Utils.cutGemType(gemId, gemName, cutName)
        else
            toDrop[#toDrop + 1] = gemId
        end
    end

    -- Add all cut gem IDs to drop list
    if ore.cutIds then
        for _, cutId in ipairs(ore.cutIds) do
            toDrop[#toDrop + 1] = cutId
        end
    end

    -- Drop everything in one slot-order pass
    if #toDrop > 0 then
        Utils.dropItemsBySlotOrder(toDrop)
    end
end

return Utils
