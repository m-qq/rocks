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

local selectedLocation = CONFIG.MiningLocation
local selectedOre = CONFIG.Ore
local selectedBankingLocation = CONFIG.BankingLocation
local useOreBox = Utils.toBool(CONFIG.UseOreBox)
local chaseRockertunities = Utils.toBool(CONFIG.ChaseRockertunities)
local threeTickMining = Utils.toBool(CONFIG.ThreeTickMining)
local bankPin = CONFIG.BankPin or ""
local staminaRefreshPercent = tonumber(CONFIG.StaminaRefreshPercent:match("%d+")) or 85

local playerOreBox = nil
local lastInteractTime = 0
local lastInteractTick = 0
local nextTickTarget = 0

local function isMiningActive()
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0 and API.ReadPlayerAnim() ~= 0
end

local function canInteract()
    return os.time() - lastInteractTime >= 3
end

local function shouldThreeTick()
    if not threeTickMining then return false end
    if API.ReadPlayerMovin2() then return false end

    local currentTick = API.Get_tick()
    local ticksSinceLastInteract = currentTick - lastInteractTick

    if lastInteractTick == 0 then
        nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
        return true
    end

    return ticksSinceLastInteract >= nextTickTarget
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
    lastInteractTime = os.time()

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

local function isNearOreLocation(location, selectedOre)
    if not location.oreCoords or not location.oreCoords[selectedOre] then
        return false
    end

    local oreCoord = location.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    local distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    return distance <= 20
end

local function mineRock(oreConfig)
    API.logInfo("Mining " .. oreConfig.name .. "...")
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    lastInteractTime = os.time()
    return Utils.waitOrTerminate(function() return isMiningActive() end, 30, 50, "Failed to start mining")
end

local function threeTickInteract(oreConfig)
    Interact:Object(oreConfig.name, oreConfig.action, 25)
    lastInteractTick = API.Get_tick()
    nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
    API.RandomSleep2(50, 25, 25)
end

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)
API.SetDrawLogs(true)
API.TurnOffMrHasselhoff(false)

if useOreBox then
    playerOreBox = OreBox.find()
    if playerOreBox then
        API.logInfo("Found ore box: " .. OreBox.getName(playerOreBox))
    else
        API.logWarn("No ore box found in inventory")
    end
end

local validated = Utils.validateMiningSetup(
    selectedLocation, selectedOre, selectedBankingLocation,
    playerOreBox, useOreBox,
    LOCATIONS, ORES, Banking, Routes, Teleports, OreBox, DATA
)

if not validated then
    return
end

local location = validated.location
local oreConfig = validated.oreConfig
local bankLocation = validated.bankLocation
useOreBox = validated.useOreBox
playerOreBox = validated.playerOreBox

local oreBoxCapacity = playerOreBox and OreBox.getCapacity(playerOreBox, oreConfig) or 0

local function needsBanking()
    local invFull = Inventory:IsFull()
    local boxFull = OreBox.isFull(playerOreBox, oreConfig)
    return invFull and (not useOreBox or boxFull)
end

local function drawStats()
    local oreName = oreConfig.name:gsub(" rock$", "")
    local statsTable = {
        {"AIO Mining"},
        {""},
        {"Anti-idle in:", Utils.formatTime(idleHandler.getTimeUntilNextIdle())},
        {""},
        {"Location:", location.name},
        {"Banking:", bankLocation.name},
        {"Ore:", oreName},
        {"Stamina:", Utils.getCurrentStamina() .. "/" .. Utils.calculateMaxStamina() .. " (" .. string.format("%.1f%%", Utils.getStaminaPercent()) .. ")"}
    }
    if threeTickMining then
        table.insert(statsTable, {"Mode:", "3-tick"})
    end
    if playerOreBox then
        table.insert(statsTable, {"Ore box:", OreBox.getOreCount(oreConfig) .. "/" .. oreBoxCapacity})
    end
    API.DrawTable(statsTable)
end

API.logInfo("Location: " .. location.name)
API.logInfo("Ore: " .. oreConfig.name)
API.logInfo("Banking: " .. bankLocation.name)
API.logInfo("Use Ore Box: " .. tostring(useOreBox))
API.logInfo("3-tick Mining: " .. tostring(threeTickMining))

while API.Read_LoopyLoop() do
    if not idleHandler.check() then break end
    idleHandler.collectGarbage()
    drawStats()

    if needsBanking() then
        if not Banking.performBanking(bankLocation, location, playerOreBox, oreConfig, bankPin, selectedOre) then
            break
        end
    elseif isNearOreLocation(location, selectedOre) then
        local invFull = Inventory:IsFull()
        local rockertunity = chaseRockertunities and findRockertunity(oreConfig) or nil
        local staminaPercent = Utils.getStaminaPercent()

        if invFull and useOreBox and playerOreBox then
            OreBox.fill(playerOreBox)
        elseif threeTickMining then
            if rockertunity and canInteract() then
                if not mineRockertunity(oreConfig, rockertunity) then break end
                lastInteractTick = API.Get_tick()
                nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
            elseif shouldThreeTick() then
                threeTickInteract(oreConfig)
            end
        elseif rockertunity and canInteract() then
            if not mineRockertunity(oreConfig, rockertunity) then break end
        elseif staminaPercent >= staminaRefreshPercent and canInteract() then
            if not mineRock(oreConfig) then break end
        elseif not isMiningActive() and canInteract() then
            if not mineRock(oreConfig) then break end
        end
    else
        if not Routes.travelTo(location, selectedOre) then break end
        if location.oreWaypoints and location.oreWaypoints[selectedOre] then
            if not Utils.walkThroughWaypoints(location.oreWaypoints[selectedOre]) then break end
            if not Utils.ensureAtOreLocation(location, selectedOre) then break end
        end
    end
    API.RandomSleep2(100, 100, 0)
end

API.logInfo("Script terminated")
