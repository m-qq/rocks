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
        routeOptions = {
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 153, z = 12185} }, route = Routes.TO_FALADOR_EAST_BANK_FROM_DM_COAL },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_FALADOR_EAST_BANK_FROM_DM },
            { route = Routes.TO_FALADOR_EAST_BANK }
        },
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
        routeOptions = {
            { condition = { slayerCape = true }, route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT_VIA_SLAYER_CAPE },
            { route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT }
        },
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
            { condition = { fromLocation = {"mining_guild_resource_dungeon"}, region = {x = 16, y = 70, z = 4166} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MGRD },
            { condition = { fromLocation = {"mining_guild"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MG },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 153, z = 12185} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_DM_COAL },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_FURNACE_FROM_DM },
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
            { condition = { fromLocation = {"mining_guild_resource_dungeon"}, region = {x = 16, y = 70, z = 4166} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_MGRD },
            { condition = { fromLocation = {"mining_guild"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_MG },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 153, z = 12185} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_DM_COAL },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_ARTISANS_GUILD_BANK_FROM_DM },
            { route = Routes.TO_ARTISANS_GUILD_BANK }
        },
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    prifddinas = {
        name = "Prifddinas",
        skip_if = { nearCoord = {x = 2208, y = 3360} },
        route = Routes.TO_PRIFDDINAS_BANK,
        bank = {
            npc = "Banker",
            action = "Bank"
        }
    },
    deep_sea_fishing_hub = {
        name = "Deep Sea Fishing Hub",
        skip_if = { nearCoord = {x = 2135, y = 7107} },
        route = Routes.TO_DEEP_SEA_FISHING_HUB_BANK,
        bank = {
            object = "Rowboat",
            action = "Bank"
        }
    },
    burthorpe = {
        name = "Burthorpe",
        skip_if = { nearCoord = {x = 2888, y = 3536} },
        route = Routes.TO_BURTHORPE_BANK,
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
    },
    lumbridge_furnace = {
        name = "Lumbridge Furnace",
        skip_if = { nearCoord = {x = 3227, y = 3254} },
        route = Routes.TO_LUMBRIDGE_FURNACE,
        metalBank = {
            object = "Furnace",
            action = "Deposit-all (into metal bank)"
        }
    },
    lumbridge_market = {
        name = "Lumbridge Market",
        skip_if = { nearCoord = {x = 3213, y = 3257} },
        route = Routes.TO_LUMBRIDGE_MARKET_BANK,
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    },
    max_guild = {
        name = "Max Guild",
        skip_if = { nearCoord = {x = 2276, y = 3313} },
        route = Routes.TO_MAX_GUILD_BANK,
        bank = {
            npc = "Banker",
            action = "Bank"
        }
    },
    wars_retreat = {
        name = "War's Retreat",
        skip_if = { nearCoord = {x = 3294, y = 10127} },
        route = Routes.TO_WARS_RETREAT_BANK,
        bank = {
            object = "Bank chest",
            action = "Use"
        }
    }
}

local function depositItem(itemId, itemName)
    local count = Inventory:GetItemAmount(itemId)
    if count == 0 then return true end

    local action = count > 1 and 7 or 1
    API.printlua("Depositing " .. itemName .. " (count: " .. count .. ", action: " .. action .. ")", 0, false)
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
        API.printlua("No bank config defined for location", 4, false)
        return false
    end

    API.printlua("Opening bank...", 5, false)
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
        API.RandomSleep2(600, 600, 300)
        return true
    end

    if isBankPinOpen() then
        if not bankPin or bankPin == "" then
            API.printlua("Bank PIN required but not configured", 4, false)
            API.Write_LoopyLoop(false)
            return false
        end

        API.printlua("Entering bank PIN...", 0, false)
        API.DoBankPin(tonumber(bankPin))

        if not Utils.waitOrTerminate(function()
            return API.BankOpen2()
        end, 10, 100, "Failed to open bank after entering PIN") then
            return false
        end
        API.RandomSleep2(600, 600, 300)
        return true
    end

    return false
end

function Banking.depositAllItems(oreBoxId, oreConfig, gemBagId)
    local keepItems = {
        [DATA.ARCH_JOURNAL_ID] = true,
        [DATA.RING_OF_KINSHIP_ID] = true,
        [39018] = true  -- Senntisten scroll (unbankable)
    }
    for _, id in ipairs(DATA.SLAYER_CAPE_IDS) do
        keepItems[id] = true
    end
    for _, id in ipairs(DATA.DUNGEONEERING_CAPE_IDS) do
        keepItems[id] = true
    end
    if oreBoxId then
        keepItems[oreBoxId] = true
    end
    if gemBagId then
        keepItems[gemBagId] = true
    end

    if oreBoxId and oreConfig then
        local currentCount = OreBox.getOreCount(oreConfig)
        if currentCount > 0 then
            API.printlua("Depositing ore box contents...", 5, false)
            API.DoAction_Bank_Inv(oreBoxId, 8, API.OFF_ACT_GeneralInterface_route2)
            if not Utils.waitOrTerminate(function()
                return OreBox.getOreCount(oreConfig) == 0
            end, 10, 100, "Failed to deposit ore box contents") then
                return false
            end
        end
    end

    if gemBagId then
        local gemTotal = Utils.getGemBagTotal(gemBagId)
        if gemTotal > 0 then
            API.printlua("Depositing gem bag contents...", 5, false)
            API.DoAction_Bank_Inv(gemBagId, 8, API.OFF_ACT_GeneralInterface_route2)
            if not Utils.waitOrTerminate(function()
                return Utils.getGemBagTotal(gemBagId) == 0
            end, 10, 100, "Failed to deposit gem bag contents") then
                return false
            end
        end
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
        API.printlua("No metal bank config provided", 4, false)
        return false
    end

    local initialOreBoxCount = oreBoxId and OreBox.getOreCount(oreConfig) or 0
    local initialInventoryCount = 0
    if oreConfig and oreConfig.oreIds then
        for _, id in ipairs(oreConfig.oreIds) do
            initialInventoryCount = initialInventoryCount + Inventory:GetItemAmount(id)
        end
    end

    if initialOreBoxCount == 0 and initialInventoryCount == 0 then
        API.printlua("No ores to deposit to metal bank", 0, false)
        return true
    end

    API.printlua("Depositing to metal bank...", 5, false)
    Interact:Object(metalBankConfig.object, metalBankConfig.action, metalBankConfig.range or 40)

    return Utils.waitOrTerminate(function()
        local oreBoxCount = oreBoxId and OreBox.getOreCount(oreConfig) or 0
        local inventoryCount = 0
        if oreConfig and oreConfig.oreIds then
            for _, id in ipairs(oreConfig.oreIds) do
                inventoryCount = inventoryCount + Inventory:GetItemAmount(id)
            end
        end
        return oreBoxCount == 0 and inventoryCount == 0
    end, 10, 100, "Failed to deposit to metal bank")
end

function Banking.performBanking(bankLocation, miningLocation, oreBoxId, oreConfig, bankPin, selectedOre, miningLocationKey, gemBagId)
    if not bankLocation then
        API.printlua("No banking location provided", 4, false)
        return false
    end

    if not Routes.travelTo(bankLocation, nil, miningLocationKey) then
        return false
    end

    if bankLocation.metalBank then
        if not Banking.depositToMetalBank(bankLocation.metalBank, oreBoxId, oreConfig) then
            API.printlua("Failed to deposit to metal bank", 4, false)
            return false
        end
    else
        if not Banking.openBank(bankLocation, bankPin) then
            API.printlua("Failed to open bank", 4, false)
            return false
        end

        if not Banking.depositAllItems(oreBoxId, oreConfig, gemBagId) then
            API.printlua("Failed to deposit items", 4, false)
            return false
        end
    end

    API.printlua("Banking complete", 5, false)

    if miningLocation then
        API.RandomSleep2(600, 300, 300)
        if not Routes.travelTo(miningLocation, selectedOre) then
            API.printlua("Failed to return to mining area", 4, false)
            return false
        end

        if miningLocation.oreWaypoints and miningLocation.oreWaypoints[selectedOre] then
            if not Utils.walkThroughWaypoints(miningLocation.oreWaypoints[selectedOre]) then
                API.printlua("Failed to walk through ore waypoints", 4, false)
                return false
            end
            if not Utils.ensureAtOreLocation(miningLocation, selectedOre) then
                API.printlua("Failed to reach ore location after banking", 4, false)
                return false
            end
        end
    end

    return true
end

return Banking
