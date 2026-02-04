local API = require("api")
local idleHandler = require("aio mining/idle_handler")
local ORES = require("aio mining/mining_ores")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")
local OreBox = require("aio mining/mining_orebox")
local Routes = require("aio mining/mining_routes")
local Banking = require("aio mining/mining_banking")
local MiningGUI = require("aio mining/mining_gui")

idleHandler.init()

API.SetDrawLogs(false)
API.SetDrawTrackedSkills(false)

ClearRender()
MiningGUI.reset()

DrawImGui(function()
    if MiningGUI.open then
        MiningGUI.draw({})
    end
end)

API.printlua("Waiting for configuration...", 0, false)

while API.Read_LoopyLoop() and not MiningGUI.started do
    if not MiningGUI.open then
        API.printlua("GUI closed before start", 0, false)
        ClearRender()
        return
    end
    API.RandomSleep2(100, 50, 0)
end

if not API.Read_LoopyLoop() then
    ClearRender()
    return
end

local cfg = MiningGUI.getConfig()

if cfg.useGemBag then
    cfg.dropGems = false
    cfg.cutAndDrop = false
end

if cfg.cutAndDrop then
    cfg.dropGems = false
end

local selectedOreConfig = ORES[cfg.ore]
if selectedOreConfig and selectedOreConfig.isStackable then
    cfg.useOreBox = false
    cfg.useGemBag = false
    cfg.cutAndDrop = false
    cfg.dropGems = false
    cfg.dropOres = false
    cfg.chaseRockertunities = false
    cfg.threeTickMining = false
elseif selectedOreConfig and not selectedOreConfig.isGemRock then
    cfg.useGemBag = false
    cfg.cutAndDrop = false
    cfg.dropGems = false
    if selectedOreConfig.noOreBox then cfg.useOreBox = false end
    if selectedOreConfig.noRockertunities then cfg.chaseRockertunities = false end
elseif selectedOreConfig and selectedOreConfig.isGemRock then
    cfg.useOreBox = false
    cfg.chaseRockertunities = false
    cfg.dropOres = false
end
if cfg.dropOres then
    cfg.useOreBox = false
end

local jujuDef = cfg.useJuju ~= "none" and DATA.JUJU_POTIONS[cfg.useJuju] or nil
local familiarDef = cfg.useSummoning ~= "none" and DATA.SUMMONING_FAMILIARS[cfg.useSummoning] or nil
local summoningRefreshLocation = cfg.summoningRefreshLocation and DATA.SUMMONING_REFRESH_LOCATIONS[cfg.summoningRefreshLocation] or nil

local state = {
    playerOreBox = nil,
    gemBagId = nil,
    jujuDef = jujuDef,
    familiarDef = familiarDef,
    summoningRefreshLocation = summoningRefreshLocation,
    lastInteractTime = 0,
    lastInteractTick = 0,
    nextTickTarget = 0,
    hasInteracted = false,
    noStamina = selectedOreConfig and selectedOreConfig.noStamina or false,
    miningLevel = API.XPLevelTable(API.GetSkillXP("MINING")),
    currentState = "Idle",
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
        API.printlua("No gem bag found in inventory - continuing without", 4, false)
        cfg.useGemBag = false
    end
end

local skipBanking = cfg.dropOres or cfg.dropGems or cfg.cutAndDrop or (selectedOreConfig and selectedOreConfig.isStackable)
local validated = Utils.validateMiningSetup(cfg.location, cfg.ore, cfg.bankLocation, state.playerOreBox, cfg.useOreBox, skipBanking)

if not validated then
    if #MiningGUI.warnings > 0 then
        MiningGUI.selectWarningsTab = true
        MiningGUI.started = false
        while API.Read_LoopyLoop() and not MiningGUI.started and MiningGUI.open do
            API.RandomSleep2(100, 50, 0)
        end
    end
    ClearRender()
    return
end

if #MiningGUI.warnings > 0 then
    MiningGUI.selectWarningsTab = true
else
    MiningGUI.selectInfoTab = true
end

local loc = validated.location
local ore = validated.oreConfig
local bank = validated.bankLocation

cfg.useOreBox = validated.useOreBox
state.playerOreBox = validated.playerOreBox

local oreBoxCapacity = state.playerOreBox and OreBox.getCapacity(state.playerOreBox, ore) or 0

if loc.dailyLimit then
    local current = API.GetVarbitValue(loc.dailyLimit.varbit)
    if current >= loc.dailyLimit.max then
        MiningGUI.addWarning("Daily limit already reached (" .. current .. "/" .. loc.dailyLimit.max .. ")")
        MiningGUI.selectWarningsTab = true
    end
end

local startXP = API.GetSkillXP("MINING")
local startLevel = API.XPLevelTable(startXP)
local startCraftingXP = (ore.isGemRock and cfg.cutAndDrop) and API.GetSkillXP("CRAFTING") or 0

local oreName = ore.name:gsub(" rock$", "")
local guiData = {
    currentStamina = 0,
    maxStamina = 1,
    noStamina = ore.noStamina,
    state = "Idle",
    location = loc.name,
    oreName = oreName,
    bankLocation = bank and bank.name or "None (stackable)",
    antiIdleTime = 0,
    mode = cfg.dropOres and "Drop" or cfg.threeTickMining and "3-Tick Mining" or nil,
    metrics = {
        currentLevel = 0, levelsGained = 0, xpGained = 0,
        xpPerHour = 0, xpRemaining = 0, levelProgress = 0,
        ttl = 0, maxLevel = false, crafting = nil,
    },
}
if loc.dailyLimit then guiData.dailyLimit = { current = 0, max = loc.dailyLimit.max } end
if state.playerOreBox then guiData.oreBox = { name = "", count = 0, capacity = 0 } end
if state.gemBagId and ore.isGemRock then
    guiData.gemBag = {
        total = 0, capacity = 0, perGemCapacity = nil,
        sapphire = 0, emerald = 0, ruby = 0, diamond = 0, dragonstone = 0,
    }
end
if ore.isGemRock and cfg.cutAndDrop then
    guiData.metrics.crafting = { level = 0, xpPerHour = 0, levelProgress = 0, ttl = 0, maxLevel = false }
end

local function buildGUIData()
    guiData.currentStamina = Utils.getStaminaDrain()
    guiData.maxStamina = Utils.calculateMaxStamina()
    guiData.state = state.currentState
    guiData.antiIdleTime = idleHandler.getTimeUntilNextIdle()

    if guiData.dailyLimit then
        guiData.dailyLimit.current = API.GetVarbitValue(loc.dailyLimit.varbit)
    end

    if guiData.oreBox then
        guiData.oreBox.name = OreBox.getName(state.playerOreBox)
        guiData.oreBox.count = OreBox.getOreCount(ore)
        guiData.oreBox.capacity = oreBoxCapacity
    end

    local currentXP = API.GetSkillXP("MINING")
    local currentLevel = API.XPLevelTable(currentXP)
    local xpGained = currentXP - startXP
    local elapsed = API.ScriptRuntime()
    local xpPerHour = elapsed > 0 and (xpGained / elapsed) * 3600 or 0
    local nextLevelXP = currentLevel < 120 and API.XPForLevel(currentLevel + 1) or 0
    local currentLevelXP = API.XPForLevel(currentLevel)
    local xpRemaining = nextLevelXP > 0 and (nextLevelXP - currentXP) or 0
    local levelRange = nextLevelXP > 0 and (nextLevelXP - currentLevelXP) or 1
    local levelProgress = nextLevelXP > 0 and ((currentXP - currentLevelXP) / levelRange) or 1
    local ttl = xpPerHour > 0 and xpRemaining > 0 and (xpRemaining / xpPerHour) * 3600 or 0

    local m = guiData.metrics
    m.currentLevel = currentLevel
    m.levelsGained = currentLevel - startLevel
    m.xpGained = xpGained
    m.xpPerHour = xpPerHour
    m.xpRemaining = xpRemaining
    m.levelProgress = levelProgress
    m.ttl = ttl
    m.maxLevel = currentLevel >= 120

    if m.crafting then
        local craftXP = API.GetSkillXP("CRAFTING")
        local craftLevel = API.XPLevelTable(craftXP)
        local craftGained = craftXP - startCraftingXP
        local craftPerHour = elapsed > 0 and (craftGained / elapsed) * 3600 or 0
        local craftNextXP = craftLevel < 120 and API.XPForLevel(craftLevel + 1) or 0
        local craftCurXP = API.XPForLevel(craftLevel)
        local craftRemaining = craftNextXP > 0 and (craftNextXP - craftXP) or 0
        local craftRange = craftNextXP > 0 and (craftNextXP - craftCurXP) or 1
        local craftProgress = craftNextXP > 0 and ((craftXP - craftCurXP) / craftRange) or 1
        local craftTtl = craftPerHour > 0 and craftRemaining > 0 and (craftRemaining / craftPerHour) * 3600 or 0
        m.crafting.level = craftLevel
        m.crafting.xpPerHour = craftPerHour
        m.crafting.levelProgress = craftProgress
        m.crafting.ttl = craftTtl
        m.crafting.maxLevel = craftLevel >= 120
    end

    if guiData.gemBag then
        Utils.getGemCounts(state.gemBagId, guiData.gemBag)
        local info = Utils.getGemBagInfo(state.gemBagId)
        guiData.gemBag.total = guiData.gemBag.sapphire + guiData.gemBag.emerald + guiData.gemBag.ruby + guiData.gemBag.diamond + guiData.gemBag.dragonstone
        guiData.gemBag.capacity = Utils.getGemBagCapacity(state.gemBagId)
        guiData.gemBag.perGemCapacity = info and info.perGemCapacity or nil
    end

    if state.jujuDef then
        local buffActive = Utils.getBuffTimeRemaining(state.jujuDef.buffId) > 0
        local hasPotion = Banking.findJujuInInventory(state.jujuDef) ~= nil
        if buffActive or hasPotion then
            if not guiData.juju then guiData.juju = {} end
            guiData.juju.timeUntilRefresh = Utils.getJujuTimeUntilRefresh(state.jujuDef)
        else
            guiData.juju = nil
        end
    end

    if state.familiarDef then
        if not guiData.familiar then guiData.familiar = {} end
        guiData.familiar.timeUntilRefresh = Utils.getFamiliarTimeUntilRefresh(state.familiarDef)
        guiData.familiar.summoningPoints = Utils.getSummoningPoints()
    else
        guiData.familiar = nil
    end

    return guiData
end

API.printlua("Location: " .. loc.name, 0, false)
API.printlua("Ore: " .. ore.name, 0, false)
if bank then
    API.printlua("Banking: " .. bank.name, 0, false)
end
API.printlua("Drop Ores: " .. tostring(cfg.dropOres), 0, false)
API.printlua("Use Ore Box: " .. tostring(cfg.useOreBox), 0, false)
API.printlua("3-tick Mining: " .. tostring(cfg.threeTickMining), 0, false)
API.printlua("Starting GUI Mining Script...", 0, false)

ClearRender()
local lastGUIUpdate = 0
DrawImGui(function()
    if MiningGUI.open then
        local now = os.clock()
        if now - lastGUIUpdate >= 0.5 then
            buildGUIData()
            lastGUIUpdate = now
        end
        MiningGUI.draw(guiData)
    end
end)

local success, err = pcall(function()
    while API.Read_LoopyLoop() do
        if not idleHandler.check() then break end
        idleHandler.collectGarbage()
        API.DoRandomEvents()
        state.miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))

        if loc.dailyLimit then
            local current = API.GetVarbitValue(loc.dailyLimit.varbit)
            if current >= loc.dailyLimit.max then
                API.printlua("Daily limit reached (" .. current .. "/" .. loc.dailyLimit.max .. ") - stopping", 0, false)
                break
            end
        end

        if state.familiarDef and Utils.needsFamiliarRefresh(state.familiarDef) then
            if Utils.getSummoningPoints() >= state.familiarDef.pointsCost and API.Container_Check_Items(93, {state.familiarDef.pouchId}) then
                if not Utils.summonFamiliar(state.familiarDef) and not state.familiarWarned then
                    state.familiarWarned = true
                    MiningGUI.addWarning("Failed to summon " .. state.familiarDef.name)
                end
            elseif state.summoningRefreshLocation then
                state.currentState = "Refreshing Summoning"
                local refreshOk, hasMorePouches = Utils.refreshSummoningPoints(loc, cfg.ore, state.familiarDef, state.playerOreBox, ore, state.gemBagId, state.summoningRefreshLocation)
                if refreshOk then
                    state.familiarWarned = false
                    state.hasInteracted = false
                    if not hasMorePouches then
                        state.familiarDef = nil
                        MiningGUI.addWarning("No more familiar pouches in bank - disabling summoning")
                    end
                elseif not state.familiarWarned then
                    state.familiarWarned = true
                    MiningGUI.addWarning("Unable to refresh summoning points")
                end
            end
        end

        if Inventory:IsFull() and cfg.cutAndDrop and ore.isGemRock then
            state.currentState = "Cutting Gems"
            Utils.cutAndDropGems(ore, state)
        elseif Inventory:IsFull() and cfg.dropGems and ore.isGemRock then
            state.currentState = "Dropping"
            Utils.dropAllOres(ore, state)
        elseif cfg.dropOres and Inventory:IsFull() then
            state.currentState = "Dropping"
            Utils.dropAllOres(ore, state)
        elseif Utils.needsBanking(cfg, ore, state) then
            state.currentState = "Banking"
            state.hasInteracted = false
            Banking.jujuWarning = nil
            Banking.familiarWarning = nil
            if not Banking.performBanking(bank, loc, state.playerOreBox, ore, cfg.bankPin, cfg.ore, cfg.location, state.gemBagId, state.jujuDef, state.familiarDef) then
                break
            end
            if Banking.jujuWarning then
                MiningGUI.addWarning(Banking.jujuWarning)
            else
                state.jujuWarned = false
            end
            if Banking.familiarWarning then
                MiningGUI.addWarning(Banking.familiarWarning)
                state.familiarDef = nil
            else
                state.familiarWarned = false
            end
        elseif Utils.isNearOreLocation(loc, cfg.ore) then
            if not state.rocksScanned then
                Utils.scanRocks(ore)
                state.rocksScanned = true
            end

            if state.jujuDef and Utils.needsJujuRefresh(state.jujuDef) then
                if not Utils.drinkJuju(state.jujuDef) and not state.jujuWarned then
                    state.jujuWarned = true
                    MiningGUI.addWarning("No juju potion in inventory - will try next bank trip")
                end
            end

            local miningInProgress = API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0
            if miningInProgress or Utils.isMiningActive(state) then
                state.currentState = "Mining"
            end

            local invFull = Inventory:IsFull()
            local rockertunity = not ore.isGemRock and cfg.chaseRockertunities and not invFull and Utils.findRockertunity(ore) or nil

            if invFull and cfg.useGemBag and state.gemBagId and ore.isGemRock and not Utils.isGemBagFull(state.gemBagId) then
                state.currentState = "Filling Gem Bag"
                Utils.fillGemBag(state.gemBagId)
            elseif invFull and not ore.isGemRock and cfg.useOreBox and state.playerOreBox and not OreBox.isFull(state.playerOreBox, ore) then
                state.currentState = "Filling Ore Box"
                OreBox.fill(state.playerOreBox)
            elseif not invFull and cfg.threeTickMining then
                state.currentState = "Mining"
                if rockertunity and Utils.canInteract(state) then
                    if not Utils.mineRockertunity(ore, rockertunity, state) then break end
                    state.hasInteracted = true
                    state.lastInteractTick = API.Get_tick()
                    state.nextTickTarget = math.random(100) <= 3 and 4 or math.random(2, 3)
                elseif Utils.shouldThreeTick(cfg, state) then
                    Utils.threeTickInteract(ore, state)
                end
            elseif rockertunity and Utils.canInteract(state) then
                state.currentState = "Mining"
                if not Utils.mineRockertunity(ore, rockertunity, state) then break end
                state.hasInteracted = true
            elseif not invFull and Utils.canInteract(state) then
                if state.noStamina then
                    if not state.hasInteracted or not Utils.isRecentlyActive(state) then
                        state.currentState = "Mining"
                        if not Utils.mineRock(ore, state) then break end
                        state.hasInteracted = true
                    end
                else
                    local staminaPercent = Utils.getStaminaPercent()
                    local miningInProgress = API.GetVarbitValue(DATA.VARBIT_IDS.MINING_PROGRESS) > 0
                    if not state.hasInteracted or state.miningLevel < 15 or not miningInProgress or staminaPercent >= cfg.staminaRefreshPercent then
                        state.currentState = "Mining"
                        if not Utils.mineRock(ore, state) then break end
                        state.hasInteracted = true
                    end
                end
            end
        else
            state.currentState = "Traveling"
            state.rocksScanned = false
            state.hasInteracted = false
            Utils.clearRockCache()
            if not Routes.travelTo(loc, cfg.ore) then break end
            if loc.oreWaypoints and loc.oreWaypoints[cfg.ore] then
                if not Utils.walkThroughWaypoints(loc.oreWaypoints[cfg.ore]) then break end
                if not Utils.ensureAtOreLocation(loc, cfg.ore) then break end
            end
        end
        API.RandomSleep2(100, 100, 0)
    end
end)

if not success then
    API.printlua("Error in main loop: " .. tostring(err), 4, false)
end

ClearRender()
API.printlua("Script terminated", 0, false)
