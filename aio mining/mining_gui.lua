local API = require("api")
local ORES = require("aio mining/mining_ores")
local LOCATIONS = require("aio mining/mining_locations")
local Banking = require("aio mining/mining_banking")
local Utils = require("aio mining/mining_utils")
local DATA = require("aio mining/mining_data")

local MiningGUI = {}
MiningGUI.open = true
MiningGUI.started = false
MiningGUI.warnings = {}
MiningGUI.selectConfigTab = true
MiningGUI.selectWarningsTab = false
MiningGUI.selectInfoTab = false

function MiningGUI.reset()
    MiningGUI.open = true
    MiningGUI.started = false
    MiningGUI.warnings = {}
    MiningGUI.selectConfigTab = true
    MiningGUI.selectWarningsTab = false
    MiningGUI.selectInfoTab = false
end

function MiningGUI.addWarning(msg)
    MiningGUI.warnings[#MiningGUI.warnings + 1] = msg
end

function MiningGUI.clearWarnings()
    MiningGUI.warnings = {}
end

-- Build sorted key/name arrays for dropdowns
local function buildSortedList(tbl, nameField)
    local keys, names = {}, {}
    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for i, key in ipairs(keys) do
        names[i] = tbl[key][nameField or "name"]
    end
    return keys, names
end

local function buildOreSortedList()
    local keys = {}
    for key in pairs(ORES) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        local ta, tb = ORES[a].tier, ORES[b].tier
        if ta ~= tb then return ta < tb end
        return ORES[a].name < ORES[b].name
    end)
    local names = {}
    for i, key in ipairs(keys) do
        local ore = ORES[key]
        names[i] = "[" .. ore.tier .. "] " .. ore.name
    end
    return keys, names
end

local oreKeys, oreNames = buildOreSortedList()
local locationKeys, locationNames = buildSortedList(LOCATIONS, "name")
local bankKeys, bankNames = buildSortedList(Banking.LOCATIONS, "name")

-- Precompute ore <-> location mappings
local oreToLocations = {}
local locationToOres = {}

for _, oreKey in ipairs(oreKeys) do
    oreToLocations[oreKey] = {}
end
for _, locKey in ipairs(locationKeys) do
    locationToOres[locKey] = {}
    local loc = LOCATIONS[locKey]
    for _, oreKey in ipairs(loc.ores) do
        oreToLocations[oreKey] = oreToLocations[oreKey] or {}
        oreToLocations[oreKey][locKey] = true
        locationToOres[locKey][oreKey] = true
    end
end

-- Find 0-based index of a key in a sorted array, or 0 if not found
local function findKeyIndex(keys, key)
    if not key then return 0 end
    for i, k in ipairs(keys) do
        if k == key then return i - 1 end
    end
    return 0
end

local CONFIG_DIR = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\configs\\"
local configPath = nil

function MiningGUI.setScriptName(name)
    configPath = CONFIG_DIR .. name .. ".config.json"
end

local function loadConfigFromFile()
    if not configPath then return nil end
    local file = io.open(configPath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveConfigToFile(cfg)
    local data = {
        Ore = oreKeys[cfg.oreIndex + 1],
        MiningLocation = locationKeys[cfg.locationIndex + 1],
        BankingLocation = bankKeys[cfg.bankIndex + 1],
        StaminaRefreshPercent = cfg.staminaPercent,
        DropOres = cfg.dropOres,
        UseOreBox = cfg.useOreBox,
        ChaseRockertunities = cfg.chaseRockertunities,
        DropGems = cfg.dropGems,
        CutAndDrop = cfg.cutAndDrop,
        UseGemBag = cfg.useGemBag,
        ThreeTickMining = cfg.threeTickMining,
        UseJuju = cfg.useJuju,
        UseSummoning = cfg.useSummoning,
        SummoningRefreshLocation = cfg.summoningRefreshLocation,
        BankPin = cfg.bankPin,
    }
    local ok, json = pcall(API.JsonEncode, data)
    if not ok or not json then
        API.printlua("Failed to encode config JSON", 4, false)
        return
    end
    if not configPath then return end
    local dir = io.open(CONFIG_DIR .. ".", "r")
    if dir then
        dir:close()
    else
        os.execute('mkdir "' .. CONFIG_DIR:gsub("/", "\\") .. '" 2>nul')
    end
    local file = io.open(configPath, "w")
    if not file then
        API.printlua("Failed to open config file for writing", 4, false)
        return
    end
    file:write(json)
    file:close()
    API.printlua("Config saved", 0, false)
end

-- Returns filtered location indices (1-based into locationKeys) for a given ore
local function getFilteredLocationIndices(oreKey)
    local result = {}
    local set = oreToLocations[oreKey]
    if not set then return result end
    for i, locKey in ipairs(locationKeys) do
        if set[locKey] then
            result[#result + 1] = i
        end
    end
    return result
end

-- Config state with defaults
MiningGUI.config = {
    oreIndex = 0,
    locationIndex = 0,
    bankIndex = 0,
    staminaPercent = 85,
    dropOres = false,
    useOreBox = true,
    chaseRockertunities = true,
    dropGems = false,
    cutAndDrop = false,
    useGemBag = false,
    threeTickMining = false,
    useJuju = "none",
    useSummoning = "none",
    summoningRefreshLocation = "wars_retreat",
    bankPin = "",
}

-- Resolve a saved value to a 0-based index: supports string keys or legacy numeric indices
local function resolveIndex(keys, value)
    if type(value) == "string" then
        return findKeyIndex(keys, value)
    elseif type(value) == "number" then
        return math.max(0, math.min(value, #keys - 1))
    end
    return 0
end

-- Load saved config from file, called after setScriptName
function MiningGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end

    local c = MiningGUI.config
    c.oreIndex = resolveIndex(oreKeys, saved.Ore)
    c.locationIndex = resolveIndex(locationKeys, saved.MiningLocation)
    c.bankIndex = resolveIndex(bankKeys, saved.BankingLocation)
    if type(saved.StaminaRefreshPercent) == "number" then
        c.staminaPercent = math.max(50, math.min(100, saved.StaminaRefreshPercent))
    end
    if type(saved.DropOres) == "boolean" then c.dropOres = saved.DropOres end
    if type(saved.UseOreBox) == "boolean" then c.useOreBox = saved.UseOreBox end
    if type(saved.ChaseRockertunities) == "boolean" then c.chaseRockertunities = saved.ChaseRockertunities end
    if type(saved.DropGems) == "boolean" then c.dropGems = saved.DropGems end
    if type(saved.CutAndDrop) == "boolean" then c.cutAndDrop = saved.CutAndDrop end
    if type(saved.UseGemBag) == "boolean" then c.useGemBag = saved.UseGemBag end
    if type(saved.ThreeTickMining) == "boolean" then c.threeTickMining = saved.ThreeTickMining end
    if type(saved.UseJuju) == "string" then c.useJuju = saved.UseJuju end
    if type(saved.UseSummoning) == "string" then c.useSummoning = saved.UseSummoning end
    if type(saved.SummoningRefreshLocation) == "string" then c.summoningRefreshLocation = saved.SummoningRefreshLocation end
    if type(saved.BankPin) == "string" then c.bankPin = saved.BankPin end

    -- Validate location has the selected ore, reset if not
    local selectedOreKey = oreKeys[c.oreIndex + 1]
    local selectedLocKey = locationKeys[c.locationIndex + 1]
    if selectedOreKey and selectedLocKey and oreToLocations[selectedOreKey] then
        if not oreToLocations[selectedOreKey][selectedLocKey] then
            local filtered = getFilteredLocationIndices(selectedOreKey)
            if #filtered > 0 then
                c.locationIndex = filtered[1] - 1
            end
        end
    end
end

-- Convert GUI state to cfg table for the script
function MiningGUI.getConfig()
    local c = MiningGUI.config
    return {
        ore = oreKeys[c.oreIndex + 1],
        location = locationKeys[c.locationIndex + 1],
        bankLocation = bankKeys[c.bankIndex + 1],
        dropOres = c.dropOres,
        useOreBox = c.useOreBox,
        chaseRockertunities = c.chaseRockertunities,
        dropGems = c.dropGems,
        cutAndDrop = c.cutAndDrop,
        useGemBag = c.useGemBag,
        threeTickMining = c.threeTickMining,
        useJuju = c.useJuju,
        useSummoning = c.useSummoning,
        summoningRefreshLocation = c.summoningRefreshLocation,
        staminaRefreshPercent = c.staminaPercent,
        bankPin = c.bankPin,
    }
end

-- Color tables
local ORE_COLORS = {
    ["Copper"]          = {0.75, 0.55, 0.30},
    ["Tin"]             = {0.70, 0.70, 0.70},
    ["Iron"]            = {0.60, 0.20, 0.15},
    ["Coal"]            = {0.45, 0.40, 0.38},
    ["Mithril"]         = {0.30, 0.25, 0.60},
    ["Adamantite"]      = {0.20, 0.55, 0.20},
    ["Luminite"]        = {0.85, 0.85, 0.10},
    ["Runite"]          = {0.20, 0.60, 0.60},
    ["Orichalcite"]     = {0.60, 0.15, 0.10},
    ["Drakolith"]       = {0.80, 0.70, 0.10},
    ["Necrite"]         = {0.15, 0.40, 0.20},
    ["Phasmatite"]      = {0.30, 0.75, 0.20},
    ["Banite"]          = {0.30, 0.35, 0.45},
    ["Light animica"]   = {0.40, 0.80, 0.90},
    ["Dark animica"]    = {0.50, 0.30, 0.70},
    ["Gold"]            = {0.90, 0.75, 0.15},
    ["Silver"]          = {0.75, 0.75, 0.80},
    ["Platinum"]        = {0.80, 0.80, 0.85},
    ["Novite"]          = {0.45, 0.12, 0.50},
    ["Bathus"]          = {0.25, 0.18, 0.12},
    ["Marmaros"]        = {0.50, 0.45, 0.38},
    ["Kratonium"]       = {0.35, 0.30, 0.15},
    ["Fractite"]        = {0.12, 0.18, 0.12},
    ["Zephyrium"]       = {0.15, 0.55, 0.40},
    ["Argonite"]        = {0.30, 0.15, 0.55},
    ["Katagon"]         = {0.12, 0.15, 0.45},
    ["Gorgonite"]       = {0.55, 0.10, 0.12},
    ["Promethium"]      = {0.50, 0.08, 0.10},
    ["Uncommon gem"]    = {0.2, 0.6, 0.8},
    ["Precious gem"]    = {0.75, 0.9, 1.0},
    ["Crystal-flecked sandstone"] = {0.6, 0.3, 0.7},
    ["Soft clay"]        = {0.65, 0.50, 0.30},
    ["Seren stone"]     = {0.4, 0.85, 0.95},
}

local GEM_COLORS = {
    Sapphire    = {0.2, 0.4, 0.9},
    Emerald     = {0.1, 0.8, 0.3},
    Ruby        = {0.9, 0.15, 0.15},
    Diamond     = {0.75, 0.9, 1.0},
    Dragonstone = {0.6, 0.3, 0.8},
}

local STATE_COLORS = {
    Mining              = {0.3, 1.0, 0.4},
    Banking             = {1.0, 0.8, 0.2},
    Traveling           = {0.4, 0.8, 1.0},
    Dropping            = {1.0, 0.5, 0.3},
    ["Cutting Gems"]    = {0.8, 0.5, 1.0},
    ["Filling Ore Box"] = {0.35, 0.6, 1.0},
    ["Filling Gem Bag"] = {0.6, 0.3, 0.8},
}

local function row(label, value, lr, lg, lb, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, lr or 0.5, lg or 0.5, lb or 0.55, 1.0)
    ImGui.TextWrapped(label)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function progressBar(progress, height, text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, r * 0.4, g * 0.4, b * 0.4, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, r * 0.1, g * 0.1, b * 0.1, 0.8)
    ImGui.ProgressBar(progress, -1, height, text)
    ImGui.PopStyleColor(2)
end

local function label(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.75, 0.9, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function disabledCheckbox(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.35, 0.35, 0.35, 1.0)
    ImGui.Selectable("     " .. text .. "##disabled_" .. text, false, ImGuiSelectableFlags.Disabled)
    ImGui.PopStyleColor(1)
end

local function drawConfigSummary(cfg)
    if ImGui.BeginTable("##cfgsummary", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.4)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.6)
        row("Ore", oreNames[cfg.oreIndex + 1])
        row("Location", locationNames[cfg.locationIndex + 1])
        local selectedOreKey = oreKeys[cfg.oreIndex + 1]
        local isGemRock = ORES[selectedOreKey] and ORES[selectedOreKey].isGemRock
        local isStackable = ORES[selectedOreKey] and ORES[selectedOreKey].isStackable
        local showBank = not isStackable and not (isGemRock and (cfg.dropGems or cfg.cutAndDrop)) and not (not isGemRock and cfg.dropOres)
        if showBank then
            row("Bank", bankNames[cfg.bankIndex + 1])
        end
        if isStackable then
            row("Mode", "Stackable Ore")
        elseif isGemRock then
            if cfg.useGemBag then row("Mode", "Use Gem Bag")
            elseif cfg.cutAndDrop then row("Mode", "Cut and Drop")
            elseif cfg.dropGems then row("Mode", "Drop Gems")
            else row("Mode", "Bank Gems") end
        else
            if cfg.dropOres then row("Mode", "Drop Ores")
            elseif cfg.useOreBox then row("Mode", "Use Ore Box")
            else row("Mode", "Bank Ores") end
        end
        if cfg.threeTickMining then
            row("3-tick", "Enabled", 0.5, 0.5, 0.55, 0.3, 1.0, 0.4)
        end
        if cfg.useJuju == "juju" then
            row("Potion", "Juju Mining Potion", 0.5, 0.5, 0.55, 0.6, 0.9, 0.3)
        elseif cfg.useJuju == "perfect" then
            row("Potion", "Perfect Juju Mining Potion", 0.5, 0.5, 0.55, 0.3, 0.9, 0.6)
        end
        if cfg.useSummoning ~= "none" then
            local familiarDef = DATA.SUMMONING_FAMILIARS[cfg.useSummoning]
            if familiarDef then
                row("Familiar", familiarDef.name, 0.5, 0.5, 0.55, 0.9, 0.5, 0.3)
            end
        end
        ImGui.EndTable()
    end
end

local function drawConfigTab(cfg, gui)
    if gui.started then
        local runText = "Script is running."
        local tw = ImGui.CalcTextSize(runText)
        local rw = ImGui.GetContentRegionAvail()
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (rw - tw) * 0.5)
        ImGui.PushStyleColor(ImGuiCol.Text, 0.4, 0.8, 0.4, 1.0)
        ImGui.TextWrapped(runText)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        drawConfigSummary(cfg)
        return
    end

    ImGui.PushItemWidth(-1)

    -- Ore / Location / Bank dropdowns
    label("Ore")
    local oreChanged, newOreIdx = ImGui.Combo("##ore", cfg.oreIndex, oreNames, 10)
    if oreChanged then
        cfg.oreIndex = newOreIdx
        local selectedOreKey = oreKeys[cfg.oreIndex + 1]
        local currentLocKey = locationKeys[cfg.locationIndex + 1]
        if not oreToLocations[selectedOreKey][currentLocKey] then
            local filtered = getFilteredLocationIndices(selectedOreKey)
            if #filtered > 0 then
                cfg.locationIndex = filtered[1] - 1
            end
        end
    end

    local selectedOreKey = oreKeys[cfg.oreIndex + 1]
    local filteredLocIndices = getFilteredLocationIndices(selectedOreKey)
    local filteredLocNames = {}
    local filteredLocMapping = {}
    for i, globalIdx in ipairs(filteredLocIndices) do
        filteredLocNames[i] = locationNames[globalIdx]
        filteredLocMapping[i] = globalIdx
    end
    local currentFilteredIdx = 0
    for i, globalIdx in ipairs(filteredLocIndices) do
        if (globalIdx - 1) == cfg.locationIndex then
            currentFilteredIdx = i - 1
            break
        end
    end
    if #filteredLocNames > 0 then
        label("Location")
        local locChanged, newLocFilteredIdx = ImGui.Combo("##location", currentFilteredIdx, filteredLocNames, 10)
        if locChanged then
            local globalIdx = filteredLocMapping[newLocFilteredIdx + 1]
            cfg.locationIndex = globalIdx - 1
        end
    else
        ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "No locations for this ore")
    end

    local isGemRock = ORES[selectedOreKey] and ORES[selectedOreKey].isGemRock
    local isStackable = ORES[selectedOreKey] and ORES[selectedOreKey].isStackable
    local effectiveDropGems = isGemRock and cfg.dropGems
    local effectiveCutAndDrop = isGemRock and cfg.cutAndDrop
    local effectiveDropOres = not isGemRock and not isStackable and cfg.dropOres
    local needsBanking = not isStackable and not effectiveDropOres and not effectiveDropGems and not effectiveCutAndDrop

    if needsBanking then
        label("Bank")
        local bankChanged, newBankIdx = ImGui.Combo("##bank", cfg.bankIndex, bankNames, 10)
        if bankChanged then cfg.bankIndex = newBankIdx end
    end

    ImGui.Separator()

    -- Ore/Gem options
    if isStackable then
        -- No options needed for stackable ores
    elseif isGemRock then
        if cfg.dropGems or cfg.cutAndDrop then
            disabledCheckbox("Use Gem Bag")
        else
            local changed, val = ImGui.Checkbox("Use Gem Bag##useGemBag", cfg.useGemBag)
            if changed then
                cfg.useGemBag = val
                if val then cfg.dropGems = false; cfg.cutAndDrop = false end
            end
        end
        if cfg.dropGems or cfg.useGemBag then
            disabledCheckbox("Cut and Drop")
        else
            local changed, val = ImGui.Checkbox("Cut and Drop##cutAndDrop", cfg.cutAndDrop)
            if changed then
                cfg.cutAndDrop = val
                if val then cfg.dropGems = false; cfg.useGemBag = false end
            end
        end
        if cfg.cutAndDrop or cfg.useGemBag then
            disabledCheckbox("Drop Gems")
        else
            local changed, val = ImGui.Checkbox("Drop Gems##dropGems", cfg.dropGems)
            if changed then
                cfg.dropGems = val
                if val then cfg.cutAndDrop = false; cfg.useGemBag = false end
            end
        end
    else
        local oreNoOreBox = ORES[selectedOreKey] and ORES[selectedOreKey].noOreBox
        local oreNoRockertunities = ORES[selectedOreKey] and ORES[selectedOreKey].noRockertunities

        if cfg.useOreBox then
            disabledCheckbox("Drop Ores")
        else
            local changed, val = ImGui.Checkbox("Drop Ores##dropOres", cfg.dropOres)
            if changed then
                cfg.dropOres = val
                if val then cfg.useOreBox = false end
            end
        end
        if not oreNoOreBox then
            if cfg.dropOres then
                disabledCheckbox("Use Ore Box")
            else
                local changed, val = ImGui.Checkbox("Use Ore Box##useOreBox", cfg.useOreBox)
                if changed then
                    cfg.useOreBox = val
                    if val then cfg.dropOres = false end
                end
            end
        end
        if not oreNoRockertunities then
            local changed, val = ImGui.Checkbox("Chase Rockertunities##chaseRock", cfg.chaseRockertunities)
            if changed then cfg.chaseRockertunities = val end
        end
    end

    if not isStackable then
        local ttChanged, ttVal = ImGui.Checkbox("3-tick Mining##3tick", cfg.threeTickMining)
        if ttChanged then cfg.threeTickMining = ttVal end
    end

    ImGui.Separator()

    -- Potion
    local selectedBankKey = bankKeys[cfg.bankIndex + 1]
    local isMetalBank = selectedBankKey and Banking.LOCATIONS[selectedBankKey] and Banking.LOCATIONS[selectedBankKey].metalBank

    if not isGemRock and not isMetalBank then
        local potionKeys = {"none", "juju", "perfect"}
        local potionNames = {"None", "Juju Mining Potion", "Perfect Juju Mining Potion"}
        local currentPotionIdx = 0
        for i, key in ipairs(potionKeys) do
            if key == cfg.useJuju then
                currentPotionIdx = i - 1
                break
            end
        end
        label("Potion")
        local potionChanged, newPotionIdx = ImGui.Combo("##potion", currentPotionIdx, potionNames, 10)
        if potionChanged then
            cfg.useJuju = potionKeys[newPotionIdx + 1]
        end
    else
        cfg.useJuju = "none"
    end

    -- Summoning
    local summoningLevel = API.XPLevelTable(API.GetSkillXP("SUMMONING"))
    local familiarKeys = {"none"}
    local familiarNames = {"None"}
    for key, def in pairs(DATA.SUMMONING_FAMILIARS) do
        if not def.levelReq or summoningLevel >= def.levelReq then
            familiarKeys[#familiarKeys + 1] = key
            familiarNames[#familiarNames + 1] = def.name
        end
    end

    if #familiarKeys > 1 then
        local currentFamiliarIdx = 0
        for i, key in ipairs(familiarKeys) do
            if key == cfg.useSummoning then
                currentFamiliarIdx = i - 1
                break
            end
        end
        label("Familiar")
        local fChanged, newFIdx = ImGui.Combo("##familiarSelect", currentFamiliarIdx, familiarNames, 10)
        if fChanged then
            cfg.useSummoning = familiarKeys[newFIdx + 1]
        end

        if cfg.useSummoning ~= "none" then
            local refreshKeys = {}
            local refreshNames = {}
            for key, loc in pairs(DATA.SUMMONING_REFRESH_LOCATIONS) do
                refreshKeys[#refreshKeys + 1] = key
                refreshNames[#refreshNames + 1] = loc.name
            end
            local currentRefreshIdx = 0
            for i, key in ipairs(refreshKeys) do
                if key == cfg.summoningRefreshLocation then
                    currentRefreshIdx = i - 1
                    break
                end
            end
            label("Refresh Location")
            local rlChanged, newRlIdx = ImGui.Combo("##summoningRefresh", currentRefreshIdx, refreshNames, 10)
            if rlChanged then
                cfg.summoningRefreshLocation = refreshKeys[newRlIdx + 1]
            end
        end
    else
        cfg.useSummoning = "none"
        cfg.summoningRefreshLocation = nil
    end

    ImGui.Separator()

    local noStamina = ORES[selectedOreKey] and ORES[selectedOreKey].noStamina
    if not noStamina then
        label("Refresh Stamina At")
        local stamChanged, newStamVal = ImGui.SliderInt("##stamina", cfg.staminaPercent, 50, 100, "%d%%")
        if stamChanged then cfg.staminaPercent = newStamVal end
    end

    if needsBanking then
        label("Bank PIN")
        local pinChanged, newPin = ImGui.InputText("##bankpin", cfg.bankPin, 0)
        if pinChanged then cfg.bankPin = newPin end
    end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Start button
    ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.55, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.2, 0.7, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.1, 0.85, 0.1, 1.0)
    if ImGui.Button("Start Mining##start", -1, 30) then
        saveConfigToFile(gui.config)
        gui.started = true
    end
    ImGui.PopStyleColor(3)
end

local function formatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    end
    return string.format("%d", n)
end

local function formatDuration(seconds)
    if seconds <= 0 then return "--" end
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, mins)
    end
    return string.format("%dm %02ds", mins, secs)
end

local function drawInfoTab(data)
    local stateText = data.state or "Idle"
    local sc = STATE_COLORS[stateText] or {0.5, 0.5, 0.5}
    local textWidth = ImGui.CalcTextSize(stateText)
    local regionWidth = ImGui.GetContentRegionAvail()
    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (regionWidth - textWidth) * 0.5)
    ImGui.PushStyleColor(ImGuiCol.Text, sc[1], sc[2], sc[3], 1.0)
    ImGui.TextWrapped(stateText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    -- Stamina (varbit tracks drain, so remaining = max - drain)
    if not data.noStamina then
        local drain = data.currentStamina or 0
        local max = data.maxStamina or 1
        local remaining = math.max(0, math.min(max, max - drain))
        local pct = remaining / max

        local sr, sg, sb = 1.0, 0.3, 0.3
        if pct > 0.6 then
            sr, sg, sb = 0.3, 0.85, 0.45
        elseif pct > 0.3 then
            sr, sg, sb = 1.0, 0.75, 0.2
        end

        progressBar(pct, 20, string.format("Stamina: %d / %d", remaining, max), sr, sg, sb)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Daily Limit
    if data.dailyLimit then
        local cur = data.dailyLimit.current or 0
        local max = data.dailyLimit.max or 1
        local pct = cur / max
        local dr, dg, db = 0.3, 0.85, 0.45
        if pct >= 1.0 then
            dr, dg, db = 1.0, 0.3, 0.3
        elseif pct > 0.8 then
            dr, dg, db = 1.0, 0.75, 0.2
        end
        progressBar(pct, 20, string.format("Daily: %d / %d", cur, max), dr, dg, db)

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Ore Box
    if data.oreBox then
        local oreName = data.oreName or "Ore"
        local oreColor = ORE_COLORS[oreName] or {0.7, 0.7, 0.7}
        local count = data.oreBox.count or 0
        local cap = data.oreBox.capacity or 1
        local p = count / cap

        if ImGui.BeginTable("##orebox", 2) then
            ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.35)
            ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.65)
            row("Ore Box", data.oreBox.name, 0.5, 0.5, 0.55, 0.9, 0.9, 0.9)
            ImGui.EndTable()
        end

        ImGui.Spacing()
        progressBar(p, 20, string.format("%s: %d / %d", oreName, count, cap), oreColor[1], oreColor[2], oreColor[3])

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Gem Bag
    if data.gemBag then
        local total = data.gemBag.total or 0
        local cap = data.gemBag.capacity or 1
        local p = total / cap
        local r, g, b = 0.3, 0.7, 1.0
        if p > 0.9 then r, g, b = 1.0, 0.3, 0.3
        elseif p > 0.7 then r, g, b = 1.0, 0.75, 0.2 end
        progressBar(p, 20, string.format("Gems: %d / %d", total, cap), r, g, b)

        ImGui.Spacing()
        if ImGui.BeginTable("##gems", 2) then
            ImGui.TableSetupColumn("gem", ImGuiTableColumnFlags.WidthStretch, 0.35)
            ImGui.TableSetupColumn("cnt", ImGuiTableColumnFlags.WidthStretch, 0.65)
            local pgc = data.gemBag.perGemCapacity
            local fmt = pgc and function(v) return v .. "/" .. pgc end or tostring
            local function gemRow(name, value)
                local c = GEM_COLORS[name] or {0.7, 0.7, 0.7}
                row(name, value, c[1], c[2], c[3])
            end
            gemRow("Sapphire", fmt(data.gemBag.sapphire))
            gemRow("Emerald", fmt(data.gemBag.emerald))
            gemRow("Ruby", fmt(data.gemBag.ruby))
            gemRow("Diamond", fmt(data.gemBag.diamond))
            if pgc then
                gemRow("Dragonstone", fmt(data.gemBag.dragonstone))
            end
            ImGui.EndTable()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Info
    if ImGui.BeginTable("##info", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.35)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.65)

        row("Location", data.location or "Unknown")
        row("Bank", data.bankLocation or "Unknown")
        if data.mode then
            row("Mode", data.mode)
        end
        row("Anti-idle", Utils.formatTime(data.antiIdleTime or 0), 0.5, 0.5, 0.55, 0.9, 0.9, 0.9)
        if data.juju then
            row("Potion", Utils.formatTime(data.juju.timeUntilRefresh or 0), 0.5, 0.5, 0.55, 0.9, 0.9, 0.9)
        end
        if data.familiar then
            row("Familiar", Utils.formatTime(data.familiar.timeUntilRefresh or 0), 0.5, 0.5, 0.55, 0.9, 0.9, 0.9)
            row("Summ. Points", tostring(data.familiar.summoningPoints or 0), 0.5, 0.5, 0.55, 0.9, 0.9, 0.9)
        end

        ImGui.EndTable()
    end
end

local function drawMetricsTab(data)
    local m = data.metrics
    if not m then return end

    if m.maxLevel then
        progressBar(1.0, 20, string.format("Mining %d  -  %s/hr", m.currentLevel, formatNumber(m.xpPerHour)), 0.3, 0.85, 0.45)
    else
        local pctText = string.format("%.0f%%", m.levelProgress * 100)
        local label = string.format("Mining %d (%s)  -  %s  -  %s/hr", m.currentLevel, pctText, formatDuration(m.ttl), formatNumber(m.xpPerHour))
        progressBar(m.levelProgress, 20, label, 0.2, 0.5, 0.9)
    end

    if m.crafting then
        ImGui.Spacing()
        local c = m.crafting
        if c.maxLevel then
            progressBar(1.0, 20, string.format("Crafting %d  -  %s/hr", c.level, formatNumber(c.xpPerHour)), 0.3, 0.85, 0.45)
        else
            local pctText = string.format("%.0f%%", c.levelProgress * 100)
            local label = string.format("Crafting %d (%s)  -  %s  -  %s/hr", c.level, pctText, formatDuration(c.ttl), formatNumber(c.xpPerHour))
            progressBar(c.levelProgress, 20, label, 0.9, 0.6, 0.2)
        end
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.55, 1.0)
        ImGui.TextWrapped("No warnings.")
        ImGui.PopStyleColor(1)
        return
    end
    for _, warning in ipairs(gui.warnings) do
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.75, 0.2, 1.0)
        ImGui.TextWrapped(warning)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.45, 0.1, 0.8)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.65, 0.55, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.8, 0.7, 0.1, 1.0)
    if ImGui.Button("Dismiss Warnings##clear", -1, 25) then
        gui.warnings = {}
    end
    ImGui.PopStyleColor(3)
end

local function drawContent(data, gui)
    if ImGui.BeginTabBar("##maintabs", 0) then
        if not gui.started then
            local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectConfigTab = false
            local configSelected = ImGui.BeginTabItem("Config###config", nil, configFlags)
            if configSelected then
                ImGui.Spacing()
                drawConfigTab(gui.config, gui)
                ImGui.EndTabItem()
            end
        end

        local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectInfoTab = false
        local infoSelected = ImGui.BeginTabItem("Info###info", nil, infoFlags)
        if infoSelected then
            ImGui.Spacing()
            if gui.started then
                drawInfoTab(data)
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.55, 1.0)
                ImGui.TextWrapped("Configure settings and press Start Mining.")
                ImGui.PopStyleColor(1)
            end
            ImGui.EndTabItem()
        end

        if gui.started then
            if ImGui.BeginTabItem("Metrics###metrics") then
                ImGui.Spacing()
                drawMetricsTab(data)
                ImGui.EndTabItem()
            end
        end

        if #gui.warnings > 0 then
            local warningLabel = "Warnings (" .. #gui.warnings .. ")###warnings"
            local warnFlags = gui.selectWarningsTab and ImGuiTabItemFlags.SetSelected or 0
            local warnSelected = ImGui.BeginTabItem(warningLabel, nil, warnFlags)
            if warnSelected then gui.selectWarningsTab = false end
            if warnSelected then
                ImGui.Spacing()
                drawWarningsTab(gui)
                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end

end

function MiningGUI.draw(data)
    ImGui.SetNextWindowSize(340, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.07, 0.07, 0.09, 0.95)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.10, 0.10, 0.13, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.13, 0.13, 0.18, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0.2, 0.2, 0.25, 0.5)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 3)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 5)

    local title = "Miner - " .. API.ScriptRuntimeString() .. "###Miner"
    local visible = ImGui.Begin(title, 0)

    if visible then
        local ok, err = pcall(drawContent, data, MiningGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(4)
    ImGui.End()

    return MiningGUI.open
end

return MiningGUI
