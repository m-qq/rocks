local API = require("api")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")

local Teleports = {}

Teleports.LODESTONES = {
    AL_KHARID = {loc = WPOINT.new(3297, 3184, 0), name = "Al Kharid", interfaceId = 11, varbit = 28},
    ANACHRONIA = {loc = WPOINT.new(5431, 2338, 0), name = "Anachronia", interfaceId = 25, varbit = 44270},
    ARDOUGNE = {loc = WPOINT.new(2634, 3348, 0), name = "Ardougne", interfaceId = 12, varbit = 29},
    ASHDALE = {loc = WPOINT.new(2474, 2708, 2), name = "Ashdale", interfaceId = 34, varbit = 22430},
    BANDIT_CAMP = {loc = WPOINT.new(2899, 3544, 0), name = "Bandit Camp", interfaceId = 9},
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

local function hasArchJournalInInventory()
    return Inventory:Contains(DATA.ARCH_JOURNAL_ID)
end

local function hasArchJournalEquipped()
    local container = API.Container_Get_all(94)
    return container and container[18] and container[18].item_id == DATA.ARCH_JOURNAL_ID
end

local function hasRingOfKinshipInInventory()
    return Inventory:Contains(DATA.RING_OF_KINSHIP_ID)
end

local function hasRingOfKinshipEquipped()
    local container = API.Container_Get_all(94)
    return container and container[13] and container[13].item_id == DATA.RING_OF_KINSHIP_ID
end

function Teleports.hasRingOfKinship()
    return hasRingOfKinshipInInventory() or hasRingOfKinshipEquipped()
end

function Teleports.ringOfKinship()
    local inInventory = hasRingOfKinshipInInventory()
    local equipped = hasRingOfKinshipEquipped()

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
    local inInventory = hasArchJournalInInventory()
    local equipped = hasArchJournalEquipped()

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

return Teleports
