local API = require("api")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")
local OreBox = require("aio mining/mining_orebox")
local Routes = require("aio mining/mining_routes")

local Banking = {}

local BANK_PIN_INTERFACE = { { 13,0,-1,0 }, { 13,25,-1,0 }, { 13,25,14,0 } }

Banking.LOCATIONS = {
    archaeology_campus = {
        name = "Archaeology Campus",
        skip_if = { nearCoord = {x = 3363, y = 3397} },
        route = Routes.TO_ARCHAEOLOGY_CAMPUS_BANK,
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    player_owned_farm = {
        name = "Player Owned Farm",
        skip_if = { nearCoord = {x = 2649, y = 3344} },
        route = Routes.TO_POF_BANK,
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    falador_west = {
        name = "Falador West",
        skip_if = { nearCoord = {x = 2947, y = 3367} },
        route = Routes.TO_FALADOR_WEST_BANK,
        bank = {
            object = "Bank booth",
            action = "Bank"
        }
    },
    falador_east = {
        name = "Falador East",
        skip_if = { nearCoord = {x = 3012, y = 3354} },
        route = Routes.TO_FALADOR_EAST_BANK,
        bank = {
            object = "Bank booth",
            action = "Bank"
        }
    },
    edgeville = {
        name = "Edgeville",
        skip_if = { nearCoord = {x = 3095, y = 3493} },
        route = Routes.TO_EDGEVILLE_BANK,
        bank = {
            object = "Counter",
            action = "Bank"
        }
    },
    memorial_to_guthix = {
        name = "Memorial to Guthix",
        skip_if = { nearCoord = {x = 2280, y = 3559} },
        route = Routes.TO_MEMORIAL_TO_GUTHIX_BANK,
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    wilderness_pirates_hideout_anvil = {
        name = "Wilderness Pirates Hideout Anvil",
        skip_if = { nearCoord = {x = 3064, y = 3951} },
        route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT,
        metalBank = {
            object = "Anvil",
            action = "Deposit-all (into metal bank)"
        }
    },
    fort_forinthry = {
        name = "Fort Forinthry",
        skip_if = { nearCoord = {x = 3303, y = 3544} },
        route = Routes.TO_FORT_FORINTHRY_BANK,
        bank = {
            npc = "Copperpot",
            action = "Bank"
        }
    },
    fort_forinthry_furnace = {
        name = "Fort Forinthry Furnace",
        skip_if = { nearCoord = {x = 3280, y = 3558} },
        route = Routes.TO_FORT_FORINTHRY_FURNACE,
        metalBank = {
            object = "Furnace",
            action = "Deposit-all (into metal bank)"
        }
    },
    artisans_guild_furnace = {
        name = "Artisans Guild Furnace",
        skip_if = { nearCoord = {x = 3043, y = 3340} },
        routeOptions = {
            { condition = { region = {x = 16, y = 70, z = 4166} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MGRD },
            { condition = { region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MG },
            { route = Routes.TO_ARTISANS_GUILD_FURNACE }
        },
        metalBank = {
            object = "Furnace",
            action = "Deposit-all (into metal bank)"
        }
    },
    artisans_guild_bank = {
        name = "Artisans Guild Bank",
        skip_if = { nearCoord = {x = 3061, y = 3340} },
        routeOptions = {
            { condition = { region = {x = 16, y = 70, z = 4166} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_MGRD },
            { condition = { region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_MG },
            { route = Routes.TO_ARTISANS_GUILD_BANK }
        },
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    daemonheim_banker = {
        name = "Daemonheim Banker",
        skip_if = { nearCoord = {x = 3448, y = 3719} },
        route = Routes.TO_DAEMONHEIM_BANK,
        bank = {
            npc = "Fremennik banker",
            action = "Bank"
        }
    }
}

local function depositItem(itemId, itemName)
    local count = Inventory:GetItemAmount(itemId)
    if count == 0 then return true end

    local action = count > 1 and 7 or 1
    API.logInfo("Depositing " .. itemName .. " (count: " .. count .. ", action: " .. action .. ")")
    API.DoAction_Bank_Inv(itemId, action, API.OFF_ACT_GeneralInterface_route2)
    return Utils.waitOrTerminate(function()
        return not Inventory:Contains(itemId)
    end, 10, 100, "Failed to deposit " .. itemName)
end

local function isBankPinOpen()
    local result = API.ScanForInterfaceTest2Get(false, BANK_PIN_INTERFACE)
    return #result > 0 and result[1].textids == "Bank of Gielinor"
end

function Banking.openBank(bankLocation, bankPin)
    if not bankLocation or not bankLocation.bank then
        API.logError("No bank config defined for location")
        return false
    end

    API.logInfo("Opening bank...")
    local bank = bankLocation.bank
    local range = bank.range or 40
    if bank.npc then
        Interact:NPC(bank.npc, bank.action, range)
    else
        Interact:Object(bank.object, bank.action, range)
    end

    if not Utils.waitOrTerminate(function()
        return API.BankOpen2() or isBankPinOpen()
    end, 10, 100, "Failed to open bank or PIN interface") then
        return false
    end

    if API.BankOpen2() then
        return true
    end

    if isBankPinOpen() then
        if not bankPin or bankPin == "" then
            API.logError("Bank PIN required but not configured")
            API.Write_LoopyLoop(false)
            return false
        end

        API.logInfo("Entering bank PIN...")
        API.DoBankPin(tonumber(bankPin))

        return Utils.waitOrTerminate(function()
            return API.BankOpen2()
        end, 10, 100, "Failed to open bank after entering PIN")
    end

    return false
end

function Banking.depositOreBox(oreBoxId, oreConfig)
    if not oreBoxId then return true end

    local currentCount = OreBox.getOreCount(oreConfig)
    if currentCount == 0 then return true end

    API.logInfo("Depositing ore box contents...")
    API.DoAction_Bank_Inv(oreBoxId, 8, API.OFF_ACT_GeneralInterface_route2)
    return Utils.waitOrTerminate(function()
        return OreBox.getOreCount(oreConfig) == 0
    end, 10, 100, "Failed to deposit ore box contents")
end

function Banking.depositGeodes()
    for _, geode in ipairs(DATA.GEODES) do
        if not depositItem(geode.id, geode.name) then
            return false
        end
    end
    return true
end

function Banking.depositOres(oreConfig)
    if not oreConfig then return true end
    return depositItem(oreConfig.oreId, oreConfig.name)
end

function Banking.depositUnknownItems(oreBoxId)
    local keepItems = {
        [DATA.ARCH_JOURNAL_ID] = true,
        [DATA.RING_OF_KINSHIP_ID] = true,
        [39018] = true  -- Senntisten scroll (unbankable)
    }
    if oreBoxId then
        keepItems[oreBoxId] = true
    end

    local inventory = Inventory:GetItems()

    for _, item in ipairs(inventory) do
        local itemId = item.id
        if itemId > 0 and not keepItems[itemId] then
            if not depositItem(itemId, item.name) then
                return false
            end
        end
    end

    return true
end

function Banking.depositToMetalBank(metalBankConfig, oreBoxId, oreConfig)
    if not metalBankConfig then
        API.logError("No metal bank config provided")
        return false
    end

    local initialOreBoxCount = oreBoxId and OreBox.getOreCount(oreConfig) or 0
    local initialInventoryCount = oreConfig and Inventory:GetItemAmount(oreConfig.oreId) or 0

    if initialOreBoxCount == 0 and initialInventoryCount == 0 then
        API.logInfo("No ores to deposit to metal bank")
        return true
    end

    API.logInfo("Depositing to metal bank...")
    Interact:Object(metalBankConfig.object, metalBankConfig.action, metalBankConfig.range or 40)

    return Utils.waitOrTerminate(function()
        local oreBoxCount = oreBoxId and OreBox.getOreCount(oreConfig) or 0
        local inventoryCount = oreConfig and Inventory:GetItemAmount(oreConfig.oreId) or 0
        return oreBoxCount == 0 and inventoryCount == 0
    end, 10, 100, "Failed to deposit to metal bank")
end

function Banking.performBanking(bankLocation, miningLocation, oreBoxId, oreConfig, bankPin)
    if not bankLocation then
        API.logError("No banking location provided")
        return false
    end

    if not Routes.travelTo(bankLocation) then
        return false
    end

    if bankLocation.metalBank then
        if not Banking.depositToMetalBank(bankLocation.metalBank, oreBoxId, oreConfig) then
            API.logWarn("Failed to deposit to metal bank")
            return false
        end
    else
        if not Banking.openBank(bankLocation, bankPin) then
            API.logWarn("Failed to open bank")
            return false
        end

        if not Banking.depositOreBox(oreBoxId, oreConfig) then
            API.logWarn("Failed to deposit ore box")
            return false
        end

        if not Banking.depositGeodes() then
            API.logWarn("Failed to deposit geodes")
            return false
        end

        if not Banking.depositOres(oreConfig) then
            API.logWarn("Failed to deposit ores")
            return false
        end

        if not Banking.depositUnknownItems(oreBoxId) then
            return false
        end
    end

    API.logInfo("Banking complete")

    if miningLocation then
        API.RandomSleep2(600, 300, 300)
        if not Routes.travelTo(miningLocation) then
            API.logWarn("Failed to return to mining area")
            return false
        end
    end

    return true
end

return Banking


