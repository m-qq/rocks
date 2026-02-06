local API = require("api")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")
local OreBox = require("aio mining/mining_orebox")
local Routes = require("aio mining/mining_routes")

local Banking = {}

Banking.fallbackBank = nil

function Banking.closeBank()
    if API.BankOpen2() then
        API.KeyboardPress2(0x1B, 60, 100)
        Utils.waitOrTerminate(function()
            return not API.Compare2874Status(24, false)
        end, 5, 100, "Bank did not close")
        API.RandomSleep2(600, 600, 300)
    end
end

local BANK_PIN_INTERFACE = { { 13,0,-1,0 }, { 13,25,-1,0 }, { 13,25,14,0 } }

local staticKeepItems = {
    [DATA.ARCH_JOURNAL_ID] = true,
    [DATA.RING_OF_KINSHIP_ID] = true,
    [DATA.SENNTISTEN_SCROLL_ID] = true
}
for _, id in ipairs(DATA.SLAYER_CAPE_IDS) do
    staticKeepItems[id] = true
end
for _, id in ipairs(DATA.DUNGEONEERING_CAPE_IDS) do
    staticKeepItems[id] = true
end
for id in pairs(DATA.ALL_JUJU_IDS) do
    staticKeepItems[id] = true
end
for id in pairs(DATA.ALL_SUMMONING_POUCH_IDS) do
    staticKeepItems[id] = true
end
for id in pairs(DATA.ALL_LOCATOR_IDS) do
    staticKeepItems[id] = true
end
for id in pairs(DATA.ALL_ENERGY_IDS) do
    staticKeepItems[id] = true
end

local containerCheckBuf = Utils.containerCheckBuf

local bankCache = {}
local bankCachePopulated = false
local notedModeDisabled = false

local function cacheBankItems(idSet)
    for id in pairs(idSet) do
        local bankItem = API.Container_Get_s(95, id)
        bankCache[id] = bankItem and bankItem.item_stack or 0
    end
end

local function populateBankCache()
    if bankCachePopulated then return end
    cacheBankItems(DATA.ALL_JUJU_IDS)
    cacheBankItems(DATA.ALL_SUMMONING_POUCH_IDS)
    bankCachePopulated = true
end

function Banking.resetCache()
    Utils.clearTable(bankCache)
    bankCachePopulated = false
end

local function bankCacheGet(itemId)
    return bankCache[itemId] or 0
end

local function bankCacheWithdraw(itemId, count)
    count = count or 1
    local current = bankCache[itemId] or 0
    bankCache[itemId] = math.max(0, current - count)
end

Banking.LOCATIONS = {
    archaeology_campus = {
        name = "Archaeology Campus",
        skip_if = { nearCoord = {x = 3363, y = 3397} },
        route = Routes.TO_ARCHAEOLOGY_CAMPUS_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    player_owned_farm = {
        name = "Player Owned Farm",
        skip_if = { nearCoord = {x = 2649, y = 3344} },
        route = Routes.TO_POF_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    falador_west = {
        name = "Falador West",
        skip_if = { nearCoord = {x = 2947, y = 3367} },
        route = Routes.TO_FALADOR_WEST_BANK,
        bank = { object = "Bank booth", action = "Bank" }
    },
    falador_east = {
        name = "Falador East",
        skip_if = { nearCoord = {x = 3012, y = 3354} },
        routeOptions = {
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 153, z = 12185} }, route = Routes.TO_FALADOR_EAST_BANK_FROM_DM_COAL },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_FALADOR_EAST_BANK_FROM_DM },
            { route = Routes.TO_FALADOR_EAST_BANK }
        },
        bank = { object = "Bank booth", action = "Bank" }
    },
    edgeville = {
        name = "Edgeville",
        skip_if = { nearCoord = {x = 3095, y = 3493} },
        route = Routes.TO_EDGEVILLE_BANK,
        bank = { object = "Counter", action = "Bank" }
    },
    memorial_to_guthix = {
        name = "Memorial to Guthix",
        skip_if = { nearCoord = {x = 2280, y = 3559} },
        route = Routes.TO_MEMORIAL_TO_GUTHIX_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    wilderness_pirates_hideout_anvil = {
        name = "Wilderness Pirates Hideout Anvil",
        skip_if = { nearCoord = {x = 3064, y = 3951} },
        routeOptions = {
            { condition = { slayerCape = true }, route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT_VIA_SLAYER_CAPE },
            { route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT }
        },
        metalBank = { object = "Anvil", action = "Deposit-all (into metal bank)" }
    },
    fort_forinthry = {
        name = "Fort Forinthry",
        skip_if = { nearCoord = {x = 3303, y = 3544} },
        route = Routes.TO_FORT_FORINTHRY_BANK,
        bank = { npc = "Copperpot", action = "Bank" }
    },
    fort_forinthry_furnace = {
        name = "Fort Forinthry Furnace",
        skip_if = { nearCoord = {x = 3280, y = 3558} },
        route = Routes.TO_FORT_FORINTHRY_FURNACE,
        metalBank = { object = "Furnace", action = "Deposit-all (into metal bank)" }
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
        metalBank = { object = "Furnace", action = "Deposit-all (into metal bank)" }
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
        bank = { object = "Bank chest", action = "Use" }
    },
    ithell = {
        name = "Ithell Bank Chest",
        skip_if = { nearCoord = {x = 2154, y = 3340} },
        route = Routes.TO_ITHELL_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    prifddinas = {
        name = "Prifddinas",
        skip_if = { nearCoord = {x = 2208, y = 3360} },
        route = Routes.TO_PRIFDDINAS_BANK,
        bank = { npc = "Banker", action = "Bank" }
    },
    deep_sea_fishing_hub = {
        name = "Deep Sea Fishing Hub",
        skip_if = { nearCoord = {x = 2135, y = 7107} },
        route = Routes.TO_DEEP_SEA_FISHING_HUB_BANK,
        bank = { object = "Rowboat", action = "Bank" }
    },
    burthorpe = {
        name = "Burthorpe",
        skip_if = { nearCoord = {x = 2888, y = 3536} },
        route = Routes.TO_BURTHORPE_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    daemonheim_banker = {
        name = "Daemonheim Banker",
        skip_if = { nearCoord = {x = 3448, y = 3719} },
        route = Routes.TO_DAEMONHEIM_BANK,
        bank = { npc = "Fremennik banker", action = "Bank" }
    },
    lumbridge_furnace = {
        name = "Lumbridge Furnace",
        skip_if = { nearCoord = {x = 3227, y = 3254} },
        route = Routes.TO_LUMBRIDGE_FURNACE,
        metalBank = { object = "Furnace", action = "Deposit-all (into metal bank)" }
    },
    lumbridge_market = {
        name = "Lumbridge Market",
        skip_if = { nearCoord = {x = 3213, y = 3257} },
        route = Routes.TO_LUMBRIDGE_MARKET_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    max_guild = {
        name = "Max Guild",
        skip_if = { nearCoord = {x = 2276, y = 3313} },
        route = Routes.TO_MAX_GUILD_BANK,
        bank = { npc = "Banker", action = "Bank" }
    },
    wars_retreat = {
        name = "War's Retreat",
        skip_if = { nearCoord = {x = 3294, y = 10127} },
        route = Routes.TO_WARS_RETREAT_BANK,
        bank = { object = "Bank chest", action = "Use" }
    },
    dwarven_resource_dungeon_deposit_box = {
        name = "Dwarven RD Deposit Box",
        levelReq = { skill = "DUNGEONEERING", level = 15 },
        skip_if = { nearCoord = {x = 1042, y = 4578, maxDistance = 10} },
        routeOptions = {
            { condition = { nearCoord = {x = 1063, y = 4574, maxDistance = 15} }, route = Routes.TO_DM_RD_DEPOSIT_BOX_FROM_GOLD },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 153, z = 12185} }, route = Routes.TO_DM_RD_DEPOSIT_BOX_FROM_DM_COAL },
            { condition = { fromLocation = {"dwarven_mine"}, region = {x = 47, y = 152, z = 12184} }, route = Routes.TO_DM_RD_DEPOSIT_BOX_FROM_DM },
            { route = Routes.TO_DWARVEN_RESOURCE_DUNGEON }
        },
        depositBox = { object = "Bank deposit box", action = "Deposit-All", id = 25937 }
    }
}

local function depositItem(itemId, itemName)
    local count = Inventory:GetItemAmount(itemId)
    if count == 0 then return true end

    local action
    if count == 1 then
        action = 2
    else
        local vb = API.GetVarbitValue(45189)
        action = vb == 7 and 1 or 7
    end
    API.printlua(string.format("Depositing %s (count: %d, action: %d)", itemName, count, action), 0, false)
    API.DoAction_Bank_Inv(itemId, action, API.OFF_ACT_GeneralInterface_route2)
    return Utils.waitOrTerminate(function()
        return not Inventory:Contains(itemId)
    end, 10, 100, string.format("Failed to deposit %s", itemName))
end

local function isBankPinOpen()
    return Utils.checkInterfaceText(BANK_PIN_INTERFACE, "Bank of Gielinor")
end

function Banking.openBank(bankLocation, bankPin)
    notedModeDisabled = false
    if not bankLocation or not bankLocation.bank then
        API.printlua("No bank config defined for location", 4, false)
        return false
    end

    API.printlua("Opening bank...", 5, false)
    local bank = bankLocation.bank
    local range = bank.range or 40

    local bankName = bank.npc or bank.object
    local searchTypes = bank.npc and {1} or {0, 12}
    if not Utils.waitOrTerminate(function()
        local results = API.ReadAllObjectsArray(searchTypes, {-1}, {bankName})
        return #results > 0
    end, 15, 100, "Bank object did not load: " .. bankName) then
        return false
    end

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
        populateBankCache()
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
        populateBankCache()
        return true
    end

    return false
end

function Banking.depositAllItems(oreBoxId, oreConfig, gemBagId)
    if oreBoxId and oreConfig then
        local currentCount = OreBox.getOreCount(oreConfig)
        if currentCount > 0 then
            API.printlua("Depositing ore box contents...", 0, false)
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
            API.printlua("Depositing gem bag contents...", 0, false)
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
        local keep = staticKeepItems[itemId] or itemId == oreBoxId or itemId == gemBagId
        if itemId > 0 and not keep then
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

function Banking.depositToDepositBox(depositBoxConfig)
    if not depositBoxConfig then
        API.printlua("No deposit box config provided", 4, false)
        return false
    end

    API.printlua("Depositing to deposit box...", 5, false)
    Interact:Object(depositBoxConfig.object, depositBoxConfig.action, 25)

    return Utils.waitOrTerminate(function()
        return Inventory:IsEmpty() or Inventory:FreeSpaces() >= 26
    end, 10, 100, "Failed to deposit to deposit box")
end

function Banking.findJujuInInventory(potionDef)
    for _, potion in ipairs(potionDef.potions) do
        containerCheckBuf[1] = potion.id
        if API.Container_Check_Items(93, containerCheckBuf) then
            return potion
        end
    end
    return nil
end

local function findBestJujuInBank(potionDef)
    for _, potion in ipairs(potionDef.potions) do
        if bankCacheGet(potion.id) > 0 then
            return potion
        end
    end
    return nil
end

local function disableNotedMode()
    if notedModeDisabled then return true end
    local vb = API.VB_FindPSettinOrder(160)
    if vb and vb.state == 1 then
        API.printlua("Disabling noted withdraw mode...", 0, false)
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 517, 127, -1, API.OFF_ACT_GeneralInterface_route)
        if not Utils.waitOrTerminate(function()
            local v = API.VB_FindPSettinOrder(160)
            return v and v.state == 0
        end, 5, 100, "Failed to disable noted mode") then
            return false
        end
    end
    notedModeDisabled = true
    return true
end

function Banking.withdrawJuju(potionDef)
    if not API.BankOpen2() then return false end

    if Banking.findJujuInInventory(potionDef) then return true end

    if not disableNotedMode() then return false end

    local potion = findBestJujuInBank(potionDef)
    if not potion then
        API.printlua("No juju potions found in bank", 4, false)
        return false
    end

    API.printlua("Withdrawing juju potion (dose " .. potion.dose .. ")...", 0, false)
    local withdrawAction = API.GetVarbitValue(45189) == 2 and 1 or 2
    API.DoAction_Bank(potion.id, withdrawAction, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return Banking.findJujuInInventory(potionDef) ~= nil
    end, 5, 100, "Failed to withdraw juju potion") then
        return false
    end

    bankCacheWithdraw(potion.id)
    return true
end

function Banking.findSummoningPouchInInventory(familiarDef)
    containerCheckBuf[1] = familiarDef.pouchId
    return API.Container_Check_Items(93, containerCheckBuf)
end

local function findSummoningPouchInBank(familiarDef)
    return bankCacheGet(familiarDef.pouchId) > 0
end

function Banking.withdrawSummoningPouch(familiarDef)
    if not API.BankOpen2() then return false end

    if Banking.findSummoningPouchInInventory(familiarDef) then return true end

    if not disableNotedMode() then return false end

    if not findSummoningPouchInBank(familiarDef) then
        API.printlua("No " .. familiarDef.name .. " pouches found in bank", 4, false)
        return false
    end

    API.printlua("Withdrawing " .. familiarDef.name .. " pouch...", 0, false)
    local withdrawAction = API.GetVarbitValue(45189) == 2 and 1 or 2
    API.DoAction_Bank(familiarDef.pouchId, withdrawAction, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return Banking.findSummoningPouchInInventory(familiarDef)
    end, 5, 100, "Failed to withdraw summoning pouch") then
        return false
    end

    bankCacheWithdraw(familiarDef.pouchId)
    return true
end

function Banking.getBankItemCount(itemId)
    return bankCacheGet(itemId)
end

function Banking.withdrawEnergy(locatorDef)
    if not API.BankOpen2() then return 0 end
    if not locatorDef then return 0 end

    local bankEnergy = API.Container_Get_s(95, locatorDef.energyId)
    local available = bankEnergy and bankEnergy.item_stack or 0

    if available <= 0 then
        return 0
    end

    API.printlua("Withdrawing " .. available .. " energy for locator recharge...", 0, false)

    if not disableNotedMode() then return 0 end

    local withdrawAction = API.GetVarbitValue(45189) == 7 and 1 or 7
    API.DoAction_Bank(locatorDef.energyId, withdrawAction, API.OFF_ACT_GeneralInterface_route)

    if not Utils.waitOrTerminate(function()
        return Inventory:Contains(locatorDef.energyId)
    end, 5, 100, "Failed to withdraw energy") then
        return 0
    end

    return Inventory:GetItemAmount(locatorDef.energyId)
end

function Banking.performBanking(config)
    local bankLocation = config.bankLocation
    local miningLocation = config.miningLocation
    local oreBoxId = config.oreBoxId
    local oreConfig = config.oreConfig
    local bankPin = config.bankPin
    local selectedOre = config.selectedOre
    local miningLocationKey = config.miningLocationKey
    local gemBagId = config.gemBagId
    local jujuDef = config.jujuDef
    local familiarDef = config.familiarDef

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
    elseif bankLocation.depositBox then
        if not Banking.depositToDepositBox(bankLocation.depositBox) then
            API.printlua("Failed to deposit to deposit box", 4, false)
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

        if jujuDef then
            if not Banking.withdrawJuju(jujuDef) then
                Banking.jujuWarning = "No juju potions available in bank"
            end
        end

        if familiarDef then
            local hasPouch = Banking.findSummoningPouchInInventory(familiarDef)
            local needsPouch = not hasPouch and (not Utils.isFamiliarActive(familiarDef) or Utils.needsFamiliarRefresh(familiarDef))
            if needsPouch then
                if not Banking.withdrawSummoningPouch(familiarDef) then
                    Banking.familiarWarning = "No " .. familiarDef.name .. " pouches available in bank"
                end
            end
        end

        local locatorDef = nil
        local locatorEquipped = false
        local withdrawnEnergy = 0
        local needsRecharge = false
        if Routes.useLocator and miningLocationKey then
            local Teleports = require("aio mining/mining_teleports")
            local locatorTargetOre = Utils.getLocatorOreForLocation(miningLocationKey)
            if locatorTargetOre then
                locatorDef, locatorEquipped = Teleports.scanForLocator(locatorTargetOre)
                if locatorDef then
                    local charges = Teleports.getLocatorCharges(locatorDef, locatorEquipped)
                    local energyInInventory = Inventory:GetItemAmount(locatorDef.energyId)
                    needsRecharge = charges <= 0

                    API.printlua("Locator check: charges=" .. math.floor(charges) .. ", energyInInv=" .. energyInInventory .. ", costPerCharge=" .. locatorDef.energyPerCharge, 0, false)

                    -- Proactively withdraw energy if we don't have enough for 1 charge, regardless of charge level
                    if energyInInventory < locatorDef.energyPerCharge then
                        withdrawnEnergy = Banking.withdrawEnergy(locatorDef)
                        local totalEnergy = energyInInventory + withdrawnEnergy
                        if totalEnergy < locatorDef.energyPerCharge then
                            API.printlua("Insufficient energy for recharge (" .. totalEnergy .. "/" .. locatorDef.energyPerCharge .. " needed)", 0, false)
                            if needsRecharge then
                                API.printlua("No energy available, falling back to alternate route", 4, false)
                                Routes.useLocator = false
                            end
                        end
                    else
                        API.printlua("Already have sufficient energy in inventory, skipping withdrawal", 0, false)
                    end
                else
                    API.printlua("No locator found for ore: " .. locatorTargetOre, 0, false)
                end
            else
                API.printlua("No locator route configured for location: " .. miningLocationKey, 0, false)
            end
        end

        Banking.closeBank()

        -- Recharge if at 0 charges and have enough energy
        if needsRecharge and locatorDef then
            local totalEnergy = Inventory:GetItemAmount(locatorDef.energyId)
            if totalEnergy >= locatorDef.energyPerCharge then
                local recharged = Utils.doRechargeDialog(locatorDef, locatorEquipped)
                -- Re-enable locator route if recharge succeeded
                if recharged and not Routes.useLocator then
                    Routes.useLocator = true
                    API.printlua("Locator recharged - re-enabling locator route", 0, false)
                end
            end
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
            local skipWalk = false
            if bankLocation.depositBox and miningLocation.oreCoords and miningLocation.oreCoords[selectedOre] then
                local oreCoord = miningLocation.oreCoords[selectedOre]
                local coord = API.PlayerCoord()
                if Utils.isWithinDistance(coord.x, coord.y, oreCoord.x, oreCoord.y, 35) then
                    skipWalk = true
                end
            end
            if not skipWalk then
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
    end

    return true
end

return Banking
