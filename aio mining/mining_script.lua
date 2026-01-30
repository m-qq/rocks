local API = require("api")
local idleHandler = require("aio mining/idle_handler")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")
local OreBox = require("aio mining/mining_orebox")
local Routes = require("aio mining/mining_routes")
local Banking = require("aio mining/mining_banking")

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

API.Write_fake_mouse_do(false)
API.TurnOffMrHasselhoff(false)

if cfg.useOreBox then
    state.playerOreBox = OreBox.find()
    if state.playerOreBox then
        API.printlua("Found ore box: " .. OreBox.getName(state.playerOreBox), 0, false)
    else
        API.printlua("No ore box found in inventory - will bank when full", 4, false)
        cfg.useOreBox = false
    end
end

if cfg.useGemBag then
    state.gemBagId = Utils.findGemBag()
    if state.gemBagId then
        local info = Utils.getGemBagInfo(state.gemBagId)
        API.printlua("Found gem bag: " .. info.name, 0, false)
    else
        API.printlua("Use Gem Bag is enabled but no gem bag found in inventory", 4, false)
        return
    end
end

local skipBanking = cfg.dropOres or cfg.dropGems or cfg.cutAndDrop
local validated = Utils.validateMiningSetup(
    cfg.location, cfg.ore, cfg.bankLocation,
    state.playerOreBox, cfg.useOreBox, skipBanking
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
        table.insert(statsTable, {"Stamina:", Utils.getStaminaRemaining() .. "/" .. Utils.calculateMaxStamina() .. " (" .. string.format("%.1f%%", Utils.getStaminaPercent()) .. ")"})
    end
    if cfg.dropOres then
        table.insert(statsTable, {"Mode:", "Drop"})
    elseif bank then
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

API.printlua("Location: " .. loc.name, 0, false)
API.printlua("Ore: " .. ore.name, 0, false)
if bank then
    API.printlua("Banking: " .. bank.name, 0, false)
end
API.printlua("Drop Ores: " .. tostring(cfg.dropOres), 0, false)
API.printlua("Use Ore Box: " .. tostring(cfg.useOreBox), 0, false)
API.printlua("3-tick Mining: " .. tostring(cfg.threeTickMining), 0, false)

while API.Read_LoopyLoop() do
    if not idleHandler.check() then break end
    idleHandler.collectGarbage()
    API.DoRandomEvents()
    state.miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
    drawStats()

    if Inventory:IsFull() and cfg.cutAndDrop and ore.isGemRock then
        Utils.cutAndDropGems(ore, state)
    elseif Inventory:IsFull() and cfg.dropGems and ore.isGemRock then
        Utils.dropAllOres(ore, state)
    elseif cfg.dropOres and Inventory:IsFull() then
        Utils.dropAllOres(ore, state)
    elseif Utils.needsBanking(cfg, ore, state) then
        if not Banking.performBanking(bank, loc, state.playerOreBox, ore, cfg.bankPin, cfg.ore, cfg.location, state.gemBagId) then
            break
        end
    elseif Utils.isNearOreLocation(loc, cfg.ore) then
        local invFull = Inventory:IsFull()
        local rockertunity = not ore.isGemRock and cfg.chaseRockertunities and not invFull and Utils.findRockertunity(ore) or nil

        if invFull and cfg.useGemBag and state.gemBagId and ore.isGemRock and not Utils.isGemBagFull(state.gemBagId) then
            Utils.fillGemBag(state.gemBagId)
        elseif invFull and not ore.isGemRock and cfg.useOreBox and state.playerOreBox and not OreBox.isFull(state.playerOreBox, ore) then
            OreBox.fill(state.playerOreBox)
        elseif not invFull and cfg.threeTickMining then
            if rockertunity and Utils.canInteract(state) then
                if not Utils.mineRockertunity(ore, rockertunity, state) then break end
                state.lastInteractTick = API.Get_tick()
                state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
            elseif Utils.shouldThreeTick(cfg, state) then
                Utils.threeTickInteract(ore, state)
            end
        elseif rockertunity and Utils.canInteract(state) then
            if not Utils.mineRockertunity(ore, rockertunity, state) then break end
        elseif not invFull and Utils.canInteract(state) then
            local staminaPercent = Utils.getStaminaPercent()
            local miningInProgress = API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0
            if state.miningLevel < 15 or not miningInProgress or staminaPercent >= cfg.staminaRefreshPercent then
                if not Utils.mineRock(ore, state) then break end
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

API.printlua("Script terminated", 0, false)
