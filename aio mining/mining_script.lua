-- version 1

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
    useOreBox = Utils.toBool(CONFIG.UseOreBox),
    chaseRockertunities = Utils.toBool(CONFIG.ChaseRockertunities),
    threeTickMining = Utils.toBool(CONFIG.ThreeTickMining),
    bankPin = CONFIG.BankPin or "",
    staminaRefreshPercent = tonumber(CONFIG.StaminaRefreshPercent:match("%d+")) or 85,
}

if cfg.dropOres then
    cfg.useOreBox = false
end

local state = {
    playerOreBox = nil,
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
    state.lastInteractTime = os.time()
    if not Utils.waitOrTerminate(function() return isMiningActive() end, 30, 50, "Failed to start mining") then
        return false
    end
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
    if cfg.dropOres then
        return false
    end
    local invFull = Inventory:IsFull()
    local boxFull = OreBox.isFull(state.playerOreBox, ore)
    return invFull and (not cfg.useOreBox or boxFull)
end

local function dropAllOres()
    if isMiningActive() then
        API.logInfo("Waiting for mining to stop before dropping...")
        if not Utils.waitOrTerminate(function()
            return not isMiningActive()
        end, 10, 100, "Mining did not stop") then
            return
        end
        API.RandomSleep2(300, 150, 100)
    end

    local oreId = ore.oreId
    local startCount = Inventory:GetItemAmount(oreId)
    local oreName = ore.name:gsub(" rock$", " ore")

    API.logInfo("Starting to drop " .. startCount .. " ores (ID: " .. oreId .. ")")
    API.logInfo("Looking for action bar: '" .. oreName .. "'")

    local oreAB = API.GetABs_name(oreName, true)
    if oreAB and oreAB.hotkey and oreAB.hotkey > 0 then
        API.logInfo("Found hotkey " .. oreAB.hotkey .. " - holding to drop all")
        API.KeyboardDown(oreAB.hotkey)

        local dropStartTime = os.time()
        while Inventory:GetItemAmount(oreId) > 0 and os.difftime(os.time(), dropStartTime) < 15 do
            local currentCount = Inventory:GetItemAmount(oreId)
            API.logInfo("Dropping... " .. currentCount .. " remaining")
            API.RandomSleep2(500, 200, 200)
        end

        API.KeyboardUp(oreAB.hotkey)
        local finalCount = Inventory:GetItemAmount(oreId)
        API.logInfo("Released key. Dropped " .. (startCount - finalCount) .. " ores, " .. finalCount .. " remaining")

        if finalCount > 0 then
            API.logWarn("Failed to drop all ores via hotkey, switching to manual drop")
            while Inventory:GetItemAmount(oreId) > 0 do
                local countBefore = Inventory:GetItemAmount(oreId)
                Inventory:Drop(oreId)
                if not Utils.waitOrTerminate(function()
                    return Inventory:GetItemAmount(oreId) < countBefore
                end, 3, 50, "Failed to drop ore") then
                    break
                end
            end
        end
    else
        API.logInfo("No hotkey found - dropping manually one by one")
        while Inventory:GetItemAmount(oreId) > 0 do
            local countBefore = Inventory:GetItemAmount(oreId)
            API.logInfo("Dropping ore... " .. countBefore .. " remaining")
            Inventory:Drop(oreId)

            if not Utils.waitOrTerminate(function()
                return Inventory:GetItemAmount(oreId) < countBefore
            end, 3, 50, "Failed to drop ore") then
                break
            end
        end
    end

    local endCount = Inventory:GetItemAmount(oreId)
    if endCount == 0 then
        API.logInfo("Successfully dropped all " .. startCount .. " ores")
    else
        API.logError("Failed to drop all ores: started with " .. startCount .. ", still have " .. endCount)
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

    if cfg.dropOres and Inventory:IsFull() then
        dropAllOres()
    elseif needsBanking() then
        if not Banking.performBanking(bank, loc, state.playerOreBox, ore, cfg.bankPin, cfg.ore) then
            break
        end
    elseif isNearOreLocation(loc, cfg.ore) then
        local invFull = Inventory:IsFull()
        local rockertunity = cfg.chaseRockertunities and not invFull and findRockertunity(ore) or nil

        if invFull and cfg.useOreBox and state.playerOreBox then
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
        elseif not isMiningActive() and canInteract() then
            local staminaPercent = Utils.getStaminaPercent()
            if state.miningLevel < 15 or staminaPercent == 0 or staminaPercent >= cfg.staminaRefreshPercent then
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
