local API = require("api")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")

local Teleports = {}

Teleports.LODESTONES = {
    AL_KHARID = {loc = WPOINT.new(3297, 3184, 0), name = "Al Kharid", interfaceId = 11, varbit = 28},
    ANACHRONIA = {loc = WPOINT.new(5431, 2338, 0), name = "Anachronia", interfaceId = 25, varbit = 44270},
    ARDOUGNE = {loc = WPOINT.new(2634, 3348, 0), name = "Ardougne", interfaceId = 12, varbit = 29},
    ASHDALE = {loc = WPOINT.new(2474, 2708, 2), name = "Ashdale", interfaceId = 34, varbit = 22430},
    BANDIT_CAMP = {loc = WPOINT.new(3214, 2954, 0), name = "Bandit Camp", interfaceId = 9},
    BURTHORPE = {loc = WPOINT.new(2899, 3544, 0), name = "Burthorpe", interfaceId = 13, varbit = 30},
    CANIFIS = {loc = WPOINT.new(3517, 3515, 0), name = "Canifis", interfaceId = 27, varbit = 18523},
    CATHERBY = {loc = WPOINT.new(2811, 3449, 0), name = "Catherby", interfaceId = 14, varbit = 31},
    DRAYNOR_VILLAGE = {loc = WPOINT.new(3105, 3298, 0), name = "Draynor Village", interfaceId = 15, varbit = 32},
    EAGLES_PEAK = {loc = WPOINT.new(2366, 3479, 0), name = "Eagles' Peak", interfaceId = 28, varbit = 18524},
    EDGEVILLE = {loc = WPOINT.new(3067, 3505, 0), name = "Edgeville", interfaceId = 16, varbit = 33},
    FALADOR = {loc = WPOINT.new(2967, 3403, 0), name = "Falador", interfaceId = 17, varbit = 34},
    FORT_FORINTHRY = {loc = WPOINT.new(3298, 3525, 0), name = "Fort Forinthry", interfaceId = 23, varbit = 52518},
    FREMENNIK_PROVINCE = {loc = WPOINT.new(2712, 3677, 0), name = "Fremennik Province", interfaceId = 29, varbit = 18525},
    KARAMJA = {loc = WPOINT.new(2761, 3147, 0), name = "Karamja", interfaceId = 30, varbit = 18526},
    LUNAR_ISLE = {loc = WPOINT.new(2085, 3914, 0), name = "Lunar Isle", interfaceId = 10},
    LUMBRIDGE = {loc = WPOINT.new(3233, 3221, 0), name = "Lumbridge", interfaceId = 18, varbit = 35},
    MENAPHOS = {loc = WPOINT.new(3216, 2716, 0), name = "Menaphos", interfaceId = 24, varbit = 36173},
    OOGLOG = {loc = WPOINT.new(2532, 2871, 0), name = "Oo'glog", interfaceId = 31, varbit = 18527},
    PORT_SARIM = {loc = WPOINT.new(3011, 3215, 0), name = "Port Sarim", interfaceId = 19, varbit = 36},
    PRIFDDINAS = {loc = WPOINT.new(2208, 3360, 1), name = "Prifddinas", interfaceId = 35, varbit = 24967},
    SEERS_VILLAGE = {loc = WPOINT.new(2689, 3482, 0), name = "Seers' Village", interfaceId = 20, varbit = 37},
    TAVERLEY = {loc = WPOINT.new(2878, 3442, 0), name = "Taverley", interfaceId = 21, varbit = 38},
    TIRANNWN = {loc = WPOINT.new(2254, 3149, 0), name = "Tirannwn", interfaceId = 32, varbit = 18528},
    UM = {loc = WPOINT.new(1084, 1768, 1), name = "City of Um", interfaceId = 36, varbit = 53270},
    VARROCK = {loc = WPOINT.new(3214, 3376, 0), name = "Varrock", interfaceId = 22, varbit = 39},
    WILDERNESS = {loc = WPOINT.new(3143, 3635, 0), name = "Wilderness Crater", interfaceId = 33, varbit = 18529},
    YANILLE = {loc = WPOINT.new(2560, 3094, 0), name = "Yanille", interfaceId = 26, varbit = 40}
}

local function isAtLodestone(lode)
    local playerLoc = API.PlayerCoord()
    return Utils.getDistance(playerLoc.x, playerLoc.y, lode.loc.x, lode.loc.y) <= 20
end

local function isLodestoneUnlocked(lode)
    if not lode.varbit then return true end
    return API.GetVarbitValue(lode.varbit) == 1
end

local function isLodestoneNetworkOpen()
    local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.LODESTONE_NETWORK)
    return #result > 0 and result[1].textids == "Lodestone Network"
end

local function openLodestoneNetwork()
    API.logInfo("Opening lodestone network...")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 33, -1, API.OFF_ACT_GeneralInterface_route)
    return Utils.waitOrTerminate(function()
        return isLodestoneNetworkOpen()
    end, 10, 100, "Failed to open lodestone network")
end

local function teleportViaNetwork(lode)
    if not isLodestoneNetworkOpen() then
        if not openLodestoneNetwork() then
            return false
        end
    end
    API.RandomSleep2(300, 100, 50)
    API.logInfo("Selecting " .. lode.name .. " lodestone...")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, lode.interfaceId, -1, API.OFF_ACT_GeneralInterface_route)
    return true
end

function Teleports.isLodestoneUnlocked(lode)
    return isLodestoneUnlocked(lode)
end

function Teleports.isLodestoneAvailable(lode)
    return API.isAbilityAvailable(lode.name .. " Lodestone")
end

function Teleports.lodestone(lode)
    if isAtLodestone(lode) then
        API.logInfo("Already at " .. lode.name .. " lodestone")
        return true
    end

    if not isLodestoneUnlocked(lode) then
        API.logError(lode.name .. " lodestone is not unlocked")
        API.Write_LoopyLoop(false)
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Teleporting to " .. lode.name .. " lodestone...")

    local useNetwork = false
    if Teleports.isLodestoneAvailable(lode) then
        if API.DoAction_Ability(lode.name .. " Lodestone", 1, API.OFF_ACT_GeneralInterface_route, true) then
            if not API.CheckAnim(200) then
                useNetwork = true
            end
        else
            useNetwork = true
        end
    else
        useNetwork = true
    end

    if useNetwork then
        API.logInfo("Using lodestone network interface...")
        if not teleportViaNetwork(lode) then
            return false
        end
        if not API.CheckAnim(200) then
            API.logError("Failed to start teleport animation")
            return false
        end
    end

    API.logInfo("Waiting for teleport animation...")
    if not Utils.waitOrTerminate(function()
        return isAtLodestone(lode)
    end, 20, 100, "Failed to teleport to " .. lode.name .. " lodestone") then
        return false
    end
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() > 0 end, 10, 100, "Teleport animation did not start")
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Teleport animation did not finish")
    API.logInfo("Teleport complete")
    API.RandomSleep2(600, 300, 50)
    return true
end

local function hasItemInEquipment(itemId, slot)
    local container = API.Container_Get_all(94)
    return container and container[slot] and container[slot].item_id == itemId
end

function Teleports.getEquippedCape(capeIds)
    for _, id in ipairs(capeIds) do
        if hasItemInEquipment(id, 2) then return id end
    end
    return nil
end

function Teleports.hasSlayerCape()
    if Teleports.getEquippedCape(DATA.SLAYER_CAPE_IDS) then return true end
    for _, id in ipairs(DATA.SLAYER_CAPE_IDS) do
        if Inventory:Contains(id) then return true end
    end
    return false
end

function Teleports.hasDungeoneeringCape()
    if Teleports.getEquippedCape(DATA.DUNGEONEERING_CAPE_IDS) then return true end
    for _, id in ipairs(DATA.DUNGEONEERING_CAPE_IDS) do
        if Inventory:Contains(id) then return true end
    end
    return false
end

Teleports.SLAYER_DESTINATIONS = {
    mandrith = {
        name = "1. Mandrith",
        selectKey = 49,
        interface = DATA.INTERFACES.SLAYER_CAPE_MANDRITH,
        coord = {x = 3050, y = 3949}
    },
    laniakea = {
        name = "2. Laniakea",
        selectKey = 50,
        interface = DATA.INTERFACES.SLAYER_CAPE_LANIAKEA,
        coord = {x = 5670, y = 2140}
    }
}

local SLAYER_CAPE_ACTIONS = {
    [9786] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [9787] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [31282] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [53782] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [34274] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [34275] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [53810] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [53839] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2}
}

function Teleports.slayerCape(destinationKey)
    local dest = Teleports.SLAYER_DESTINATIONS[destinationKey]
    if not dest then
        API.logError("Unknown Slayer cape destination: " .. tostring(destinationKey))
        return false
    end

    local capeId = Teleports.getEquippedCape(DATA.SLAYER_CAPE_IDS)
    local inventorySlot = nil
    if not capeId then
        for _, id in ipairs(DATA.SLAYER_CAPE_IDS) do
            if Inventory:Contains(id) then
                local item = Inventory:GetItem(id)
                capeId = id
                inventorySlot = item[1].slot
                break
            end
        end
    end

    if not capeId then
        API.logWarn("No Slayer cape found")
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Using Slayer cape to teleport to " .. dest.name .. "...")
    if inventorySlot then
        local params = SLAYER_CAPE_ACTIONS[capeId]
        API.DoAction_Interface(0x24, capeId, params.action, 1473, 5, inventorySlot, params.route)
    else
        API.DoAction_Interface(0xffffffff, capeId, 3, 1464, 15, 1, API.OFF_ACT_GeneralInterface_route)
    end

    if not Utils.waitOrTerminate(function()
        local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.SLAYER_MASTER_TELEPORT)
        return #result > 0 and result[1].textids == "Choose a slayer master"
    end, 10, 100, "Slayer teleport interface did not open") then
        return false
    end

    if dest.pageKey then
        API.logInfo("Navigating to next page...")
        API.KeyboardPress33(dest.pageKey, 0, 100, 50)
    end

    if not Utils.waitOrTerminate(function()
        local result = API.ScanForInterfaceTest2Get(false, dest.interface)
        return #result > 0 and result[1].textids == dest.name
    end, 10, 100, dest.name .. " option not found") then
        local result = API.ScanForInterfaceTest2Get(false, dest.interface)
        if #result > 0 then
            API.logError("Found instead: " .. tostring(result[1].textids))
        else
            API.logError("No interface results found")
        end
        return false
    end

    API.logInfo("Selecting " .. dest.name .. "...")
    API.KeyboardPress33(dest.selectKey, 0, 100, 50)

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local dist = Utils.getDistance(coord.x, coord.y, dest.coord.x, dest.coord.y)
        return API.ReadPlayerAnim() == 8941 and dist <= 15
    end, 15, 100, "Failed to teleport to " .. dest.name) then
        return false
    end
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Teleport animation did not finish")
    API.logInfo("Slayer cape teleport complete")
    return true
end

Teleports.DUNGEONEERING_DESTINATIONS = {
    al_kharid = {
        name = "5. Al Kharid hidden mine",
        pageKey = 48,
        selectKey = 53,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_AL_KHARID,
        coord = {x = 3301, y = 3308}
    },
    daemonheim = {
        name = "5. Daemonheim woodcutting island dungeon",
        selectKey = 53,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_DAEMONHEIM,
        coord = {x = 3513, y = 3663}
    },
    dwarven_mine = {
        name = "2. Dwarven mine hidden mine",
        selectKey = 50,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_DWARVEN,
        coord = {x = 3037, y = 9774}
    },
    karamja = {
        name = "4. Karamja Volcano lesser demon dungeon",
        selectKey = 52,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_KARAMJA,
        coord = {x = 2844, y = 9558}
    },
    mining_guild = {
        name = "7. Mining Guild hidden mine",
        selectKey = 55,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_MINING_GUILD,
        coord = {x = 3021, y = 9738}
    },
    kalgerion = {
        name = "9. Kal'gerion demon dungeon",
        pageKey = 48,
        selectKey = 57,
        interface = DATA.INTERFACES.DUNGEONEERING_CAPE_KALGERION,
        coord = {x = 3399, y = 3663}
    }
}

local DUNGEONEERING_CAPE_ACTIONS = {
    [18508] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [18509] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [19709] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [53792] = {action = 3, route = API.OFF_ACT_GeneralInterface_route},
    [34294] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [34295] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [53820] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2},
    [53849] = {action = 7, route = API.OFF_ACT_GeneralInterface_route2}
}

function Teleports.dungeoneeringCape(destinationKey)
    local dest = Teleports.DUNGEONEERING_DESTINATIONS[destinationKey]
    if not dest then
        API.logError("Unknown Dungeoneering cape destination: " .. tostring(destinationKey))
        return false
    end

    local capeId = Teleports.getEquippedCape(DATA.DUNGEONEERING_CAPE_IDS)
    local inventorySlot = nil
    if not capeId then
        for _, id in ipairs(DATA.DUNGEONEERING_CAPE_IDS) do
            if Inventory:Contains(id) then
                local item = Inventory:GetItem(id)
                capeId = id
                inventorySlot = item[1].slot
                break
            end
        end
    end

    if not capeId then
        API.logWarn("No Dungeoneering cape found")
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Using Dungeoneering cape to teleport to " .. dest.name .. "...")
    if inventorySlot then
        local params = DUNGEONEERING_CAPE_ACTIONS[capeId]
        API.DoAction_Interface(0x24, capeId, params.action, 1473, 5, inventorySlot, params.route)
    else
        API.DoAction_Interface(0xffffffff, capeId, 3, 1464, 15, 1, API.OFF_ACT_GeneralInterface_route)
    end

    if not Utils.waitOrTerminate(function()
        local result = API.ScanForInterfaceTest2Get(false, DATA.INTERFACES.DUNGEONEERING_CAPE_TELEPORT)
        return #result > 0 and result[1].textids == "Where would you like to teleport to?"
    end, 10, 100, "Dungeoneering cape teleport interface did not open") then
        return false
    end

    if dest.pageKey then
        API.logInfo("Navigating to next page...")
        API.KeyboardPress33(dest.pageKey, 0, 100, 50)
    end

    if not Utils.waitOrTerminate(function()
        local result = API.ScanForInterfaceTest2Get(false, dest.interface)
        return #result > 0 and result[1].textids == dest.name
    end, 10, 100, dest.name .. " option not found") then
        local result = API.ScanForInterfaceTest2Get(false, dest.interface)
        if #result > 0 then
            API.logError("Found instead: " .. tostring(result[1].textids))
        else
            API.logError("No interface results found")
        end
        return false
    end

    API.logInfo("Selecting " .. dest.name .. "...")
    API.KeyboardPress33(dest.selectKey, 0, 100, 50)

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local dist = Utils.getDistance(coord.x, coord.y, dest.coord.x, dest.coord.y)
        return API.ReadPlayerAnim() == 8941 and dist <= 15
    end, 15, 100, "Failed to teleport to " .. dest.name) then
        return false
    end
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Teleport animation did not finish")
    API.logInfo("Dungeoneering cape teleport complete")
    return true
end

function Teleports.hasArchJournal()
    return Inventory:Contains(DATA.ARCH_JOURNAL_ID) or hasItemInEquipment(DATA.ARCH_JOURNAL_ID, 18)
end

function Teleports.hasRingOfKinship()
    return Inventory:Contains(DATA.RING_OF_KINSHIP_ID) or hasItemInEquipment(DATA.RING_OF_KINSHIP_ID, 13)
end

function Teleports.ringOfKinship()
    local inInventory = Inventory:Contains(DATA.RING_OF_KINSHIP_ID)
    local equipped = hasItemInEquipment(DATA.RING_OF_KINSHIP_ID, 13)

    if not inInventory and not equipped then
        API.logWarn("No Ring of Kinship found in inventory or equipped")
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    if equipped then
        API.logInfo("Using equipped Ring of Kinship to teleport to Daemonheim...")
        API.DoAction_Interface(0xffffffff, DATA.RING_OF_KINSHIP_ID, 3, 1464, 15, 12, API.OFF_ACT_GeneralInterface_route)
    else
        API.logInfo("Using Ring of Kinship from inventory to teleport to Daemonheim...")
        API.DoAction_Inventory1(DATA.RING_OF_KINSHIP_ID, 0, 3, API.OFF_ACT_GeneralInterface_route)
    end

    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() > 0 end, 10, 100, "Teleport animation did not start")
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Teleport animation did not finish")
    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local dist = Utils.getDistance(coord.x, coord.y, 3449, 3696)
        return dist <= 10
    end, 15, 100, "Failed to teleport to Daemonheim") then
        return false
    end
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() > 0 end, 10, 100, "Second teleport animation did not start")
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Second teleport animation did not finish")
    API.logInfo("Teleport complete")
    API.RandomSleep2(600, 300, 50)
    return true
end

function Teleports.archJournal()
    local inInventory = Inventory:Contains(DATA.ARCH_JOURNAL_ID)
    local equipped = hasItemInEquipment(DATA.ARCH_JOURNAL_ID, 18)

    if not inInventory and not equipped then
        API.logWarn("No archaeology journal found in inventory or equipped")
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    if equipped then
        API.logInfo("Using equipped archaeology journal to teleport...")
        API.DoAction_Interface(0xffffffff, DATA.ARCH_JOURNAL_ID, 2, 1464, 15, 17, API.OFF_ACT_GeneralInterface_route)
    else
        local journal = Inventory:GetItem(DATA.ARCH_JOURNAL_ID)
        local slot = journal[1].slot
        API.logInfo("Using archaeology journal (inventory slot " .. slot .. ") to teleport...")
        API.DoAction_Inventory1(DATA.ARCH_JOURNAL_ID, 0, 7, API.OFF_ACT_GeneralInterface_route2)
    end

    API.RandomSleep2(600, 300, 300)
    return Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local dist = Utils.getDistance(coord.x, coord.y, 3336, 3378)
        return dist <= 10 and API.ReadPlayerAnim() == 0
    end, 15, 100, "Failed to teleport to Archaeology Campus")
end

local function findMemoryStrandSlot()
    for _, slot in ipairs(DATA.MEMORY_STRAND_SLOTS) do
        if API.GetVarbitValue(slot.varbit) == 55 then
            return slot
        end
    end
    return nil
end

function Teleports.memoryStrand()
    local slot = findMemoryStrandSlot()
    if not slot then
        API.logError("No memory strands favorited - terminating")
        API.Write_LoopyLoop(false)
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Using memory strand to teleport to Memorial to Guthix...")
    API.DoAction_Interface(0x24, DATA.MEMORY_STRAND_ID, 1, 1473, 20, slot.interfaceSlot, API.OFF_ACT_GeneralInterface_route)

    API.RandomSleep2(600, 300, 300)
    return Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local dist = Utils.getDistance(coord.x, coord.y, 2292, 3553)
        return dist <= 10 and API.ReadPlayerAnim() == 0
    end, 15, 100, "Failed to teleport to Memorial to Guthix")
end

local GOTE_ID = 44550

function Teleports.hasGraceOfTheElves()
    return hasItemInEquipment(GOTE_ID, 3)
end

function Teleports.deepSeaFishingHub()
    if not hasItemInEquipment(GOTE_ID, 3) then
        API.logError("Grace of the Elves necklace not equipped")
        API.Write_LoopyLoop(false)
        return false
    end

    local portal2 = API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_2)
    local portal1 = API.GetVarbitValue(DATA.VARBIT_IDS.GOTE_PORTAL_1)

    local action
    if portal2 == 16 then
        action = 3
    elseif portal1 == 16 then
        action = 2
    else
        API.logError("Deep Sea Fishing Hub is not set as a Grace of the Elves portal destination. Please configure it via the necklace.")
        API.Write_LoopyLoop(false)
        return false
    end

    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Teleporting to Deep Sea Fishing Hub...")
    API.DoAction_Interface(0xffffffff, GOTE_ID, action, 1464, 15, 2, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 8941
    end, 15, 100, "Failed to start Deep Sea Fishing Hub teleport") then
        return false
    end

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return API.ReadPlayerAnim() == 0 and coord.x == 2135 and coord.y == 7107
    end, 15, 100, "Failed to arrive at Deep Sea Fishing Hub") then
        return false
    end

    API.logInfo("Deep Sea Fishing Hub teleport complete")
    return true
end

function Teleports.maxGuild()
    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Teleporting to Max Guild...")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1461, 1, 199, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 8941
    end, 15, 100, "Failed to start Max Guild teleport") then
        return false
    end

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 0
    end, 15, 100, "Max Guild teleport animation did not finish") then
        return false
    end

    local coord = API.PlayerCoord()
    if coord.x ~= 2276 or coord.y ~= 3313 then
        API.logError("Max Guild teleport landed at wrong location (" .. coord.x .. ", " .. coord.y .. "). Talk to Elen Anterth in the Max Guild to change your teleport location to be inside the tower.")
        API.Write_LoopyLoop(false)
        return false
    end

    API.logInfo("Max Guild teleport complete")
    return true
end

function Teleports.warsRetreat()
    if API.ReadPlayerAnim() ~= 0 then
        API.logInfo("Waiting for current action to finish...")
        if not Utils.waitOrTerminate(function()
            return API.ReadPlayerAnim() == 0
        end, 10, 100, "Timed out waiting for action to finish") then
            return false
        end
    end

    API.logInfo("Teleporting to War's Retreat...")
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1461, 1, 205, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 8941
    end, 15, 100, "Failed to start War's Retreat teleport") then
        return false
    end

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return API.ReadPlayerAnim() == 0 and coord.x == 3294 and coord.y == 10127
    end, 15, 100, "Failed to arrive at War's Retreat") then
        return false
    end

    API.logInfo("War's Retreat teleport complete")
    return true
end

return Teleports
