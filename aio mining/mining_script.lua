local API = require("api")
local idleHandler = require("aio mining/idle_handler")
local ORES = require("aio mining/mining_ores")
local LOCATIONS = require("aio mining/mining_locations")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")
local OreBox = require("aio mining/mining_orebox")
local Routes = require("aio mining/mining_routes")
local Banking = require("aio mining/mining_banking")
local Teleports = require("aio mining/mining_teleports")

idleHandler.init()

API.ClearLog()

local cfg = {
    location = CONFIG.MiningLocation,
    ore = CONFIG.Ore,
    bankLocation = CONFIG.BankingLocation,
    dropOres = Utils.toBool(CONFIG.DropOres),
    dropGems = Utils.toBool(CONFIG.DropGems),
    useOreBox = Utils.toBool(CONFIG.UseOreBox),
    chaseRockertunities = Utils.toBool(CONFIG.ChaseRockertunities),
    threeTickMining = Utils.toBool(CONFIG.ThreeTickMining),
    cutAndDrop = Utils.toBool(CONFIG.CutAndDrop),
    useGemBag = Utils.toBool(CONFIG.UseGemBag),
    bankPin = CONFIG.BankPin or "",
    staminaRefreshPercent = tonumber(CONFIG.StaminaRefreshPercent:match("%d+")) or 85,
}

if cfg.useGemBag then
    cfg.dropGems = false
    cfg.cutAndDrop = false
end

if cfg.cutAndDrop then
    cfg.dropGems = false
end

if cfg.dropOres then
    cfg.useOreBox = false
end

local state = {
    playerOreBox = nil,
    gemBagId = nil,
    lastInteractTime = 0,
    lastInteractTick = 0,
    nextTickTarget = 0,
    miningLevel = API.XPLevelTable(API.GetSkillXP("MINING")),
}

local function isMiningActive()
    if state.miningLevel < 15 then
        return API.ReadPlayerAnim() ~= 0
    end
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0 and API.ReadPlayerAnim() ~= 0
end

local function canInteract()
    return os.time() - state.lastInteractTime >= 3
end

local function shouldThreeTick()
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

local function findRockertunity(oreConfig)
    local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, {4})
    if #rockertunities == 0 then return nil end

    local targetRocks = API.ReadAllObjectsArray({0, 12}, {-1}, {oreConfig.name})
    if #targetRocks == 0 then return nil end

    for _, rockertunity in ipairs(rockertunities) do
        for _, rock in ipairs(targetRocks) do
            local distance = Utils.getDistance(rock.Tile_XYZ.x, rock.Tile_XYZ.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y)
            if distance < 1 then
                return {
                    id = rock.Id,
                    x = rock.Tile_XYZ.x,
                    y = rock.Tile_XYZ.y
                }
            end
        end
    end
    return nil
end

local function mineRockertunity(oreConfig, rockTarget)
    API.logInfo("Mining rockertunity at " .. rockTarget.x .. ", " .. rockTarget.y)

    API.RandomSleep2(600, 400, 200)

    local tile = WPOINT.new(rockTarget.x, rockTarget.y, 0)
    API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, {rockTarget.id}, 40, tile)
    state.lastInteractTime = os.time()

    local function isGone()
        local rockertunities = API.GetAllObjArray1(DATA.ROCKERTUNITY_IDS, 20, {4})
        for _, rockertunity in ipairs(rockertunities) do
            local distance = Utils.getDistance(rockTarget.x, rockTarget.y, rockertunity.Tile_XYZ.x, rockertunity.Tile_XYZ.y)
            if distance < 1 then
                return false
            end
        end
        return true
    end

    return Utils.waitOrTerminate(isGone, 30, 100, "Rockertunity did not disappear")
end

local function isNearOreLocation(loc, selectedOre)
    if not loc.oreCoords or not loc.oreCoords[selectedOre] then
        return false
    end

    local oreCoord = loc.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    local distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    return distance <= 20
end

local function mineRock(oreConfig)
    API.logInfo("Mining " .. oreConfig.name .. "...")
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    if not Utils.waitOrTerminate(function() return isMiningActive() or Inventory:IsFull() end, 30, 50, "Failed to start mining") then
        return false
    end
    state.lastInteractTime = os.time()
    API.RandomSleep2(300, 150, 100)
    return true
end

local function threeTickInteract(oreConfig)
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    state.lastInteractTick = API.Get_tick()
    state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
    API.RandomSleep2(50, 25, 25)
end

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)
API.SetDrawLogs(true)
API.TurnOffMrHasselhoff(false)

if cfg.useOreBox then
    state.playerOreBox = OreBox.find()
    if state.playerOreBox then
        API.logInfo("Found ore box: " .. OreBox.getName(state.playerOreBox))
    else
        API.logWarn("No ore box found in inventory")
    end
end

if cfg.useGemBag then
    state.gemBagId = Utils.findGemBag()
    if state.gemBagId then
        local info = Utils.getGemBagInfo(state.gemBagId)
        API.logInfo("Found gem bag: " .. info.name)
    else
        API.logError("Use Gem Bag is enabled but no gem bag found in inventory")
        return
    end
end

local validated = Utils.validateMiningSetup(
    cfg.location, cfg.ore, cfg.bankLocation,
    state.playerOreBox, cfg.useOreBox, cfg.dropOres
)

if not validated then
    return
end

local loc = validated.location
local ore = validated.oreConfig
local bank = validated.bankLocation
cfg.useOreBox = validated.useOreBox
state.playerOreBox = validated.playerOreBox

local oreBoxCapacity = state.playerOreBox and OreBox.getCapacity(state.playerOreBox, ore) or 0

local function needsBanking()
    if cfg.dropOres then return false end
    if ore.isGemRock and (cfg.dropGems or cfg.cutAndDrop) then return false end
    local invFull = Inventory:IsFull()
    if cfg.useGemBag and state.gemBagId then
        return invFull and Utils.isGemBagFull(state.gemBagId)
    end
    local boxFull = OreBox.isFull(state.playerOreBox, ore)
    return invFull and (not cfg.useOreBox or boxFull)
end

local function waitForMiningToStop()
    if isMiningActive() then
        API.logInfo("Waiting for mining to stop...")
        if not Utils.waitOrTerminate(function()
            return not isMiningActive()
        end, 10, 100, "Mining did not stop") then
            return false
        end
        API.RandomSleep2(300, 150, 100)
    end
    return true
end

local function dropItemById(oreId, displayName, useHotkey)
    local startCount = Inventory:GetItemAmount(oreId)
    if startCount == 0 then return end

    API.logInfo("Dropping " .. startCount .. " of " .. displayName .. " (ID: " .. oreId .. ")")

    if useHotkey then
        local oreAB = API.GetABs_name(displayName, true)
        if oreAB and oreAB.hotkey and oreAB.hotkey > 0 then
            API.logInfo("Found hotkey " .. oreAB.hotkey .. " - holding to drop all")
            API.KeyboardDown(oreAB.hotkey)

            local dropStartTime = os.time()
            while Inventory:GetItemAmount(oreId) > 0 and os.difftime(os.time(), dropStartTime) < 15 do
                API.logInfo("Dropping... " .. Inventory:GetItemAmount(oreId) .. " remaining")
                API.RandomSleep2(300, 100, 100)
            end

            API.KeyboardUp(oreAB.hotkey)
            if Inventory:GetItemAmount(oreId) == 0 then return end
            API.logWarn("Failed to drop all via hotkey, switching to manual drop")
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
        API.RandomSleep2(200, 100, 50)
    end
end

local function dropAllOres()
    if not waitForMiningToStop() then return end

    local useHotkey = not ore.isGemRock
    for _, oreId in ipairs(ore.oreIds) do
        local displayName = ore.oreNames and ore.oreNames[oreId] or ore.name:gsub(" rock$", " ore")
        dropItemById(oreId, displayName, useHotkey)
    end
end

local GEM_CUTTING_INTERFACE = { { 1371,7,-1,0 }, { 1371,0,-1,0 }, { 1371,15,-1,0 }, { 1371,25,-1,0 }, { 1371,10,-1,0 }, { 1371,11,-1,0 }, { 1371,27,-1,0 }, { 1371,27,3,0 } }
local GEM_CONFIRM_INTERFACE = { { 1370,0,-1,0 }, { 1370,2,-1,0 }, { 1370,4,-1,0 }, { 1370,5,-1,0 }, { 1370,13,-1,0 } }

local function isGemCuttingInterfaceOpen()
    local result = API.ScanForInterfaceTest2Get(false, GEM_CUTTING_INTERFACE)
    return result[1] and result[1].textids == "Gem Cutting"
end

local function isCuttingGems()
    local vbState = API.VB_FindPSettinOrder(2227)
    return vbState and vbState.state == 1
end

local function cutGemType(gemId, gemName, cutName)
    local count = Inventory:GetItemAmount(gemId)
    if count == 0 then return end

    API.logInfo("Cutting " .. count .. " " .. gemName .. "...")
    API.DoAction_Inventory1(gemId, 0, 1, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return isGemCuttingInterfaceOpen()
    end, 5, 100, "Failed to open gem cutting interface") then
        return
    end

    local attempts = 0
    while attempts < 10 do
        local result = API.ScanForInterfaceTest2Get(false, GEM_CONFIRM_INTERFACE)
        if result[1] and result[1].textids == cutName then
            API.logInfo("Confirming " .. cutName .. " cutting")
            API.KeyboardPress2(32, 60, 100)
            break
        end
        API.RandomSleep2(75, 50, 25)
        attempts = attempts + 1
    end

    if not Utils.waitOrTerminate(function()
        return isCuttingGems()
    end, 5, 100, "Failed to start cutting") then
        return
    end

    Utils.waitOrTerminate(function()
        return not isCuttingGems()
    end, 30, 100, "Cutting timed out")

    API.RandomSleep2(300, 150, 100)
end

local function cutAndDropGems()
    if not waitForMiningToStop() then return end

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
        cutGemType(gemId, gemName, cutName)
    end

    for _, cutId in ipairs(ore.cutIds) do
        local cutName = ore.cutNames and ore.cutNames[cutId] or ("Cut gem " .. cutId)
        dropItemById(cutId, cutName, false)
    end
end

local function drawStats()
    local oreName = ore.name:gsub(" rock$", "")
    local statsTable = {
        {"AIO Mining"},
        {""},
        {"Anti-idle in:", Utils.formatTime(idleHandler.getTimeUntilNextIdle())},
        {""},
        {"Location:", loc.name},
        {"Ore:", oreName}
    }
    if state.miningLevel >= 15 then
        table.insert(statsTable, {"Stamina:", Utils.getCurrentStamina() .. "/" .. Utils.calculateMaxStamina() .. " (" .. string.format("%.1f%%", Utils.getStaminaPercent()) .. ")"})
    end
    if cfg.dropOres then
        table.insert(statsTable, {"Mode:", "Drop"})
    else
        table.insert(statsTable, {"Banking:", bank.name})
    end
    if cfg.threeTickMining then
        table.insert(statsTable, {"Mode:", "3-tick"})
    end
    if state.playerOreBox then
        table.insert(statsTable, {"Ore box:", OreBox.getOreCount(ore) .. "/" .. oreBoxCapacity})
    end
    if state.gemBagId then
        local counts = Utils.getGemCounts(state.gemBagId)
        local total = counts.sapphire + counts.emerald + counts.ruby + counts.diamond + counts.dragonstone
        local capacity = Utils.getGemBagCapacity(state.gemBagId)
        local info = Utils.getGemBagInfo(state.gemBagId)
        local pgc = info and info.perGemCapacity
        table.insert(statsTable, {"Gem bag:", total .. "/" .. capacity})
        if pgc then
            table.insert(statsTable, {"  Sapphire:", counts.sapphire .. "/" .. pgc})
            table.insert(statsTable, {"  Emerald:", counts.emerald .. "/" .. pgc})
            table.insert(statsTable, {"  Ruby:", counts.ruby .. "/" .. pgc})
            table.insert(statsTable, {"  Diamond:", counts.diamond .. "/" .. pgc})
            table.insert(statsTable, {"  Dragonstone:", counts.dragonstone .. "/" .. pgc})
        else
            table.insert(statsTable, {"  Sapphire:", tostring(counts.sapphire)})
            table.insert(statsTable, {"  Emerald:", tostring(counts.emerald)})
            table.insert(statsTable, {"  Ruby:", tostring(counts.ruby)})
            table.insert(statsTable, {"  Diamond:", tostring(counts.diamond)})
        end
    end
    API.DrawTable(statsTable)
end

API.logInfo("Location: " .. loc.name)
API.logInfo("Ore: " .. ore.name)
if not cfg.dropOres then
    API.logInfo("Banking: " .. bank.name)
end
API.logInfo("Drop Ores: " .. tostring(cfg.dropOres))
API.logInfo("Use Ore Box: " .. tostring(cfg.useOreBox))
API.logInfo("3-tick Mining: " .. tostring(cfg.threeTickMining))

while API.Read_LoopyLoop() do
    if not idleHandler.check() then break end
    idleHandler.collectGarbage()
    API.DoRandomEvents()
    state.miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
    drawStats()

    if Inventory:IsFull() and cfg.cutAndDrop and ore.isGemRock then
        cutAndDropGems()
    elseif Inventory:IsFull() and cfg.dropGems and ore.isGemRock then
        dropAllOres()
    elseif cfg.dropOres and Inventory:IsFull() then
        dropAllOres()
    elseif needsBanking() then
        if not Banking.performBanking(bank, loc, state.playerOreBox, ore, cfg.bankPin, cfg.ore, cfg.location, state.gemBagId) then
            break
        end
    elseif isNearOreLocation(loc, cfg.ore) then
        local invFull = Inventory:IsFull()
        local rockertunity = not ore.isGemRock and cfg.chaseRockertunities and not invFull and findRockertunity(ore) or nil

        if invFull and cfg.useGemBag and state.gemBagId and ore.isGemRock and not Utils.isGemBagFull(state.gemBagId) then
            Utils.fillGemBag(state.gemBagId)
        elseif invFull and not ore.isGemRock and cfg.useOreBox and state.playerOreBox and not OreBox.isFull(state.playerOreBox, ore) then
            OreBox.fill(state.playerOreBox)
        elseif cfg.threeTickMining then
            if rockertunity and canInteract() then
                if not mineRockertunity(ore, rockertunity) then break end
                state.lastInteractTick = API.Get_tick()
                state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
            elseif shouldThreeTick() then
                threeTickInteract(ore)
            end
        elseif rockertunity and canInteract() then
            if not mineRockertunity(ore, rockertunity) then break end
        elseif canInteract() then
            local staminaPercent = Utils.getStaminaPercent()
            local miningInProgress = API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0
            if state.miningLevel < 15 or not miningInProgress or staminaPercent >= cfg.staminaRefreshPercent then
                if not mineRock(ore) then break end
            end
        end
    else
        if not Routes.travelTo(loc, cfg.ore) then break end
        if loc.oreWaypoints and loc.oreWaypoints[cfg.ore] then
            if not Utils.walkThroughWaypoints(loc.oreWaypoints[cfg.ore]) then break end
            if not Utils.ensureAtOreLocation(loc, cfg.ore) then break end
        end
    end
    API.RandomSleep2(100, 100, 0)
end

API.logInfo("Script terminated")
