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
    return Utils.isWithinDistance(playerLoc.x, playerLoc.y, lode.loc.x, lode.loc.y, 20)
end

local function isLodestoneUnlocked(lode)
    if not lode.varbit then return true end
    return API.GetVarbitValue(lode.varbit) == 1
end

local function isLodestoneNetworkOpen()
    return Utils.checkInterfaceText(DATA.INTERFACES.LODESTONE_NETWORK, "Lodestone Network")
end

local function openLodestoneNetwork()
    API.printlua("Opening lodestone network...", 5, false)
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
    API.printlua("Selecting " .. lode.name .. " lodestone...", 0, false)
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, lode.interfaceId, -1, API.OFF_ACT_GeneralInterface_route)
    return true
end

function Teleports.isLodestoneUnlocked(lode)
    return isLodestoneUnlocked(lode)
end

function Teleports.isLodestoneAvailable(lode)
    return API.isAbilityAvailable(lode.name .. " Lodestone")
end

local function waitReadyToTeleport()
    if API.LocalPlayer_IsInCombat_() or API.ReadPlayerAnim() ~= 0 then
        API.printlua("Waiting to be ready to teleport...", 0, false)
        if not Utils.waitOrTerminate(function()
            return not API.LocalPlayer_IsInCombat_() and API.ReadPlayerAnim() == 0
        end, 10, 100, "Not ready to teleport - in combat or animating") then
            return false
        end
    end
    return true
end

function Teleports.lodestone(lode)
    if isAtLodestone(lode) then
        API.printlua("Already at " .. lode.name .. " lodestone", 0, false)
        return true
    end

    if not isLodestoneUnlocked(lode) then
        API.printlua(lode.name .. " lodestone is not unlocked", 4, false)
        API.Write_LoopyLoop(false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    API.printlua("Teleporting to " .. lode.name .. " lodestone...", 5, false)

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
        API.printlua("Using lodestone network interface...", 0, false)
        if not teleportViaNetwork(lode) then
            return false
        end
        if not API.CheckAnim(200) then
            API.printlua("Failed to start teleport animation", 4, false)
            return false
        end
    end

    API.printlua("Waiting for teleport animation...", 0, false)
    if not Utils.waitOrTerminate(function()
        return isAtLodestone(lode)
    end, 20, 100, "Failed to teleport to " .. lode.name .. " lodestone") then
        return false
    end
    Utils.waitForAnimCycle("Teleport")
    API.printlua("Teleport complete", 0, false)
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

local function hasCape(capeIds)
    if Teleports.getEquippedCape(capeIds) then return true end
    for _, id in ipairs(capeIds) do
        if Inventory:Contains(id) then return true end
    end
    return false
end

function Teleports.hasSlayerCape()
    return hasCape(DATA.SLAYER_CAPE_IDS)
end

function Teleports.hasDungeoneeringCape()
    return hasCape(DATA.DUNGEONEERING_CAPE_IDS)
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

local function capeTeleport(config)
    local dest = config.destinations[config.destinationKey]
    if not dest then
        API.printlua("Unknown " .. config.capeName .. " destination: " .. tostring(config.destinationKey), 4, false)
        return false
    end

    local capeId = Teleports.getEquippedCape(config.capeIds)
    local inventorySlot = nil
    if not capeId then
        for _, id in ipairs(config.capeIds) do
            if Inventory:Contains(id) then
                local item = Inventory:GetItem(id)
                capeId = id
                inventorySlot = item[1].slot
                break
            end
        end
    end

    if not capeId then
        API.printlua("No " .. config.capeName .. " found", 4, false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    API.printlua("Using " .. config.capeName .. " to teleport to " .. dest.name .. "...", 0, false)
    if inventorySlot then
        local params = config.capeActions[capeId]
        API.DoAction_Interface(0x24, capeId, params.action, 1473, 5, inventorySlot, params.route)
    else
        API.DoAction_Interface(0xffffffff, capeId, 3, 1464, 15, 1, API.OFF_ACT_GeneralInterface_route)
    end

    if not Utils.waitOrTerminate(function()
        return Utils.checkInterfaceText(config.menuInterface, config.menuText)
    end, 10, 100, config.capeName .. " teleport interface did not open") then
        return false
    end

    if dest.pageKey then
        API.printlua("Navigating to next page...", 0, false)
        API.KeyboardPress33(dest.pageKey, 0, 100, 50)
    end

    if not Utils.waitOrTerminate(function()
        return Utils.checkInterfaceText(dest.interface, dest.name)
    end, 10, 100, dest.name .. " option not found") then
        local result = API.ScanForInterfaceTest2Get(false, dest.interface)
        if #result > 0 then
            API.printlua("Found instead: " .. tostring(result[1].textids), 4, false)
        else
            API.printlua("No interface results found", 4, false)
        end
        return false
    end

    API.printlua("Selecting " .. dest.name .. "...", 0, false)
    API.KeyboardPress33(dest.selectKey, 0, 100, 50)

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return API.ReadPlayerAnim() == 8941 and Utils.isWithinDistance(coord.x, coord.y, dest.coord.x, dest.coord.y, 15)
    end, 15, 100, "Failed to teleport to " .. dest.name) then
        return false
    end
    Utils.waitOrTerminate(function() return API.ReadPlayerAnim() == 0 end, 10, 100, "Teleport animation did not finish")
    API.printlua(config.capeName .. " teleport complete", 0, false)
    return true
end

function Teleports.slayerCape(destinationKey)
    return capeTeleport({
        destinationKey = destinationKey,
        destinations = Teleports.SLAYER_DESTINATIONS,
        capeIds = DATA.SLAYER_CAPE_IDS,
        capeActions = SLAYER_CAPE_ACTIONS,
        capeName = "Slayer cape",
        menuInterface = DATA.INTERFACES.SLAYER_MASTER_TELEPORT,
        menuText = "Choose a slayer master"
    })
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
    return capeTeleport({
        destinationKey = destinationKey,
        destinations = Teleports.DUNGEONEERING_DESTINATIONS,
        capeIds = DATA.DUNGEONEERING_CAPE_IDS,
        capeActions = DUNGEONEERING_CAPE_ACTIONS,
        capeName = "Dungeoneering cape",
        menuInterface = DATA.INTERFACES.DUNGEONEERING_CAPE_TELEPORT,
        menuText = "Where would you like to teleport to?"
    })
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
        API.printlua("No Ring of Kinship found in inventory or equipped", 4, false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    if equipped then
        API.printlua("Using equipped Ring of Kinship to teleport to Daemonheim...", 5, false)
        API.DoAction_Interface(0xffffffff, DATA.RING_OF_KINSHIP_ID, 3, 1464, 15, 12, API.OFF_ACT_GeneralInterface_route)
    else
        API.printlua("Using Ring of Kinship from inventory to teleport to Daemonheim...", 5, false)
        API.DoAction_Inventory1(DATA.RING_OF_KINSHIP_ID, 0, 3, API.OFF_ACT_GeneralInterface_route)
    end

    Utils.waitForAnimCycle("Teleport")
    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return Utils.isWithinDistance(coord.x, coord.y, 3449, 3696, 10)
    end, 15, 100, "Failed to teleport to Daemonheim") then
        return false
    end
    Utils.waitForAnimCycle("Second teleport")
    API.printlua("Teleport complete", 0, false)
    API.RandomSleep2(600, 300, 50)
    return true
end

function Teleports.archJournal()
    local inInventory = Inventory:Contains(DATA.ARCH_JOURNAL_ID)
    local equipped = hasItemInEquipment(DATA.ARCH_JOURNAL_ID, 18)

    if not inInventory and not equipped then
        API.printlua("No archaeology journal found in inventory or equipped", 4, false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    if equipped then
        API.printlua("Using equipped archaeology journal to teleport...", 5, false)
        API.DoAction_Interface(0xffffffff, DATA.ARCH_JOURNAL_ID, 2, 1464, 15, 17, API.OFF_ACT_GeneralInterface_route)
    else
        if not Inventory:Contains(DATA.ARCH_JOURNAL_ID) then
            API.printlua("Archaeology journal not found in inventory", 4, false)
            return false
        end
        API.printlua("Using archaeology journal to teleport...", 0, false)
        API.DoAction_Inventory1(DATA.ARCH_JOURNAL_ID, 0, 7, API.OFF_ACT_GeneralInterface_route2)
    end

    API.RandomSleep2(600, 300, 300)
    return Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return Utils.isWithinDistance(coord.x, coord.y, 3336, 3378, 10) and API.ReadPlayerAnim() == 0
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

function Teleports.hasMemoryStrandFavorited()
    return findMemoryStrandSlot() ~= nil
end

function Teleports.memoryStrand()
    local slot = findMemoryStrandSlot()
    if not slot then
        API.printlua("No memory strands favorited - terminating", 4, false)
        API.Write_LoopyLoop(false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    API.printlua("Using memory strand to teleport to Memorial to Guthix...", 5, false)
    API.DoAction_Interface(0x24, DATA.MEMORY_STRAND_ID, 1, 1473, 20, slot.interfaceSlot, API.OFF_ACT_GeneralInterface_route)

    API.RandomSleep2(600, 300, 300)
    return Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return Utils.isWithinDistance(coord.x, coord.y, 2292, 3553, 10) and API.ReadPlayerAnim() == 0
    end, 15, 100, "Failed to teleport to Memorial to Guthix")
end

local GOTE_ID = 44550

function Teleports.hasGraceOfTheElves()
    return hasItemInEquipment(GOTE_ID, 3)
end

function Teleports.deepSeaFishingHub()
    if not hasItemInEquipment(GOTE_ID, 3) then
        API.printlua("Grace of the Elves necklace not equipped", 4, false)
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
        API.printlua("Deep Sea Fishing Hub is not set as a Grace of the Elves portal destination. Please configure it via the necklace.", 4, false)
        API.Write_LoopyLoop(false)
        return false
    end

    if not waitReadyToTeleport() then return false end

    API.printlua("Teleporting to Deep Sea Fishing Hub...", 5, false)
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

    API.printlua("Deep Sea Fishing Hub teleport complete", 0, false)
    return true
end

function Teleports.maxGuild()
    if not waitReadyToTeleport() then return false end

    API.printlua("Teleporting to Max Guild...", 5, false)
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
        API.printlua("Max Guild teleport landed at wrong location (" .. coord.x .. ", " .. coord.y .. "). Talk to Elen Anterth in the Max Guild to change your teleport location to be inside the tower.", 4, false)
        API.Write_LoopyLoop(false)
        return false
    end

    API.printlua("Max Guild teleport complete", 0, false)
    return true
end

function Teleports.warsRetreat()
    if not waitReadyToTeleport() then return false end

    API.printlua("Teleporting to War's Retreat...", 5, false)
    API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1461, 1, 205, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        local anim = API.ReadPlayerAnim()
        return anim == 8941 or (anim == 0 and coord.x == 3294 and coord.y == 10127)
    end, 15, 100, "Failed to start War's Retreat teleport") then
        return false
    end

    if not Utils.waitOrTerminate(function()
        local coord = API.PlayerCoord()
        return API.ReadPlayerAnim() == 0 and coord.x == 3294 and coord.y == 10127
    end, 15, 100, "Failed to arrive at War's Retreat") then
        return false
    end

    API.printlua("War's Retreat teleport complete", 0, false)
    return true
end

local RL = DATA.RESOURCE_LOCATOR
local containerCheckBuf = Utils.containerCheckBuf

local function isLocatorWindowOpen()
    return Utils.checkInterfaceText(RL.INTERFACES.LOCATOR_WINDOW, "Resource Locator")
end

local function isWarningOpen()
    return Utils.checkInterfaceText(RL.INTERFACES.WARNING, "Warning! There is a chance that the area may be dangerous.")
end

local function isConfirmDontAskOpen()
    return Utils.checkInterfaceText(RL.INTERFACES.CONFIRM_DONT_ASK, "Yes and don't ask me again")
end

local function isConfirmTravelOpen()
    return Utils.checkInterfaceText(RL.INTERFACES.CONFIRM_TRAVEL, "Travel anyway")
end

-- Find lowest-tier locator supporting ore. Checks equipped (94) then inventory (93).
function Teleports.scanForLocator(targetOre)
    for _, locator in ipairs(RL.LOCATORS) do
        if not targetOre or locator.ores[targetOre] then
            containerCheckBuf[1] = locator.id
            if API.Container_Check_Items(94, containerCheckBuf) then
                return locator, true, nil
            end
            if API.Container_Check_Items(93, containerCheckBuf) then
                local item = Inventory:GetItem(locator.id)
                local slot = item and item[1] and item[1].slot
                return locator, false, slot
            end
        end
    end
    return nil, false, nil
end

function Teleports.getLocatorCharges(locator, isEquipped)
    local containerId = isEquipped and 94 or 93
    local item = API.Container_Get_s(containerId, locator.id)
    if item and item.Extra_ints and item.Extra_ints[2] then
        return RL.MAX_CHARGES - (item.Extra_ints[2] / 2)
    end
    return RL.MAX_CHARGES
end

-- Has a locator for this ore with charges > 0. Used by route conditions.
function Teleports.hasResourceLocator(targetOre)
    local locator, isEquipped = Teleports.scanForLocator(targetOre)
    if not locator then return false end
    return Teleports.getLocatorCharges(locator, isEquipped) > 0
end

local function doSingleLocatorTeleport(oreKey, locator, isEquipped)
    if not waitReadyToTeleport() then return false end

    API.printlua("Activating " .. locator.name .. "...", 0, false)
    if isEquipped then
        API.DoAction_Interface(0xffffffff, locator.id, 2, 1464, 15, RL.EQUIPMENT_SLOT, API.OFF_ACT_GeneralInterface_route)
    else
        API.DoAction_Inventory1(locator.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
    end

    if not Utils.waitOrTerminate(isLocatorWindowOpen, 10, 100, "Locator window did not open") then
        return false
    end
    API.RandomSleep2(300, 150, 100)

    local dest = RL.DESTINATIONS[oreKey]
    API.DoAction_Interface(dest.a, dest.b, dest.c, dest.d, dest.e, dest.f, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return isWarningOpen() or isConfirmDontAskOpen() or isConfirmTravelOpen()
            or API.ReadPlayerAnim() == RL.TELEPORT_ANIM
    end, 10, 100, "No dialog or teleport detected after ore selection") then
        return false
    end

    if API.ReadPlayerAnim() ~= RL.TELEPORT_ANIM then
        if isWarningOpen() then
            API.KeyboardPress2(0x20, 60, 100)
            API.RandomSleep2(600, 300, 300)
            if not Utils.waitOrTerminate(function()
                return isConfirmDontAskOpen() or isConfirmTravelOpen()
                    or API.ReadPlayerAnim() == RL.TELEPORT_ANIM
            end, 10, 100, "No confirmation after warning") then
                return false
            end
        end

        if API.ReadPlayerAnim() ~= RL.TELEPORT_ANIM then
            if isConfirmDontAskOpen() then
                API.KeyboardPress2(0x33, 60, 100)
            elseif isConfirmTravelOpen() then
                API.KeyboardPress2(0x31, 60, 100)
            end
        end
    end

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == RL.TELEPORT_ANIM
    end, 15, 100, "Locator teleport animation did not start") then
        return false
    end

    if not Utils.waitOrTerminate(function()
        return API.ReadPlayerAnim() == 0 and not API.ReadPlayerMovin2()
    end, 15, 100, "Locator teleport animation did not finish") then
        return false
    end

    return true
end

-- Returns (success, needsRecharge). If expectedCoord is nil, accepts any landing.
function Teleports.resourceLocator(oreKey, expectedCoord)
    local locator, isEquipped = Teleports.scanForLocator(oreKey)
    if not locator then
        API.printlua("No resource locator found for " .. oreKey, 4, false)
        return false, false
    end

    local charges = Teleports.getLocatorCharges(locator, isEquipped)
    local maxAttempts = expectedCoord and math.floor(charges) or 1

    if maxAttempts <= 0 then
        API.printlua("Resource locator out of charges", 0, false)
        return false, true
    end

    for attempt = 1, maxAttempts do
        local currentCharges = Teleports.getLocatorCharges(locator, isEquipped)
        if currentCharges <= 0 then
            return false, true
        end

        API.printlua("Locator teleport to " .. oreKey .. " (" .. attempt .. "/" .. maxAttempts .. ", " .. math.floor(currentCharges) .. " charges)", 0, false)

        if not doSingleLocatorTeleport(oreKey, locator, isEquipped) then
            return false, false
        end

        local coord = API.PlayerCoord()
        local landedUnsafe = false

        if oreKey == "adamantite" then
            if Utils.isWithinDistance(coord.x, coord.y, 3321, 2872, RL.MAX_DISTANCE)
                and not Quest:Get(391):isComplete() then
                API.printlua("Landed at Agility Pyramid but Crocodile Tears quest incomplete, retrying...", 0, false)
                landedUnsafe = true
            end
        end

        if oreKey == "runite" then
            if Utils.isWithinDistance(coord.x, coord.y, 2860, 9578, RL.MAX_DISTANCE) then
                local combatLevel = Utils.getCombatLevel()
                if combatLevel < 31 then
                    API.printlua("Landed at Karamja Volcano but combat level " .. combatLevel .. " < 31, retrying...", 0, false)
                    landedUnsafe = true
                end
            end
        end

        if not expectedCoord and not landedUnsafe then
            return true, false
        end

        if not landedUnsafe and expectedCoord then
            local dist = Utils.getDistance(coord.x, coord.y, expectedCoord.x, expectedCoord.y)
            if dist <= RL.MAX_DISTANCE then
                API.printlua("Arrived at expected location (dist: " .. math.floor(dist) .. ")", 0, false)
                return true, false
            end
            API.printlua("Wrong location (dist: " .. math.floor(dist) .. "), retrying...", 0, false)
        end
    end

    return false, true
end

-- Route system wrapper. config = { ore = "silver", coord = { x, y } }
-- Handles recharging when charges run out during teleport attempts.
function Teleports.resourceLocatorRoute(config)
    local maxRechargeAttempts = 5

    for attempt = 1, maxRechargeAttempts do
        local success, needsRecharge = Teleports.resourceLocator(config.ore, config.coord)

        if success then
            return true
        end

        if not needsRecharge then
            -- Failed for reason other than charges (teleport didn't work)
            return false
        end

        -- Out of charges - try to recharge
        local locator, isEquipped = Teleports.scanForLocator(config.ore)
        if not locator then
            return false
        end

        local energyInInventory = Inventory:GetItemAmount(locator.energyId)
        if energyInInventory < locator.energyPerCharge then
            -- Not enough energy for even 1 charge - let travelTo handle fallback
            API.printlua("Locator out of charges, insufficient energy to recharge (" .. energyInInventory .. "/" .. locator.energyPerCharge .. " needed)", 0, false)
            return false
        end

        API.printlua("Recharging locator (attempt " .. attempt .. "/" .. maxRechargeAttempts .. ")...", 0, false)
        local recharged = Utils.doRechargeDialog(locator, isEquipped)
        if not recharged then
            API.printlua("Failed to recharge locator", 4, false)
            return false
        end

        API.RandomSleep2(300, 150, 100)
    end

    return false
end

return Teleports
