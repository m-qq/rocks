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
local bankPin = CONFIG.BankPin or ""

local playerOreBox = nil
local staminaThreshold = math.random(160, 190)
local lastMineAttempt = 0

local function isMiningActive()
    return API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0 and API.ReadPlayerAnim() ~= 0
end

local function canAttemptMine()
    return os.time() - lastMineAttempt >= 3
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
    local tile = WPOINT.new(rockTarget.x, rockTarget.y, 0)
    API.logInfo("Mining rockertunity at " .. rockTarget.x .. ", " .. rockTarget.y .. " (rock ID: " .. rockTarget.id .. ")")

    API.RandomSleep2(600, 400, 200)

    API.DoAction_Object2(0x3a, API.OFF_ACT_GeneralObject_route0, {rockTarget.id}, 40, tile)
    Utils.waitOrTerminate(function() return API.ReadPlayerMovin2() end, 5, 50, "Failed to start moving to rockertunity")
    return Utils.waitOrTerminate(function() return isMiningActive() end, 7, 50, "Failed to start mining rockertunity")
end

local function mineRock(oreConfig)
    API.logInfo("Mining " .. oreConfig.name .. "...")
    Interact:Object(oreConfig.name, oreConfig.action, 40)
    lastMineAttempt = os.time()
    return Utils.waitOrTerminate(function() return isMiningActive() end, 30, 50, "Failed to start mining")
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

local location = LOCATIONS[selectedLocation]
local oreConfig = ORES[selectedOre]

if not location then
    API.logError("Invalid location: " .. selectedLocation)
    return
end

if not oreConfig then
    API.logError("Invalid ore: " .. selectedOre)
    return
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
    return
end

local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
if miningLevel < oreConfig.tier then
    API.logError("Mining level " .. miningLevel .. " is below required level " .. oreConfig.tier .. " for " .. oreConfig.name)
    return
end

if useOreBox and not OreBox.validate(playerOreBox, oreConfig) then
    useOreBox = false
    playerOreBox = nil
end

for _, dungOre in ipairs(DATA.DUNGEONEERING_ORES) do
    if selectedOre == dungOre then
        if not Teleports.hasRingOfKinship() then
            API.logError("Ring of Kinship required for Dungeoneering ores (not found in inventory or equipped)")
            return
        end
        break
    end
end

local bankLocation = Banking.LOCATIONS[selectedBankingLocation]
if not bankLocation then
    API.logError("Invalid banking location: " .. selectedBankingLocation)
    return
end

if selectedBankingLocation == "player_owned_farm" then
    if API.GetVarbitValue(DATA.VARBIT_IDS.POF_BANK_UNLOCKED) == 0 then
        API.logError("Player Owned Farm bank chest is not unlocked")
        return
    end
end

Routes.checkLodestonesForDestination(location)
Routes.checkLodestonesForDestination(bankLocation)

if location.requiredLevels then
    for _, req in ipairs(location.requiredLevels) do
        local skillLevel = API.XPLevelTable(API.GetSkillXP(req.skill))
        if skillLevel < req.level then
            API.logError(req.skill .. " level " .. skillLevel .. " is below required level " .. req.level .. " for " .. location.name)
            return
        end
    end
end

if selectedLocation == "dwarven_mine" or selectedLocation == "dwarven_resource_dungeon" then
    local combatLevel = Utils.getCombatLevel()
    if combatLevel < 45 then
        API.logWarn("Combat level " .. combatLevel .. " is below 45. You may be attacked by scorpions.")
        if not Utils.disableAutoRetaliate() then
            return
        end
    end
elseif selectedLocation == "wilderness_south_west" then
    API.logWarn("Skeletons will attack players of any combat level at this location.")
    if not Utils.disableAutoRetaliate() then
        return
    end
end

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
        {"Stamina:", API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) .. "/" .. staminaThreshold}
    }
    if playerOreBox then
        table.insert(statsTable, {"Ore box:", OreBox.getOreCount(oreConfig) .. "/" .. oreBoxCapacity})
    end
    API.DrawTable(statsTable)
end

API.logInfo("Location: " .. location.name)
API.logInfo("Ore: " .. oreConfig.name)
API.logInfo("Banking: " .. bankLocation.name)
API.logInfo("Use Ore Box: " .. tostring(useOreBox))

while API.Read_LoopyLoop() do
    if not idleHandler.check() then break end
    idleHandler.collectGarbage()
    drawStats()
    if needsBanking() then
        if not Banking.performBanking(bankLocation, location, playerOreBox, oreConfig, bankPin) then
            break
        end
    elseif Utils.isAtRegion(location.oreRegions and location.oreRegions[selectedOre] or location.region) then
        local invFull = Inventory:IsFull()
        local rockertunity = chaseRockertunities and findRockertunity(oreConfig) or nil
        local stamina = API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS)
        if invFull and useOreBox and playerOreBox then
            OreBox.fill(playerOreBox)
        elseif rockertunity and canAttemptMine() then
            if not mineRockertunity(oreConfig, rockertunity) then break end
            staminaThreshold = math.random(160, 190)
        elseif stamina >= staminaThreshold and canAttemptMine() then
            if not mineRock(oreConfig) then break end
            staminaThreshold = math.random(160, 190)
        elseif not isMiningActive() and canAttemptMine() then
            if not mineRock(oreConfig) then break end
        end
    else
        if not Routes.travelTo(location) then break end
        if location.oreWaypoints and location.oreWaypoints[selectedOre] then
            if not Utils.walkThroughWaypoints(location.oreWaypoints[selectedOre]) then break end
        end
    end
    API.RandomSleep2(100, 100, 0)
end

API.logInfo("Script terminated")
