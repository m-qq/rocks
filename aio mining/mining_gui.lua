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
    MiningGUI._filteredLocNames = nil
    MiningGUI._filteredLocMapping = nil
    MiningGUI._familiarKeys = nil
    MiningGUI._familiarNames = nil
    MiningGUI._refreshKeys = nil
    MiningGUI._refreshNames = nil
    -- Reset preset popup state
    MiningGUI.presetPopup.open = false
    MiningGUI.presetPopup.mode = nil
    MiningGUI.presetPopup.inputName = ""
    MiningGUI.presetPopup.presetList = {}
    MiningGUI.presetPopup.selectedIndex = 0
    MiningGUI.presetPopup.errorMsg = nil
end

function MiningGUI.addWarning(msg)
    MiningGUI.warnings[#MiningGUI.warnings + 1] = msg
    if #MiningGUI.warnings > 50 then
        table.remove(MiningGUI.warnings, 1)
    end
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

-- Find 0-based index of a key in a sorted array, or -1 if not found
local function findKeyIndex(keys, key)
    if not key then return -1 end
    for i, k in ipairs(keys) do
        if k == key then return i - 1 end
    end
    return -1
end

local PRESETS_FILE = os.getenv("USERPROFILE") .. "\\MemoryError\\Lua_Scripts\\aio mining\\mining_presets.json"

-- Preset management state
MiningGUI.presetPopup = {
    open = false,
    mode = nil, -- "save" or "load"
    inputName = "",
    presetList = {},
    selectedIndex = 0,
    errorMsg = nil,
}

-- In-memory cache of all presets (loaded once, updated on save/delete)
local presetsCache = nil

local function loadAllPresets()
    if presetsCache then return presetsCache end
    local file = io.open(PRESETS_FILE, "r")
    if not file then
        presetsCache = {}
        return presetsCache
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        presetsCache = {}
        return presetsCache
    end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or type(data) ~= "table" then
        presetsCache = {}
        return presetsCache
    end
    presetsCache = data
    return presetsCache
end

local function saveAllPresets()
    local file = io.open(PRESETS_FILE, "w")
    if not file then return false end
    if not presetsCache or not next(presetsCache) then
        file:write("{}")
    else
        local ok, json = pcall(API.JsonEncode, presetsCache)
        if not ok or not json then
            file:close()
            return false
        end
        file:write(json)
    end
    file:close()
    return true
end

local function listPresets()
    local presets = loadAllPresets()
    local names = {}
    for name in pairs(presets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

local function savePresetToFile(presetName, cfg)
    local oreKey = oreKeys[cfg.oreIndex + 1]
    local oreDef = ORES[oreKey]
    local isGemRock = oreDef and oreDef.isGemRock
    local isStackable = oreDef and oreDef.isStackable
    local noOreBox = oreDef and oreDef.noOreBox
    local noRockertunities = oreDef and oreDef.noRockertunities

    local data = {
        Ore = oreKey,
        MiningLocation = locationKeys[cfg.locationIndex + 1],
        BankingLocation = bankKeys[cfg.bankIndex + 1],
        StaminaRefreshPercent = cfg.staminaPercent,
        ThreeTickMining = cfg.threeTickMining,
        UseSummoning = cfg.useSummoning,
        SummoningRefreshLocation = cfg.summoningRefreshLocation,
        BankPin = cfg.bankPin,
    }

    -- Only save options valid for ore type
    if isGemRock then
        data.UseGemBag = cfg.useGemBag
        data.DropGems = cfg.dropGems
        data.CutAndDrop = cfg.cutAndDrop
    elseif not isStackable then
        data.DropOres = cfg.dropOres
        data.UseOreBox = not noOreBox and cfg.useOreBox
        data.ChaseRockertunities = not noRockertunities and cfg.chaseRockertunities
        data.UseJuju = cfg.useJuju
    end

    local presets = loadAllPresets()
    presets[presetName] = data
    if not saveAllPresets() then
        return false, "Failed to save presets file"
    end
    return true
end

local function loadPresetFromFile(presetName)
    local presets = loadAllPresets()
    return presets[presetName]
end

local function deletePreset(presetName)
    local presets = loadAllPresets()
    presets[presetName] = nil
    saveAllPresets()
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
-- Returns 0 (default) if not found
local function resolveIndex(keys, value)
    if type(value) == "string" then
        local idx = findKeyIndex(keys, value)
        return idx >= 0 and idx or 0
    elseif type(value) == "number" then
        return math.max(0, math.min(value, #keys - 1))
    end
    return 0
end

-- Apply saved data to config
local function applyConfigData(saved, c)
    -- Core settings with validation
    local oreIdx = saved.Ore and findKeyIndex(oreKeys, saved.Ore) or -1
    local locIdx = saved.MiningLocation and findKeyIndex(locationKeys, saved.MiningLocation) or -1

    if saved.Ore and oreIdx < 0 then
        API.printlua("Warning: Ore '" .. tostring(saved.Ore) .. "' not found, using default", 4, false)
    end
    if saved.MiningLocation and locIdx < 0 then
        API.printlua("Warning: Location '" .. tostring(saved.MiningLocation) .. "' not found, using default", 4, false)
    end

    c.oreIndex = resolveIndex(oreKeys, saved.Ore)
    c.locationIndex = resolveIndex(locationKeys, saved.MiningLocation)
    c.bankIndex = resolveIndex(bankKeys, saved.BankingLocation)
    c.staminaPercent = type(saved.StaminaRefreshPercent) == "number"
        and math.max(50, math.min(100, saved.StaminaRefreshPercent)) or 85
    c.threeTickMining = saved.ThreeTickMining == true
    c.useSummoning = type(saved.UseSummoning) == "string" and saved.UseSummoning or "none"
    c.summoningRefreshLocation = type(saved.SummoningRefreshLocation) == "string"
        and saved.SummoningRefreshLocation or "wars_retreat"
    c.bankPin = type(saved.BankPin) == "string" and saved.BankPin or ""

    -- Reset all mode options to defaults first
    c.dropOres = false
    c.useOreBox = true
    c.chaseRockertunities = true
    c.dropGems = false
    c.cutAndDrop = false
    c.useGemBag = false
    c.useJuju = "none"

    -- Apply ore-type-specific options from saved data
    local oreKey = oreKeys[c.oreIndex + 1]
    local oreDef = ORES[oreKey]
    local isGemRock = oreDef and oreDef.isGemRock
    local isStackable = oreDef and oreDef.isStackable

    if isGemRock then
        c.dropGems = saved.DropGems == true
        c.cutAndDrop = saved.CutAndDrop == true
        c.useGemBag = saved.UseGemBag == true
    elseif not isStackable then
        c.dropOres = saved.DropOres == true
        c.useOreBox = saved.UseOreBox ~= false  -- default true
        c.chaseRockertunities = saved.ChaseRockertunities ~= false  -- default true
        c.useJuju = type(saved.UseJuju) == "string" and saved.UseJuju or "none"
    end

    -- Validate location has the selected ore
    local selectedLocKey = locationKeys[c.locationIndex + 1]
    if oreKey and selectedLocKey and oreToLocations[oreKey] then
        if not oreToLocations[oreKey][selectedLocKey] then
            local filtered = getFilteredLocationIndices(oreKey)
            if #filtered > 0 then
                c.locationIndex = filtered[1] - 1
            end
        end
    end
end

-- Reset config to defaults
function MiningGUI.resetConfig()
    local c = MiningGUI.config
    c.oreIndex = 0
    c.locationIndex = 0
    c.bankIndex = 0
    c.staminaPercent = 85
    c.dropOres = false
    c.useOreBox = true
    c.chaseRockertunities = true
    c.dropGems = false
    c.cutAndDrop = false
    c.useGemBag = false
    c.threeTickMining = false
    c.useJuju = "none"
    c.useSummoning = "none"
    c.summoningRefreshLocation = "wars_retreat"
    c.bankPin = ""
    -- Clear warnings and cached dropdown data
    MiningGUI.warnings = {}
    MiningGUI._filteredLocNames = nil
    MiningGUI._filteredLocMapping = nil
    MiningGUI._familiarKeys = nil
    MiningGUI._familiarNames = nil
    MiningGUI._refreshKeys = nil
    MiningGUI._refreshNames = nil
end

-- Load a named preset into config
function MiningGUI.loadPreset(presetName)
    local saved = loadPresetFromFile(presetName)
    if not saved then return false end
    -- Clear warnings before loading new config
    MiningGUI.warnings = {}
    applyConfigData(saved, MiningGUI.config)
    -- Clear cached dropdown data
    MiningGUI._filteredLocNames = nil
    MiningGUI._filteredLocMapping = nil
    MiningGUI._familiarKeys = nil
    MiningGUI._familiarNames = nil
    return true
end

-- Save current config as a named preset
function MiningGUI.savePreset(presetName)
    return savePresetToFile(presetName, MiningGUI.config)
end

-- Convert GUI state to cfg table for the script
function MiningGUI.getConfig()
    local c = MiningGUI.config
    local oreKey = oreKeys[c.oreIndex + 1]
    local oreDef = ORES[oreKey]
    local isGemRock = oreDef and oreDef.isGemRock
    local isStackable = oreDef and oreDef.isStackable
    local noOreBox = oreDef and oreDef.noOreBox
    local noRockertunities = oreDef and oreDef.noRockertunities

    local cfg = {
        ore = oreKey,
        location = locationKeys[c.locationIndex + 1],
        bankLocation = bankKeys[c.bankIndex + 1],
        staminaRefreshPercent = c.staminaPercent,
        threeTickMining = not isStackable and c.threeTickMining or false,
        useSummoning = c.useSummoning,
        summoningRefreshLocation = c.summoningRefreshLocation,
        bankPin = c.bankPin,
    }

    -- Ore-type-specific options
    if isGemRock then
        cfg.dropGems = c.dropGems
        cfg.cutAndDrop = c.cutAndDrop
        cfg.useGemBag = c.useGemBag
        cfg.dropOres = false
        cfg.useOreBox = false
        cfg.chaseRockertunities = false
        cfg.useJuju = "none"
    elseif isStackable then
        cfg.dropOres = false
        cfg.useOreBox = false
        cfg.chaseRockertunities = false
        cfg.dropGems = false
        cfg.cutAndDrop = false
        cfg.useGemBag = false
        cfg.useJuju = "none"
    else
        cfg.dropOres = c.dropOres
        cfg.useOreBox = not noOreBox and c.useOreBox or false
        cfg.chaseRockertunities = not noRockertunities and c.chaseRockertunities or false
        cfg.useJuju = c.useJuju
        cfg.dropGems = false
        cfg.cutAndDrop = false
        cfg.useGemBag = false
    end

    return cfg
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
    ImGui.PushStyleColor(ImGuiCol.Text, lr or 0.55, lg or 0.55, lb or 0.58, 1.0)
    ImGui.TextUnformatted(label)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, vr or 0.78, vg or 0.78, vb or 0.8, 1.0)
    ImGui.TextUnformatted(tostring(value))
    ImGui.PopStyleColor(1)
end

local function progressBar(progress, height, text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, r * 0.5, g * 0.5, b * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.12, 0.12, 0.15, 1.0)
    ImGui.ProgressBar(progress, -1, height, text)
    ImGui.PopStyleColor(2)
end

local function label(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.62, 0.65, 1.0)
    ImGui.TextUnformatted(text)
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

-- UI mode: "presets" shows preset list, "setup" shows configuration
local uiMode = "presets"
local presetSaveName = ""

local function getPresetNames()
    return listPresets()
end

local function getPresetInfo(name)
    local data = loadPresetFromFile(name)
    if not data then return { ore = "?", location = "?", bank = "?", mode = "?" } end
    local info = {}
    local oreDef = ORES[data.Ore]
    info.ore = oreDef and oreDef.name or "?"
    local locDef = LOCATIONS[data.MiningLocation]
    info.location = locDef and locDef.name or "?"
    local bankDef = Banking.LOCATIONS[data.BankingLocation]
    info.bank = bankDef and bankDef.name or "?"
    local isGemRock = oreDef and oreDef.isGemRock
    -- Mode based on ore type
    if isGemRock then
        if data.DropGems then info.mode = "Drop"
        elseif data.CutAndDrop then info.mode = "Cut & Drop"
        elseif data.UseGemBag then info.mode = "Gem Bag"
        else info.mode = "Bank" end
    else
        if data.DropOres then info.mode = "Drop"
        elseif data.UseOreBox then info.mode = "Ore Box"
        else info.mode = "Bank" end
    end
    -- Extras (only show if valid for ore type)
    info.rock = not isGemRock and data.ChaseRockertunities and not (oreDef and oreDef.noRockertunities)
    info.juju = not isGemRock and data.UseJuju and data.UseJuju ~= "none"
    info.summon = data.UseSummoning and data.UseSummoning ~= "none"
    return info
end

local function drawConfigTab(cfg, gui)
    if gui.started then
        local runText = "Running"
        local tw = ImGui.CalcTextSize(runText)
        local rw = ImGui.GetContentRegionAvail()
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + (rw - tw) * 0.5)
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.65, 0.5, 1.0)
        ImGui.TextUnformatted(runText)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        drawConfigSummary(cfg)
        return
    end

    local presetNames = getPresetNames()

    -- Auto-switch to setup mode if no presets
    if #presetNames == 0 then
        uiMode = "setup"
    end

    if uiMode == "presets" then
        local toDelete = nil
        local rowH, xWidth, rounding = 26, 28, 3
        local listHeight = math.min(#presetNames * 36, 216)

        ImGui.BeginChild("presetList", -1, listHeight, false)
        for i, name in ipairs(presetNames) do
            ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.13, 0.14, 0.16, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Border, 0.25, 0.27, 0.30, 1.0)
            ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, rounding)
            ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, 1)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
            ImGui.BeginChild("preset" .. i, -1, rowH, true)

            local availW = ImGui.GetContentRegionAvail() - 6

            ImGui.PushStyleColor(ImGuiCol.Button, 0.0, 0.0, 0.0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.20, 0.38, 0.28, 0.4)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.18, 0.32, 0.24, 0.6)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 0)
            ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, rounding)
            if ImGui.Button(name .. "##start" .. i, availW - xWidth, rowH) then
                gui.loadPreset(name)
                gui.started = true
            end
            ImGui.PopStyleVar(2)
            ImGui.PopStyleColor(3)

            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Button, 0.0, 0.0, 0.0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.25, 0.25, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.4, 0.2, 0.2, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.63, 1.0)
            ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, rounding)
            if ImGui.Button("x##del" .. i, xWidth, rowH) then
                toDelete = name
            end
            ImGui.PopStyleVar(1)
            ImGui.PopStyleColor(4)

            ImGui.EndChild()
            ImGui.PopStyleVar(4)
            ImGui.PopStyleColor(2)
            ImGui.Spacing()
        end
        ImGui.EndChild()

        if toDelete then deletePreset(toDelete) end

        ImGui.Spacing()

        -- New setup button
        ImGui.PushStyleColor(ImGuiCol.Button, 0.18, 0.25, 0.35, 0.95)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.24, 0.32, 0.45, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.16, 0.22, 0.32, 1.0)
        if ImGui.Button("+ New Preset", -1, 30) then
            uiMode = "setup"
            presetSaveName = ""
        end
        ImGui.PopStyleColor(3)

        return
    end

    -- ============ SETUP MODE ============
    -- Back button if we have presets
    if #presetNames > 0 then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.22, 0.25, 0.30, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.34, 0.40, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.30, 0.36, 1.0)
        if ImGui.Button("< Back", 70, 22) then
            uiMode = "presets"
        end
        ImGui.PopStyleColor(3)
        ImGui.Spacing()
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
    local filteredLocNames = gui._filteredLocNames or {}
    local filteredLocMapping = gui._filteredLocMapping or {}
    for i = 1, math.max(#filteredLocNames, #filteredLocIndices) do
        if i <= #filteredLocIndices then
            filteredLocNames[i] = locationNames[filteredLocIndices[i]]
            filteredLocMapping[i] = filteredLocIndices[i]
        else
            filteredLocNames[i] = nil
            filteredLocMapping[i] = nil
        end
    end
    gui._filteredLocNames = filteredLocNames
    gui._filteredLocMapping = filteredLocMapping
    local currentFilteredIdx = 0
    local foundInFiltered = false
    for i, globalIdx in ipairs(filteredLocIndices) do
        if (globalIdx - 1) == cfg.locationIndex then
            currentFilteredIdx = i - 1
            foundInFiltered = true
            break
        end
    end
    -- If current location not in filtered list, update to first valid location
    if not foundInFiltered and #filteredLocIndices > 0 then
        cfg.locationIndex = filteredLocIndices[1] - 1
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
    if not gui._familiarKeys then
        local summoningLevel = API.XPLevelTable(API.GetSkillXP("SUMMONING"))
        gui._familiarKeys = {"none"}
        gui._familiarNames = {"None"}
        for key, def in pairs(DATA.SUMMONING_FAMILIARS) do
            if not def.levelReq or summoningLevel >= def.levelReq then
                gui._familiarKeys[#gui._familiarKeys + 1] = key
                gui._familiarNames[#gui._familiarNames + 1] = def.name
            end
        end
        gui._refreshKeys = {}
        gui._refreshNames = {}
        for key, loc in pairs(DATA.SUMMONING_REFRESH_LOCATIONS) do
            gui._refreshKeys[#gui._refreshKeys + 1] = key
            gui._refreshNames[#gui._refreshNames + 1] = loc.name
        end
    end
    local familiarKeys = gui._familiarKeys
    local familiarNames = gui._familiarNames

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
            local refreshKeys = gui._refreshKeys
            local refreshNames = gui._refreshNames
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

    -- Save as preset option
    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.65, 0.7, 1.0)
    ImGui.TextUnformatted("Save as preset (optional):")
    ImGui.PopStyleColor(1)

    ImGui.PushItemWidth(-1)
    local nameChanged, newName = ImGui.InputText("##saveName", presetSaveName, 0)
    if nameChanged then
        presetSaveName = newName
    end
    ImGui.PopItemWidth()

    ImGui.Spacing()

    -- Start button (saves preset if name provided)
    ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.45, 0.30, 0.95)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.52, 0.35, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.22, 0.40, 0.27, 1.0)

    local buttonLabel = presetSaveName ~= "" and "Save & Start" or "Start"
    if ImGui.Button(buttonLabel .. "##start", -1, 32) then
        -- Save preset if name provided
        if presetSaveName ~= "" then
            local name = presetSaveName:match("^%s*(.-)%s*$")  -- trim
            if name ~= "" then
                gui.savePreset(name)
            end
        end
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
    -- Progress bars section
    local hasProgressBars = false

    -- Stamina bar
    if not data.noStamina then
        local drain = data.currentStamina or 0
        local max = data.maxStamina or 1
        local remaining = math.max(0, math.min(max, max - drain))
        local pct = remaining / max
        local sr, sg, sb = 0.45, 0.65, 0.45
        if pct <= 0.3 then
            sr, sg, sb = 0.7, 0.35, 0.35
        elseif pct <= 0.6 then
            sr, sg, sb = 0.7, 0.6, 0.3
        end
        progressBar(pct, 18, string.format("Stamina  %d / %d", remaining, max), sr, sg, sb)
        hasProgressBars = true
    end

    -- Daily Limit bar
    if data.dailyLimit then
        if hasProgressBars then ImGui.Spacing() end
        local cur = data.dailyLimit.current or 0
        local max = data.dailyLimit.max or 1
        local pct = cur / max
        local dr, dg, db = 0.45, 0.65, 0.45
        if pct >= 1.0 then
            dr, dg, db = 0.7, 0.35, 0.35
        elseif pct > 0.8 then
            dr, dg, db = 0.7, 0.6, 0.3
        end
        progressBar(pct, 18, string.format("Daily  %d / %d", cur, max), dr, dg, db)
        hasProgressBars = true
    end

    -- Ore Box bar
    if data.oreBox then
        if hasProgressBars then ImGui.Spacing() end
        local oreName = data.oreName or "Ore"
        local count = data.oreBox.count or 0
        local cap = data.oreBox.capacity or 1
        local p = count / cap
        progressBar(p, 18, string.format("%s  %d / %d", oreName, count, cap), 0.5, 0.55, 0.65)
        hasProgressBars = true
    end

    -- Gem Bag bar
    if data.gemBag then
        if hasProgressBars then ImGui.Spacing() end
        local total = data.gemBag.total or 0
        local cap = data.gemBag.capacity or 1
        local p = total / cap
        local gr, gg, gb = 0.5, 0.55, 0.65
        if p > 0.9 then gr, gg, gb = 0.7, 0.35, 0.35
        elseif p > 0.7 then gr, gg, gb = 0.7, 0.6, 0.3 end
        progressBar(p, 18, string.format("Gem Bag  %d / %d", total, cap), gr, gg, gb)
        hasProgressBars = true
    end

    -- Separator after progress bars
    if hasProgressBars then
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    -- Info table
    if ImGui.BeginTable("##info", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.38)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.62)

        row("Location", data.location or "--")
        row("Bank", data.bankLocation or "--")
        if data.mode then
            row("Mode", data.mode)
        end

        -- Timers
        row("Anti-idle", Utils.formatTime(data.antiIdleTime or 0))
        if data.juju then
            row("Potion", Utils.formatTime(data.juju.timeUntilRefresh or 0))
        end
        if data.familiar then
            row("Familiar", Utils.formatTime(data.familiar.timeUntilRefresh or 0))
            row("Summ. Points", tostring(data.familiar.summoningPoints or 0))
        end

        ImGui.EndTable()
    end

    -- Gem bag details (collapsible or only if gems present)
    if data.gemBag and data.gemBag.total and data.gemBag.total > 0 then
        ImGui.Spacing()
        if ImGui.CollapsingHeader("Gem Bag") then
            if ImGui.BeginTable("##gems", 2) then
                ImGui.TableSetupColumn("gem", ImGuiTableColumnFlags.WidthStretch, 0.38)
                ImGui.TableSetupColumn("cnt", ImGuiTableColumnFlags.WidthStretch, 0.62)
                local pgc = data.gemBag.perGemCapacity
                local fmt = pgc and function(v) return v .. " / " .. pgc end or tostring
                local function gemRow(name, value)
                    local c = GEM_COLORS[name] or {0.6, 0.6, 0.6}
                    row(name, fmt(value), c[1], c[2], c[3])
                end
                if (data.gemBag.sapphire or 0) > 0 then gemRow("Sapphire", data.gemBag.sapphire) end
                if (data.gemBag.emerald or 0) > 0 then gemRow("Emerald", data.gemBag.emerald) end
                if (data.gemBag.ruby or 0) > 0 then gemRow("Ruby", data.gemBag.ruby) end
                if (data.gemBag.diamond or 0) > 0 then gemRow("Diamond", data.gemBag.diamond) end
                if pgc and (data.gemBag.dragonstone or 0) > 0 then gemRow("Dragonstone", data.gemBag.dragonstone) end
                ImGui.EndTable()
            end
        end
    end
end

local function drawMetricsTab(data)
    local m = data.metrics
    if not m then return end

    -- Mining XP bar
    if m.maxLevel then
        progressBar(1.0, 18, string.format("Mining %d  |  %s/hr", m.currentLevel, formatNumber(m.xpPerHour)), 0.45, 0.6, 0.45)
    else
        local pctText = string.format("%.0f%%", m.levelProgress * 100)
        local label = string.format("Mining %d (%s)  |  %s  |  %s/hr", m.currentLevel, pctText, formatDuration(m.ttl), formatNumber(m.xpPerHour))
        progressBar(m.levelProgress, 18, label, 0.45, 0.55, 0.65)
    end

    -- Crafting XP bar (if applicable)
    if m.crafting then
        ImGui.Spacing()
        local c = m.crafting
        if c.maxLevel then
            progressBar(1.0, 18, string.format("Crafting %d  |  %s/hr", c.level, formatNumber(c.xpPerHour)), 0.45, 0.6, 0.45)
        else
            local pctText = string.format("%.0f%%", c.levelProgress * 100)
            local label = string.format("Crafting %d (%s)  |  %s  |  %s/hr", c.level, pctText, formatDuration(c.ttl), formatNumber(c.xpPerHour))
            progressBar(c.levelProgress, 18, label, 0.6, 0.55, 0.45)
        end
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.52, 1.0)
        ImGui.TextUnformatted("No warnings.")
        ImGui.PopStyleColor(1)
        return
    end
    for _, warning in ipairs(gui.warnings) do
        ImGui.PushStyleColor(ImGuiCol.Text, 0.85, 0.7, 0.35, 1.0)
        ImGui.TextWrapped(warning)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.35, 0.35, 0.38, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.45, 0.48, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.52, 1.0)
    if ImGui.Button("Dismiss##clear", -1, 24) then
        gui.warnings = {}
    end
    ImGui.PopStyleColor(3)
end

local function drawPresetPopup(gui)
    local popup = gui.presetPopup
    if not popup.open then return end

    local popupTitle = popup.mode == "save" and "Save Preset###presetPopup" or "Load Preset###presetPopup"
    ImGui.SetNextWindowSize(280, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(150, 150, ImGuiCond.FirstUseEver)

    local visible = ImGui.Begin(popupTitle, ImGuiWindowFlags.NoCollapse)
    if visible then
        if popup.mode == "save" then
            -- Save mode: input field for preset name
            label("Preset Name")
            ImGui.PushItemWidth(-1)
            local changed, newName = ImGui.InputText("##presetName", popup.inputName, 0)
            if changed then
                popup.inputName = newName
                popup.errorMsg = nil
            end
            ImGui.PopItemWidth()

            if popup.errorMsg then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.85, 0.45, 0.4, 1.0)
                ImGui.TextWrapped(popup.errorMsg)
                ImGui.PopStyleColor(1)
            end

            ImGui.Spacing()

            -- Show existing presets for reference
            if #popup.presetList > 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.55, 1.0)
                ImGui.TextWrapped("Existing presets:")
                ImGui.PopStyleColor(1)
                for _, name in ipairs(popup.presetList) do
                    ImGui.BulletText(name)
                end
                ImGui.Spacing()
            end

            ImGui.Separator()
            ImGui.Spacing()

            -- Buttons
            ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.45, 0.30, 0.95)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.52, 0.35, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.22, 0.40, 0.27, 1.0)
            if ImGui.Button("Save##savePreset", 120, 24) then
                local name = popup.inputName:match("^%s*(.-)%s*$") -- trim
                if name == "" then
                    popup.errorMsg = "Please enter a name"
                else
                    local success, err = gui.savePreset(name)
                    if success then
                        popup.open = false
                        popup.inputName = ""
                        popup.errorMsg = nil
                        API.printlua("Preset '" .. name .. "' saved", 0, false)
                    else
                        popup.errorMsg = err or "Failed to save preset"
                    end
                end
            end
            ImGui.PopStyleColor(3)

            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.Button, 0.35, 0.35, 0.38, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.45, 0.48, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.52, 1.0)
            if ImGui.Button("Cancel##cancelPreset", 120, 24) then
                popup.open = false
                popup.inputName = ""
                popup.errorMsg = nil
            end
            ImGui.PopStyleColor(3)

        else
            -- Load mode: list of presets to select
            if #popup.presetList == 0 then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.52, 1.0)
                ImGui.TextUnformatted("No saved presets found.")
                ImGui.PopStyleColor(1)
            else
                label("Select Preset")
                ImGui.PushItemWidth(-1)
                local changed, newIdx = ImGui.Combo("##presetSelect", popup.selectedIndex, popup.presetList, 10)
                if changed then
                    popup.selectedIndex = newIdx
                    popup.errorMsg = nil
                end
                ImGui.PopItemWidth()
            end

            if popup.errorMsg then
                ImGui.PushStyleColor(ImGuiCol.Text, 0.85, 0.45, 0.4, 1.0)
                ImGui.TextWrapped(popup.errorMsg)
                ImGui.PopStyleColor(1)
            end

            ImGui.Spacing()
            ImGui.Separator()
            ImGui.Spacing()

            -- Buttons
            if #popup.presetList > 0 then
                ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.45, 0.30, 0.95)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.52, 0.35, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.22, 0.40, 0.27, 1.0)
                if ImGui.Button("Load##loadPreset", 76, 24) then
                    local presetName = popup.presetList[popup.selectedIndex + 1]
                    if presetName then
                        local success = gui.loadPreset(presetName)
                        if success then
                            popup.open = false
                            popup.errorMsg = nil
                            API.printlua("Preset '" .. presetName .. "' loaded", 0, false)
                        else
                            popup.errorMsg = "Failed to load preset"
                        end
                    end
                end
                ImGui.PopStyleColor(3)

                ImGui.SameLine()

                ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.32, 0.32, 0.9)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.58, 0.38, 0.38, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.28, 0.28, 1.0)
                if ImGui.Button("Delete##deletePreset", 76, 24) then
                    local presetName = popup.presetList[popup.selectedIndex + 1]
                    if presetName then
                        deletePreset(presetName)
                        popup.presetList = listPresets()
                        popup.selectedIndex = 0
                        API.printlua("Preset '" .. presetName .. "' deleted", 0, false)
                    end
                end
                ImGui.PopStyleColor(3)

                ImGui.SameLine()
            end

            ImGui.PushStyleColor(ImGuiCol.Button, 0.35, 0.35, 0.38, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.45, 0.48, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.52, 1.0)
            if ImGui.Button("Cancel##cancelLoad", 76, 24) then
                popup.open = false
                popup.errorMsg = nil
            end
            ImGui.PopStyleColor(3)
        end
    end
    ImGui.End()
end

local function drawContent(data, gui)

    if ImGui.BeginTabBar("##maintabs", 0) then
        if not gui.started then
            local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectConfigTab = false
            local configSelected = ImGui.BeginTabItem("Presets###config", nil, configFlags)
            if configSelected then
                ImGui.Spacing()
                drawConfigTab(gui.config, gui)
                ImGui.EndTabItem()
            end
        end

        if gui.started then
            local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectInfoTab = false
            if ImGui.BeginTabItem("Info###info", nil, infoFlags) then
                ImGui.Spacing()
                drawInfoTab(data)
                ImGui.EndTabItem()
            end

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

    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.08, 0.08, 0.09, 0.96)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.11, 0.11, 0.12, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.14, 0.14, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0.25, 0.25, 0.28, 0.4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12, 8)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 2)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 4)

    local now = os.clock()
    if not MiningGUI._titleCache or now - (MiningGUI._titleCacheTime or 0) >= 1 then
        local title
        if MiningGUI.started then
            local state = (data and data.state) or "Idle"
            local runtime = API.ScriptRuntimeString()
            title = string.format("%s | %s", state, runtime)
        else
            title = "Config"
        end
        MiningGUI._titleCache = title .. "###Miner"
        MiningGUI._titleCacheTime = now
    end
    local visible = ImGui.Begin(MiningGUI._titleCache, 0)

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
