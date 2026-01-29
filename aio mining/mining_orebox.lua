local API = require("api")
local DATA = require("aio mining/mining_data")
local Utils = require("aio mining/mining_utils")

local OreBox = {}

function OreBox.find()
    for boxId, _ in pairs(DATA.ORE_BOX_INFO) do
        if Inventory:Contains(boxId) then
            return boxId
        end
    end
    return nil
end

function OreBox.isOresomeComplete()
    for _, vb in pairs(DATA.VARBIT_IDS.ORESOME) do
        if API.GetVarbitValue(vb) ~= 100 then
            return false
        end
    end
    return true
end

function OreBox.isStillOresomeComplete()
    for _, vb in pairs(DATA.VARBIT_IDS.STILL_ORESOME) do
        if API.GetVarbitValue(vb) ~= 100 then
            return false
        end
    end
    return true
end

function OreBox.getCapacity(boxId, oreConfig)
    if not oreConfig then return 0 end

    local boxInfo = DATA.ORE_BOX_INFO[boxId]
    if not boxInfo or oreConfig.tier > boxInfo.maxTier then
        return 0
    end

    local capacity = DATA.ORE_BOX_BASE_CAPACITY

    if oreConfig.oresomeKey then
        if oreConfig.capacityBoostLevel then
            local miningLevel = API.XPLevelTable(API.GetSkillXP("MINING"))
            if miningLevel >= oreConfig.capacityBoostLevel then
                capacity = capacity + DATA.MINING_LEVEL_BONUS
            end
        end

        if OreBox.isOresomeComplete() then
            capacity = capacity + DATA.ORESOME_BONUS
        end

        if OreBox.isStillOresomeComplete() then
            capacity = capacity + DATA.STILL_ORESOME_BONUS
        end
    end

    return capacity
end

function OreBox.getOreCount(oreConfig)
    if not oreConfig or not oreConfig.vbInBox then
        return 0
    end
    return API.GetVarbitValue(oreConfig.vbInBox)
end

function OreBox.isFull(boxId, oreConfig)
    if not boxId then
        return true
    end
    return OreBox.getOreCount(oreConfig) >= OreBox.getCapacity(boxId, oreConfig)
end

function OreBox.fill(boxId)
    if not boxId then
        return false
    end
    if not Inventory:IsOpen() then
        API.DoAction_Interface(0xc2, 0xffffffff, 1, 1431, 0, 9, API.OFF_ACT_GeneralInterface_route)
        if not Utils.waitOrTerminate(function()
            return Inventory:IsOpen()
        end, 10, 100, "Failed to open inventory") then
            return false
        end
    end
    API.logInfo("Filling ore box...")
    if API.DoAction_Inventory1(boxId, 0, 1, API.OFF_ACT_GeneralInterface_route) then
        API.RandomSleep2(600, 200, 200)
        return true
    end
    return false
end

function OreBox.getName(boxId)
    local boxInfo = DATA.ORE_BOX_INFO[boxId]
    if boxInfo then
        return boxInfo.name
    end
    return nil
end

function OreBox.canStore(boxId, oreConfig)
    if not boxId or not oreConfig then
        return false
    end
    local boxInfo = DATA.ORE_BOX_INFO[boxId]
    if not boxInfo then
        return false
    end
    return oreConfig.tier <= boxInfo.maxTier
end

function OreBox.validate(boxId, oreConfig)
    if not boxId or not oreConfig then
        return true
    end
    if not OreBox.canStore(boxId, oreConfig) then
        local oreName = oreConfig.name:gsub(" rock$", "")
        API.logWarn(OreBox.getName(boxId) .. " cannot store " .. oreName .. " (tier " .. oreConfig.tier .. ") - continuing without ore box")
        return false
    end
    return true
end

return OreBox