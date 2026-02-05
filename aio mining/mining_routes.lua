local API = require("api")
local Utils = require("aio mining/mining_utils")
local Teleports = require("aio mining/mining_teleports")
local DATA = require("aio mining/mining_data")

local Routes = {}

Routes.useLocator = false

-- Reusable single-element buffers for GetAllObjArray1 calls
local objIdBuf = {0}
local objTypeBuf = {0}
local interfaceScanBuf = {}

local function checkWaitCondition(wait)
    local coord = API.PlayerCoord()

    if wait.coord then
        if coord.x ~= wait.coord.x or coord.y ~= wait.coord.y then
            return false
        end
    end

    if wait.nearCoord then
        local dist = Utils.getDistance(coord.x, coord.y, wait.nearCoord.x, wait.nearCoord.y)
        if dist > (wait.nearCoord.maxDistance or 10) then
            return false
        end
    end

    if wait.region then
        if not Utils.isAtRegion(wait.region) then
            return false
        end
    end

    if wait.floor then
        if API.GetFloorLv_2() ~= wait.floor then
            return false
        end
    end

    if wait.nearObject then
        objIdBuf[1] = wait.nearObject.id
        objTypeBuf[1] = wait.nearObject.type or 12
        local objects = API.GetAllObjArray1(objIdBuf, 50, objTypeBuf)
        if #objects == 0 then return false end
        local dist = Utils.getDistance(coord.x, coord.y, objects[1].Tile_XYZ.x, objects[1].Tile_XYZ.y)
        if dist > wait.nearObject.maxDistance then
            return false
        end
    end

    if wait.objectState then
        objIdBuf[1] = wait.objectState.id
        objTypeBuf[1] = wait.objectState.type or 12
        local objects = API.GetAllObjArray1(objIdBuf, 50, objTypeBuf)
        if #objects == 0 then return false end
        if objects[1].Bool1 ~= wait.objectState.value then
            return false
        end
    end

    if wait.anim ~= nil then
        if API.ReadPlayerAnim() ~= wait.anim then
            return false
        end
    end

    if wait.minY then
        if coord.y < wait.minY then
            return false
        end
    end

    if wait.interface then
        interfaceScanBuf = API.ScanForInterfaceTest2Get(false, wait.interface.ids)
        if #interfaceScanBuf == 0 or interfaceScanBuf[1].textids ~= wait.interface.text then
            return false
        end
    end

    return true
end

local function shouldSkipStep(skip_if)
    if not skip_if then return false end

    local coord = API.PlayerCoord()

    if skip_if.nearCoord then
        local dist = Utils.getDistance(coord.x, coord.y, skip_if.nearCoord.x, skip_if.nearCoord.y)
        if dist <= (skip_if.nearCoord.maxDistance or 40) then
            return true
        end
    end

    if skip_if.nearCoords then
        for _, nc in ipairs(skip_if.nearCoords) do
            local dist = Utils.getDistance(coord.x, coord.y, nc.x, nc.y)
            if dist <= (nc.maxDistance or 40) then
                return true
            end
        end
    end

    if skip_if.objectState then
        objIdBuf[1] = skip_if.objectState.id
        objTypeBuf[1] = skip_if.objectState.type or 12
        local objects = API.GetAllObjArray1(objIdBuf, 50, objTypeBuf)
        if #objects > 0 and objects[1].Bool1 == skip_if.objectState.value then
            return true
        end
    end

    return false
end

function Routes.executeStep(step)
    local desc = step.desc or "Step"

    if shouldSkipStep(step.skip_if) then
        API.printlua("Route: Skipping " .. desc, 0, false)
        return true
    end

    API.printlua("Route: " .. desc, 0, false)

    if step.action then
        if step.action.lodestone then
            if not Teleports.lodestone(step.action.lodestone) then
                return false
            end
        elseif step.action.teleport then
            if not Teleports[step.action.teleport](step.action.teleportArg) then
                return false
            end
        elseif step.action.interact then
            local i = step.action.interact
            Interact:Object(i.object, i.action, i.tile, i.range or 40)
        elseif step.action.walk then
            local w = step.action.walk
            if not Utils.walkThroughWaypoints(w.waypoints, w.threshold or 6) then
                return false
            end
        elseif step.action.interface then
            local i = step.action.interface
            API.DoAction_Interface(i.a, i.b, i.c, i.d, i.e, i.f, i.route)
        end
    end

    if step.wait then
        if step.retryAction and step.action and step.action.interact then
            local timeout = step.timeout or 20
            local startTime = os.time()
            while os.time() - startTime < timeout do
                if checkWaitCondition(step.wait) then
                    return true
                end

                if step.retryOnAnim then
                    -- Pattern: interact, wait for success coord OR fail anim, retry on fail
                    while os.time() - startTime < timeout do
                        if checkWaitCondition(step.wait) then
                            return true
                        end
                        if API.ReadPlayerAnim() == step.retryOnAnim then
                            API.printlua("Route: Failed attempt, retrying...", 0, false)
                            while os.time() - startTime < timeout do
                                if API.ReadPlayerAnim() == 0 then break end
                                API.RandomSleep2(100, 50, 50)
                            end
                            startTime = os.time()
                            break
                        end
                        API.RandomSleep2(100, 50, 50)
                    end
                    if os.time() - startTime < timeout then
                        local i = step.action.interact
                        Interact:Object(i.object, i.action, i.tile, i.range or 40)
                    end
                else
                    -- Pattern: interact, wait for objectState change or anim cycle
                    local waitStart = os.time()
                    while os.time() - startTime < timeout do
                        if checkWaitCondition(step.wait) then
                            return true
                        end
                        if os.time() - waitStart >= 3 and API.ReadPlayerAnim() == 0 then
                            break
                        end
                        API.RandomSleep2(100, 50, 50)
                    end
                    if os.time() - startTime < timeout then
                        local i = step.action.interact
                        Interact:Object(i.object, i.action, i.tile, i.range or 40)
                    end
                end

                API.RandomSleep2(100, 50, 50)
            end
            API.printlua("Failed: " .. desc, 4, false)
            API.Write_LoopyLoop(false)
            return false
        else
            if not Utils.waitOrTerminate(function()
                return checkWaitCondition(step.wait)
            end, step.timeout or 20, 100, "Failed: " .. desc) then
                return false
            end
        end
    end

    return true
end

function Routes.execute(route)
    for i, step in ipairs(route) do
        API.printlua("Executing route step " .. i .. "/" .. #route, 0, false)
        if not Routes.executeStep(step) then
            API.printlua("Route failed at step " .. i, 4, false)
            return false
        end
        API.RandomSleep2(300, 150, 100)
    end
    API.printlua("Route completed successfully", 0, false)
    return true
end

local lodestoneWarned = {}

function Routes.resetState()
    lodestoneWarned = {}
end

function Routes.checkLodestones(route)
    if not route then return end
    for _, step in ipairs(route) do
        if step.action and step.action.lodestone then
            local lode = step.action.lodestone
            if not lodestoneWarned[lode.name] and not Teleports.isLodestoneAvailable(lode) then
                lodestoneWarned[lode.name] = true
                API.printlua(lode.name .. " Lodestone not on action bar - will use lodestone network", 4, false)
            end
        end
    end
end

function Routes.validateLodestonesUnlocked(route)
    if not route then return true end
    for _, step in ipairs(route) do
        if step.action and step.action.lodestone then
            local lode = step.action.lodestone
            if not Teleports.isLodestoneUnlocked(lode) then
                API.printlua(lode.name .. " lodestone is not unlocked", 4, false)
                return false
            end
        end
    end
    return true
end

function Routes.validateLodestonesForDestination(destination)
    if not destination then return true end

    if destination.route then
        return Routes.validateLodestonesUnlocked(destination.route)
    end

    if destination.routeOptions then
        local selectedRoute = Routes.selectRoute(destination)
        if selectedRoute then
            return Routes.validateLodestonesUnlocked(selectedRoute)
        end
    end

    return true
end

function Routes.checkLodestonesForDestination(destination)
    if not destination then return end

    if destination.route then
        Routes.checkLodestones(destination.route)
        return
    end

    if destination.routeOptions then
        local selectedRoute = Routes.selectRoute(destination)
        if selectedRoute then
            Routes.checkLodestones(selectedRoute)
        end
    end
end

local function isAtDestination(destination, selectedOre)
    if not destination.oreCoords or not selectedOre or not destination.oreCoords[selectedOre] then
        return false
    end

    local oreCoord = destination.oreCoords[selectedOre]
    local playerCoord = API.PlayerCoord()
    local distance = Utils.getDistance(playerCoord.x, playerCoord.y, oreCoord.x, oreCoord.y)
    return distance <= 20
end

function Routes.selectRoute(destination, fromLocationKey)
    if destination.route then
        return destination.route
    end

    if not destination.routeOptions then
        return nil
    end

    local coord = API.PlayerCoord()
    for _, option in ipairs(destination.routeOptions) do
        if not option.condition then
            return option.route
        end
        if option.condition.fromLocation then
            local matched = false
            for _, loc in ipairs(option.condition.fromLocation) do
                if loc == fromLocationKey then matched = true break end
            end
            if not matched then goto continue end
        end
        if option.condition.dungeoneeringCape then
            if Teleports.hasDungeoneeringCape() then
                return option.route
            end
        elseif option.condition.slayerCape then
            if Teleports.hasSlayerCape() and Utils.getCombatLevel() >= 120 then
                return option.route
            end
        elseif option.condition.archJournal then
            if Teleports.hasArchJournal() then
                return option.route
            end
        elseif option.condition.nearCoord then
            local dist = Utils.getDistance(coord.x, coord.y, option.condition.nearCoord.x, option.condition.nearCoord.y)
            if dist <= (option.condition.nearCoord.maxDistance or 40) then
                return option.route
            end
        elseif option.condition.region and Utils.isAtRegion(option.condition.region) then
            return option.route
        elseif option.condition.resourceLocator and Routes.useLocator then
            if Teleports.hasResourceLocator(option.condition.resourceLocator) then
                return option.route
            end
        end
        ::continue::
    end
    return nil
end

-- Map teleport type to the item IDs it requires.
local teleportItemMap = {
    archJournal = { DATA.ARCH_JOURNAL_ID },
    ringOfKinship = { DATA.RING_OF_KINSHIP_ID },
    dungeoneeringCape = DATA.DUNGEONEERING_CAPE_IDS,
    slayerCape = DATA.SLAYER_CAPE_IDS,
}

-- Return the set of item IDs required by a route's teleport steps.
function Routes.getRouteItemRequirements(route)
    local items = {}
    if not route then return items end
    for _, step in ipairs(route) do
        if step.action and step.action.teleport then
            local ids = teleportItemMap[step.action.teleport]
            if ids then
                for _, id in ipairs(ids) do
                    items[id] = true
                end
            end
        end
    end
    return items
end

-- Return the set of item IDs required by the selected route for a destination.
function Routes.getSelectedRouteItemRequirements(destination, fromLocationKey)
    if not destination then return {} end
    local route = Routes.selectRoute(destination, fromLocationKey)
    return Routes.getRouteItemRequirements(route)
end

function Routes.travelTo(destination, selectedOre, fromLocationKey)
    if not destination then
        API.printlua("No destination provided", 4, false)
        return false
    end

    if isAtDestination(destination, selectedOre) then
        API.printlua("Already at " .. destination.name, 0, false)
        return true
    end

    if shouldSkipStep(destination.skip_if) then
        API.printlua("Already at " .. destination.name, 0, false)
        return true
    end

    local route = Routes.selectRoute(destination, fromLocationKey)

    if not route then
        API.printlua("No route defined for " .. destination.name, 4, false)
        return false
    end

    -- Close bank if open before teleporting
    local Banking = require("aio mining/mining_banking")
    Banking.closeBank()

    API.printlua("Traveling to " .. destination.name .. "...", 5, false)
    local routeSuccess = Routes.execute(route)

    -- If locator route failed, check if we should fall back to alternate route
    if not routeSuccess and Routes.useLocator and destination.routeOptions then
        -- Find locator ore from route options to check if locator is depleted
        local locatorOre = nil
        for _, option in ipairs(destination.routeOptions) do
            if option.condition and option.condition.resourceLocator then
                locatorOre = option.condition.resourceLocator
                break
            end
        end

        if locatorOre then
            local locator, isEquipped = Teleports.scanForLocator(locatorOre)
            if locator then
                local charges = Teleports.getLocatorCharges(locator, isEquipped)
                local energyInInventory = Inventory:GetItemAmount(locator.energyId)

                -- If out of charges and not enough energy for 1 charge, switch to fallback route
                if charges <= 0 and energyInInventory < locator.energyPerCharge then
                    API.printlua("Locator depleted with no energy - switching to fallback route", 0, false)
                    Routes.useLocator = false
                    local fallbackRoute = Routes.selectRoute(destination, fromLocationKey)
                    if fallbackRoute and fallbackRoute ~= route then
                        API.printlua("Using fallback route...", 0, false)
                        routeSuccess = Routes.execute(fallbackRoute)
                    end
                end
            end
        end
    end

    if not routeSuccess then
        API.printlua("Route to " .. destination.name .. " failed", 4, false)
        return false
    end

    if selectedOre and not (destination.oreWaypoints and destination.oreWaypoints[selectedOre]) then
        if not Utils.ensureAtOreLocation(destination, selectedOre) then
            API.printlua("Failed to reach ore location", 4, false)
            return false
        end
    end

    API.printlua("Arrived at " .. destination.name, 0, false)
    return true
end

Routes.TO_AL_KHARID_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.AL_KHARID },
        skip_if = { nearCoord = {x = 3297, y = 3185} },
        desc = "Teleport to Al Kharid lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3307, y = 3217}, {x = 3306, y = 3244}, {x = 3301, y = 3272}, {x = 3298, y = 3294}} } },
        desc = "Walk to Al Kharid mine"
    }
}

Routes.TO_AL_KHARID_MINE_VIA_ARCH_JOURNAL = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3335, y = 3378}} } },
        skip_if = { nearCoord = {x = 3335, y = 3378, maxDistance = 15} },
        desc = "Walk from bank to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3315, y = 3349}, {x = 3291, y = 3333}, {x = 3291, y = 3309}} } },
        desc = "Walk to Rocks shortcut"
    },
    {
        action = { interact = { object = "Rocks", action = "Climb over" } },
        wait = { anim = 3303 },
        timeout = 15,
        desc = "Climb over rocks - animation start"
    },
    {
        wait = { anim = 0 },
        timeout = 15,
        desc = "Climb over rocks - animation end"
    },
    {
        action = { walk = { waypoints = {{x = 3300, y = 3294}} } },
        desc = "Walk to Al Kharid mine"
    }
}

Routes.TO_AL_KHARID_RESOURCE_DUNGEON = {
    {
        action = { lodestone = Teleports.LODESTONES.AL_KHARID },
        skip_if = { nearCoord = {x = 3297, y = 3185} },
        desc = "Teleport to Al Kharid lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3307, y = 3217}, {x = 3306, y = 3244}, {x = 3301, y = 3272}, {x = 3298, y = 3294}, {x = 3299, y = 3307}} } },
        desc = "Walk to resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 18, y = 70, z = 4678}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_AL_KHARID_MINE_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "al_kharid" },
        skip_if = { nearCoord = {x = 3301, y = 3309} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { walk = { waypoints = {{x = 3300, y = 3294}} } },
        desc = "Walk to Al Kharid mine"
    }
}

Routes.TO_AL_KHARID_GEM_ROCKS = {
    {
        action = { lodestone = Teleports.LODESTONES.AL_KHARID },
        skip_if = { nearCoord = {x = 3297, y = 3185} },
        desc = "Teleport to Al Kharid lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3307, y = 3217}, {x = 3306, y = 3244}, {x = 3301, y = 3272}, {x = 3299, y = 3313}} } },
        desc = "Walk to Al Kharid gem rocks"
    }
}

Routes.TO_AL_KHARID_GEM_ROCKS_VIA_ARCH_JOURNAL = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3335, y = 3378}} } },
        skip_if = { nearCoord = {x = 3335, y = 3378, maxDistance = 15} },
        desc = "Walk from bank to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3315, y = 3349}, {x = 3291, y = 3333}, {x = 3291, y = 3309}} } },
        desc = "Walk to Rocks shortcut"
    },
    {
        action = { interact = { object = "Rocks", action = "Climb over" } },
        wait = { anim = 3303 },
        timeout = 15,
        desc = "Climb over rocks - animation start"
    },
    {
        wait = { anim = 0 },
        timeout = 15,
        desc = "Climb over rocks - animation end"
    }
}

Routes.TO_AL_KHARID_GEM_ROCKS_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "al_kharid" },
        skip_if = { nearCoord = {x = 3301, y = 3309} },
        desc = "Teleport via Dungeoneering cape"
    }
}

Routes.TO_AL_KHARID_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "al_kharid" },
        skip_if = { nearCoord = {x = 3301, y = 3309} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 18, y = 70, z = 4678}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_AL_KHARID_RESOURCE_DUNGEON_VIA_ARCH_JOURNAL = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3335, y = 3378}} } },
        skip_if = { nearCoord = {x = 3335, y = 3378, maxDistance = 15} },
        desc = "Walk from bank to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3315, y = 3349}, {x = 3291, y = 3333}, {x = 3291, y = 3309}} } },
        desc = "Walk to Rocks shortcut"
    },
    {
        action = { interact = { object = "Rocks", action = "Climb over" } },
        wait = { anim = 3303 },
        timeout = 15,
        desc = "Climb over rocks - animation start"
    },
    {
        wait = { anim = 0 },
        timeout = 15,
        desc = "Climb over rocks - animation end"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 18, y = 70, z = 4678}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_ANACHRONIA_SW = {
    {
        action = { lodestone = Teleports.LODESTONES.ARDOUGNE },
        skip_if = { nearCoord = {x = 2634, y = 3349} },
        desc = "Teleport to Ardougne lodestone"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb up", tile = WPOINT.new(2654, 3362, 0) } },
        wait = { coord = {x = 2656, y = 3362}, floor = 1 },
        timeout = 20,
        desc = "Climb stairs to first floor"
    },
    {
        action = { interact = { object = "Mystical tree", action = "Teleport", tile = WPOINT.new(2655, 3365, 1) } },
        wait = { coord = {x = 5201, y = 2374} },
        timeout = 15,
        desc = "Teleport via Mystical tree"
    },
    {
        action = { walk = { waypoints = {{x = 5206, y = 2358}, {x = 5220, y = 2343}, {x = 5235, y = 2330}} } },
        desc = "Walk to second Mystical tree"
    },
    {
        wait = { nearObject = {id = 114328, type = 12, maxDistance = 15} },
        timeout = 5,
        desc = "Verify near Mystical tree for Bill teleport"
    },
    {
        action = { interact = { object = "Mystical tree", action = "Teleport to Bill", tile = WPOINT.new(5244, 2332, 0) } },
        wait = { coord = {x = 5301, y = 2294} },
        timeout = 15,
        desc = "Teleport to Bill"
    },
    {
        action = { walk = { waypoints = {{x = 5314, y = 2285}, {x = 5329, y = 2269}, {x = 5340, y = 2255}} } },
        desc = "Walk to light animica rocks"
    }
}

Routes.TO_ANACHRONIA_SWAMP = {
    {
        action = { teleport = "slayerCape", teleportArg = "laniakea" },
        skip_if = { nearCoord = {x = 5670, y = 2140} },
        desc = "Teleport to Laniakea via Slayer cape"
    },
    {
        action = { walk = { waypoints = {{x = 5657, y = 2176}, {x = 5616, y = 2172}} } },
        desc = "Walk to dark animica rocks"
    }
}

Routes.TO_LLETYA_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.TIRANNWN },
        skip_if = { nearCoord = {x = 2254, y = 3149} },
        desc = "Teleport to Tirannwn lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2272, y = 3161}} } },
        desc = "Walk to stick trap"
    },
    {
        action = { interact = { object = "Sticks", action = "Pass" } },
        wait = { coord = {x = 2277, y = 3163} },
        timeout = 10,
        retryAction = true,
        retryOnAnim = 18353,
        desc = "Pass sticks"
    }
}

Routes.TO_EMPTY_THRONE_ROOM = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3376, y = 3402}} } },
        desc = "Walk to Ancient doors"
    },
    {
        action = { interact = { object = "Ancient doors", action = "Enter" } },
        wait = { region = {x = 44, y = 197, z = 11461} },
        timeout = 20,
        desc = "Enter Empty Throne Room"
    },
    {
        action = { walk = { waypoints = {{x = 2848, y = 12619}, {x = 2856, y = 12630}, {x = 2875, y = 12637}} } },
        desc = "Walk to dark animica rocks"
    }
}

Routes.TO_ARCHAEOLOGY_CAMPUS_BANK = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3347, y = 3390}, {x = 3361, y = 3396}} } },
        desc = "Walk to bank chest"
    }
}

Routes.TO_PORT_PHASMATYS_SOUTH_MINE = {
    {
        action = { teleport = "archJournal" },
        wait = { anim = 0 },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        timeout = 15,
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { interact = { object = "Dig sites map", action = "View" } },
        wait = { interface = { ids = DATA.INTERFACES.DIG_SITES, text = "Archaeological Dig Sites" } },
        timeout = 10,
        desc = "Open Dig sites map"
    },
    {
        action = { interface = { a = 0xffffffff, b = 0xffffffff, c = 2, d = 667, e = 11, f = 1, route = API.OFF_ACT_GeneralInterface_route } },
        wait = { nearCoord = {x = 3697, y = 3206}, anim = 0 },
        timeout = 20,
        desc = "Teleport to Everlight digsite"
    },
    {
        action = { walk = { waypoints = {{x = 3694, y = 3235}, {x = 3678, y = 3264}, {x = 3681, y = 3299}, {x = 3693, y = 3332}, {x = 3696, y = 3365}, {x = 3692, y = 3398}} } },
        desc = "Walk to Port Phasmatys South mine"
    }
}

Routes.TO_FALADOR_WEST_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2963, y = 3380}, {x = 2945, y = 3369}} } },
        desc = "Walk to Falador West bank"
    }
}

Routes.TO_FALADOR_EAST_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2983, y = 3374}, {x = 3012, y = 3356}} } },
        desc = "Walk to Falador East bank"
    }
}

Routes.TO_EDGEVILLE_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.EDGEVILLE },
        skip_if = { nearCoord = {x = 3067, y = 3505} },
        desc = "Teleport to Edgeville lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3085, y = 3502}, {x = 3094, y = 3496}} } },
        desc = "Walk to Edgeville bank"
    }
}

Routes.TO_POF_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.ARDOUGNE },
        skip_if = { nearCoord = {x = 2634, y = 3349} },
        desc = "Teleport to Ardougne lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2650, y = 3349}} } },
        desc = "Walk to POF bank chest"
    }
}

Routes.TO_VARROCK_SW_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.VARROCK },
        skip_if = { nearCoord = {x = 3214, y = 3377} },
        desc = "Teleport to Varrock lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3197, y = 3373}, {x = 3182, y = 3370}} } },
        desc = "Walk to Varrock SW mine"
    }
}

Routes.TO_VARROCK_SE_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.VARROCK },
        skip_if = { nearCoord = {x = 3214, y = 3377} },
        desc = "Teleport to Varrock lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3238, y = 3371}, {x = 3267, y = 3371}, {x = 3288, y = 3364}} } },
        desc = "Walk to Varrock SE mine"
    }
}

Routes.TO_VARROCK_SE_MINE_VIA_ARCH_JOURNAL = {
    {
        action = { teleport = "archJournal" },
        skip_if = { nearCoord = {x = 3336, y = 3378} },
        desc = "Teleport to Archaeology Campus"
    },
    {
        action = { walk = { waypoints = {{x = 3306, y = 3367}, {x = 3287, y = 3363}} } },
        desc = "Walk to Varrock SE mine"
    }
}

Routes.TO_LUMBRIDGE_SE_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.LUMBRIDGE },
        skip_if = { nearCoord = {x = 3233, y = 3222} },
        desc = "Teleport to Lumbridge lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3243, y = 3196}, {x = 3239, y = 3175}, {x = 3229, y = 3150}} } },
        desc = "Walk to Lumbridge SE mine"
    }
}

Routes.TO_LUMBRIDGE_SW_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.LUMBRIDGE },
        skip_if = { nearCoord = {x = 3233, y = 3222} },
        desc = "Teleport to Lumbridge lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3219, y = 3200}, {x = 3196, y = 3205}, {x = 3170, y = 3207}, {x = 3160, y = 3188}, {x = 3153, y = 3170}, {x = 3147, y = 3147}} } },
        desc = "Walk to Lumbridge SW mine"
    }
}

Routes.TO_RIMMINGTON_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.PORT_SARIM },
        skip_if = { nearCoord = {x = 3011, y = 3216} },
        desc = "Teleport to Port Sarim lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2986, y = 3219}, {x = 2974, y = 3235}} } },
        desc = "Walk to Rimmington mine"
    }
}

Routes.TO_DWARVEN_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2978, y = 3378}, {x = 3005, y = 3361}, {x = 3030, y = 3366}, {x = 3060, y = 3372}} } },
        desc = "Walk to Dwarven Mine entrance"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-down", tile = WPOINT.new(3060, 3377, 0) } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down stairs"
    }
}

Routes.TO_DWARVEN_MINE_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "dwarven_mine" },
        skip_if = { nearCoord = {x = 3037, y = 9774} },
        desc = "Teleport via Dungeoneering cape"
    }
}

Routes.TO_ARTISANS_GUILD_FURNACE_FROM_DM = {
    {
        action = { walk = { waypoints = {{x = 3056, y = 9776}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3039, y = 3340}} } },
        desc = "Walk to Artisans Guild furnace"
    }
}

Routes.TO_ARTISANS_GUILD_FURNACE_FROM_DM_COAL = {
    {
        action = { walk = { waypoints = {{x = 3043, y = 9798}, {x = 3057, y = 9777}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3039, y = 3340}} } },
        desc = "Walk to Artisans Guild furnace"
    }
}

Routes.TO_ARTISANS_GUILD_BANK_FROM_DM = {
    {
        action = { walk = { waypoints = {{x = 3056, y = 9776}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3058, y = 3340}} } },
        desc = "Walk to Artisans Guild bank"
    }
}

Routes.TO_ARTISANS_GUILD_BANK_FROM_DM_COAL = {
    {
        action = { walk = { waypoints = {{x = 3043, y = 9798}, {x = 3057, y = 9777}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3058, y = 3340}} } },
        desc = "Walk to Artisans Guild bank"
    }
}

Routes.TO_FALADOR_EAST_BANK_FROM_DM = {
    {
        action = { walk = { waypoints = {{x = 3056, y = 9776}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3032, y = 3367}, {x = 3013, y = 3356}} } },
        desc = "Walk to Falador East bank"
    }
}

Routes.TO_FALADOR_EAST_BANK_FROM_DM_COAL = {
    {
        action = { walk = { waypoints = {{x = 3043, y = 9798}, {x = 3057, y = 9777}} } },
        desc = "Walk to stairs"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-up" } },
        wait = { nearCoord = {x = 3061, y = 3376}, nearObject = {id = 11714, type = 12, maxDistance = 20} },
        timeout = 20,
        desc = "Climb up stairs"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { walk = { waypoints = {{x = 3032, y = 3367}, {x = 3013, y = 3356}} } },
        desc = "Walk to Falador East bank"
    }
}

Routes.TO_DWARVEN_MINE_FROM_ARTISANS_GUILD_FURNACE = {
    {
        action = { walk = { waypoints = {{x = 3060, y = 3372}} } },
        desc = "Walk to Dwarven Mine entrance"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-down", tile = WPOINT.new(3060, 3377, 0) } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down stairs"
    }
}

Routes.TO_DWARVEN_MINE_FROM_ARTISANS_GUILD_BANK = {
    {
        action = { walk = { waypoints = {{x = 3060, y = 3372}} } },
        desc = "Walk to Dwarven Mine entrance"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-down", tile = WPOINT.new(3060, 3377, 0) } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down stairs"
    }
}

Routes.TO_DWARVEN_MINE_FROM_FALADOR_EAST_BANK = {
    {
        action = { walk = { waypoints = {{x = 3032, y = 3367}, {x = 3060, y = 3372}} } },
        desc = "Walk to Dwarven Mine entrance"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-down", tile = WPOINT.new(3060, 3377, 0) } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down stairs"
    }
}

Routes.TO_DWARVEN_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "dwarven_mine" },
        skip_if = { nearCoord = {x = 3037, y = 9774} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { coord = {x = 1041, y = 4575}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_KARAMJA_VOLCANO_MINE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "karamja" },
        skip_if = { nearCoord = {x = 2844, y = 9558} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { walk = { waypoints = {{x = 2860, y = 9577}} } },
        desc = "Walk to runite rocks"
    }
}

Routes.TO_MINING_GUILD = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2978, y = 3378}, {x = 3005, y = 3361}, {x = 3031, y = 3348}, {x = 3021, y = 3339}} } },
        desc = "Walk to Mining Guild entrance"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    }
}

Routes.TO_MINING_GUILD_FROM_ARTISANS_WORKSHOP = {
    {
        action = { walk = { waypoints = {{x = 3021, y = 3339}} } },
        skip_if = { nearCoord = {x = 3021, y = 3339} },
        desc = "Walk to Mining Guild ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    }
}

Routes.TO_MINING_GUILD_RESOURCE_DUNGEON = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2978, y = 3378}, {x = 3005, y = 3361}, {x = 3031, y = 3348}, {x = 3021, y = 3339}} } },
        desc = "Walk to Mining Guild entrance"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    },
    {
        wait = { nearObject = {id = 52856, type = 0, maxDistance = 50} },
        timeout = 10,
        desc = "Wait for resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 16, y = 70, z = 4166} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_WORKSHOP = {
    {
        action = { walk = { waypoints = {{x = 3021, y = 3339}} } },
        skip_if = { nearCoord = {x = 3021, y = 3339} },
        desc = "Walk to Mining Guild ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    },
    {
        wait = { nearObject = {id = 52856, type = 0, maxDistance = 50} },
        timeout = 10,
        desc = "Wait for resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 16, y = 70, z = 4166} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_DWARVEN_RESOURCE_DUNGEON = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2978, y = 3378}, {x = 3005, y = 3361}, {x = 3030, y = 3366}, {x = 3060, y = 3372}} } },
        desc = "Walk to Dwarven Mine entrance"
    },
    {
        action = { interact = { object = "Door", action = "Open", tile = WPOINT.new(3061, 3374, 0) } },
        skip_if = { objectState = {id = 11714, type = 12, value = 1} },
        wait = { objectState = {id = 11714, type = 12, value = 1} },
        timeout = 10,
        desc = "Open door"
    },
    {
        action = { interact = { object = "Stairs", action = "Climb-down", tile = WPOINT.new(3060, 3377, 0) } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down stairs"
    },
    {
        action = { walk = { waypoints = {{x = 3037, y = 9772}} } },
        desc = "Walk to resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { coord = {x = 1041, y = 4575}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_WILDERNESS_VOLCANO_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.WILDERNESS },
        skip_if = { nearCoord = {x = 3143, y = 3636} },
        desc = "Teleport to Wilderness lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3168, y = 3629}, {x = 3185, y = 3632}} } },
        desc = "Walk to Wilderness Volcano mine"
    }
}

Routes.TO_WILDERNESS_HOBGOBLIN_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.WILDERNESS },
        skip_if = { nearCoord = {x = 3143, y = 3636} },
        desc = "Teleport to Wilderness lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3116, y = 3645}, {x = 3089, y = 3657}, {x = 3072, y = 3683}, {x = 3071, y = 3720}, {x = 3078, y = 3747}, {x = 3086, y = 3770}, {x = 3077, y = 3794}, {x = 3051, y = 3800}, {x = 3031, y = 3801}} } },
        desc = "Walk to Wilderness Hobgoblin mine"
    }
}

Routes.TO_WILDERNESS_PIRATES_HIDEOUT = {
    {
        action = { lodestone = Teleports.LODESTONES.EDGEVILLE },
        skip_if = { nearCoord = {x = 3067, y = 3505} },
        desc = "Teleport to Edgeville lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3087, y = 3492}, {x = 3094, y = 3476}} } },
        desc = "Walk to wilderness lever"
    },
    {
        action = { interact = { object = "Lever", action = "Pull" } },
        wait = { nearCoord = {x = 3154, y = 3924}, anim = 0 },
        timeout = 20,
        desc = "Pull lever to teleport"
    },
    {
        action = { walk = { waypoints = {{x = 3158, y = 3947}} } },
        desc = "Walk to web"
    },
    {
        action = { interact = { object = "Web", action = "Slash" } },
        skip_if = { objectState = {id = 65346, type = 12, value = 1} },
        wait = { objectState = {id = 65346, type = 12, value = 1} },
        timeout = 30,
        retryAction = true,
        desc = "Slash web"
    },
    {
        action = { walk = { waypoints = {{x = 3131, y = 3957}, {x = 3101, y = 3962}, {x = 3075, y = 3950}, {x = 3058, y = 3946}} } },
        desc = "Walk to Pirates Hideout mine"
    }
}

Routes.TO_WILDERNESS_PIRATES_HIDEOUT_VIA_SLAYER_CAPE = {
    {
        action = { teleport = "slayerCape", teleportArg = "mandrith" },
        skip_if = { nearCoord = {x = 3050, y = 3949} },
        desc = "Teleport to Mandrith via Slayer cape"
    }
}

Routes.TO_PISCATORIS_SOUTH_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.EAGLES_PEAK },
        skip_if = { nearCoord = {x = 2366, y = 3479} },
        desc = "Teleport to Eagles' Peak lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2357, y = 3513}, {x = 2352, y = 3545}, {x = 2348, y = 3580}, {x = 2344, y = 3613}, {x = 2337, y = 3639}} } },
        desc = "Walk to Piscatoris South mine"
    }
}

Routes.TO_MEMORIAL_TO_GUTHIX_BANK = {
    {
        action = { teleport = "memoryStrand" },
        skip_if = { nearCoord = {x = 2292, y = 3553} },
        desc = "Teleport to Memorial to Guthix"
    },
    {
        action = { walk = { waypoints = {{x = 2280, y = 3559}} } },
        desc = "Walk to bank chest"
    }
}

Routes.TO_FORT_FORINTHRY_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.FORT_FORINTHRY },
        skip_if = { nearCoord = {x = 3298, y = 3526} },
        desc = "Teleport to Fort Forinthry lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3303, y = 3544}} } },
        desc = "Walk to Copperpot"
    }
}

Routes.TO_FORT_FORINTHRY_FURNACE = {
    {
        action = { lodestone = Teleports.LODESTONES.FORT_FORINTHRY },
        skip_if = { nearCoord = {x = 3298, y = 3526} },
        desc = "Teleport to Fort Forinthry lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3303, y = 3544}, {x = 3280, y = 3558}} } },
        desc = "Walk to furnace"
    }
}

Routes.TO_ARTISANS_GUILD_FURNACE = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2981, y = 3377}, {x = 3005, y = 3354}, {x = 3039, y = 3339}} } },
        desc = "Walk to Artisans Guild furnace"
    }
}

Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MG = {
    {
        action = { walk = { waypoints = {{x = 3021, y = 9739}} } },
        skip_if = { nearCoord = {x = 3021, y = 9739} },
        desc = "Walk to ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-up" } },
        wait = { region = {x = 47, y = 52, z = 12084}, anim = 0 },
        timeout = 20,
        desc = "Climb up ladder"
    },
    {
        action = { walk = { waypoints = {{x = 3039, y = 3339}} } },
        desc = "Walk to Artisans Guild furnace"
    }
}

Routes.TO_ARTISANS_GUILD_FURNACE_FROM_MGRD = {
    {
        action = { interact = { object = "Mysterious door", action = "Exit" } },
        wait = { region = {x = 47, y = 152, z = 12184}, anim = 0 },
        timeout = 20,
        desc = "Exit resource dungeon"
    },
    {
        action = { walk = { waypoints = {{x = 3021, y = 9739}} } },
        skip_if = { nearCoord = {x = 3021, y = 9739} },
        desc = "Walk to ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-up" } },
        wait = { region = {x = 47, y = 52, z = 12084}, anim = 0 },
        timeout = 20,
        desc = "Climb up ladder"
    },
    {
        action = { walk = { waypoints = {{x = 3039, y = 3339}} } },
        desc = "Walk to Artisans Guild furnace"
    }
}

Routes.TO_ARTISANS_GUILD_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.FALADOR },
        skip_if = { nearCoord = {x = 2967, y = 3404} },
        desc = "Teleport to Falador lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2981, y = 3377}, {x = 3005, y = 3354}, {x = 3039, y = 3339}, {x = 3059, y = 3339}} } },
        desc = "Walk to Artisans Guild bank"
    }
}

Routes.TO_ARTISANS_GUILD_BANK_FROM_MG = {
    {
        action = { walk = { waypoints = {{x = 3021, y = 9739}} } },
        skip_if = { nearCoord = {x = 3021, y = 9739} },
        desc = "Walk to ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-up" } },
        wait = { region = {x = 47, y = 52, z = 12084}, anim = 0 },
        timeout = 20,
        desc = "Climb up ladder"
    },
    {
        action = { walk = { waypoints = {{x = 3059, y = 3339}} } },
        desc = "Walk to Artisans Guild bank"
    }
}

Routes.TO_ARTISANS_GUILD_BANK_FROM_MGRD = {
    {
        action = { interact = { object = "Mysterious door", action = "Exit" } },
        wait = { region = {x = 47, y = 152, z = 12184}, anim = 0 },
        timeout = 20,
        desc = "Exit resource dungeon"
    },
    {
        action = { walk = { waypoints = {{x = 3021, y = 9739}} } },
        skip_if = { nearCoord = {x = 3021, y = 9739} },
        desc = "Walk to ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-up" } },
        wait = { region = {x = 47, y = 52, z = 12084}, anim = 0 },
        timeout = 20,
        desc = "Climb up ladder"
    },
    {
        action = { walk = { waypoints = {{x = 3059, y = 3339}} } },
        desc = "Walk to Artisans Guild bank"
    }
}

Routes.TO_MINING_GUILD_FROM_ARTISANS_GUILD_BANK = {
    {
        action = { walk = { waypoints = {{x = 3032, y = 3339}, {x = 3021, y = 3339}} } },
        desc = "Walk to Mining Guild ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    }
}

Routes.TO_WILDERNESS_SOUTH_WEST_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.EDGEVILLE },
        skip_if = { nearCoord = {x = 3067, y = 3505} },
        desc = "Teleport to Edgeville lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3062, y = 3519}} } },
        desc = "Walk to Wilderness wall"
    },
    {
        action = { interact = { object = "Wilderness wall", action = "Cross" } },
        wait = { anim = 6703 },
        timeout = 15,
        desc = "Cross Wilderness wall - animation start"
    },
    {
        wait = { anim = 0 },
        timeout = 15,
        desc = "Cross Wilderness wall - animation end"
    },
    {
        action = { walk = { waypoints = {{x = 3048, y = 3552}, {x = 3044, y = 3584}, {x = 3018, y = 3592}} } },
        desc = "Walk to Wilderness South-West mine"
    }
}

Routes.TO_WILDERNESS_SOUTH_MINE = {
    {
        action = { lodestone = Teleports.LODESTONES.EDGEVILLE },
        skip_if = { nearCoord = {x = 3067, y = 3505} },
        desc = "Teleport to Edgeville lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3081, y = 3519}} } },
        desc = "Walk to Wilderness wall"
    },
    {
        action = { interact = { object = "Wilderness wall", action = "Cross" } },
        wait = { anim = 6703 },
        timeout = 15,
        desc = "Cross Wilderness wall - animation start"
    },
    {
        wait = { anim = 0 },
        timeout = 15,
        desc = "Cross Wilderness wall - animation end"
    },
    {
        action = { walk = { waypoints = {{x = 3093, y = 3548}, {x = 3103, y = 3567}} } },
        desc = "Walk to Wilderness South mine"
    }
}

Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_GUILD_BANK = {
    {
        action = { walk = { waypoints = {{x = 3032, y = 3339}, {x = 3021, y = 3339}} } },
        desc = "Walk to Mining Guild ladder"
    },
    {
        action = { interact = { object = "Ladder", action = "Climb-down" } },
        wait = { region = {x = 47, y = 152, z = 12184} },
        timeout = 20,
        desc = "Climb down ladder"
    },
    {
        wait = { nearObject = {id = 52856, type = 0, maxDistance = 50} },
        timeout = 10,
        desc = "Wait for resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 16, y = 70, z = 4166} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_MINING_GUILD_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "mining_guild" },
        skip_if = { nearCoord = {x = 3021, y = 9738} },
        desc = "Teleport via Dungeoneering cape"
    }
}

Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "mining_guild" },
        skip_if = { nearCoord = {x = 3021, y = 9738} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 16, y = 70, z = 4166} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_DAEMONHEIM_SOUTHWEST_MINE_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "kalgerion" },
        skip_if = { nearCoord = {x = 3399, y = 3663} },
        desc = "Teleport via Dungeoneering cape"
    }
}

Routes.TO_DAEMONHEIM_BANK = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3449, y = 3717}} } },
        desc = "Walk to Fremennik banker"
    }
}

Routes.TO_DAEMONHEIM_SOUTHEAST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3465, y = 3676}, {x = 3473, y = 3663}} } },
        desc = "Walk to Southeast mine"
    }
}

Routes.TO_DAEMONHEIM_SOUTH_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3441, y = 3666}, {x = 3442, y = 3643}} } },
        desc = "Walk to South mine"
    }
}

Routes.TO_DAEMONHEIM_SOUTHWEST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3441, y = 3667}, {x = 3421, y = 3639}, {x = 3397, y = 3664}} } },
        desc = "Walk to Southwest mine"
    }
}

Routes.TO_DAEMONHEIM_WEST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3442, y = 3657}, {x = 3408, y = 3639}, {x = 3392, y = 3677}, {x = 3393, y = 3714}} } },
        desc = "Walk to West mine"
    }
}

Routes.TO_DAEMONHEIM_NORTHWEST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3442, y = 3669}, {x = 3392, y = 3662}, {x = 3388, y = 3716}, {x = 3399, y = 3755}} } },
        desc = "Walk to Northwest mine"
    }
}

Routes.TO_DAEMONHEIM_EAST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3472, y = 3687}, {x = 3494, y = 3713}, {x = 3504, y = 3734}} } },
        desc = "Walk to East mine"
    }
}

Routes.TO_DAEMONHEIM_NORTHEAST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3472, y = 3687}, {x = 3496, y = 3715}, {x = 3481, y = 3771}} } },
        desc = "Walk to Northeast mine"
    }
}

Routes.TO_DAEMONHEIM_NOVITE_WEST_MINE = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3428, y = 3699}, {x = 3416, y = 3719}} } },
        desc = "Walk to Novite West mine"
    }
}

Routes.TO_DAEMONHEIM_RESOURCE_DUNGEON = {
    {
        action = { teleport = "ringOfKinship" },
        skip_if = { nearCoord = {x = 3449, y = 3696} },
        desc = "Teleport to Daemonheim"
    },
    {
        action = { walk = { waypoints = {{x = 3472, y = 3687}, {x = 3510, y = 3664}} } },
        desc = "Walk to resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { nearCoord = {x = 3498, y = 3633} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_DAEMONHEIM_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE = {
    {
        action = { teleport = "dungeoneeringCape", teleportArg = "daemonheim" },
        skip_if = { nearCoord = {x = 3513, y = 3663} },
        desc = "Teleport via Dungeoneering cape"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { nearCoord = {x = 3498, y = 3633} },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_PRIFDDINAS_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoord = {x = 2208, y = 3360} },
        desc = "Teleport to Prifddinas lodestone"
    }
}

Routes.TO_DEEP_SEA_FISHING_HUB_BANK = {
    {
        action = { teleport = "deepSeaFishingHub" },
        skip_if = { nearCoord = {x = 2135, y = 7107} },
        desc = "Teleport to Deep Sea Fishing Hub"
    }
}

Routes.TO_BURTHORPE_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.BURTHORPE },
        skip_if = { nearCoord = {x = 2899, y = 3544} },
        desc = "Teleport to Burthorpe lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2888, y = 3536}} } },
        desc = "Walk to Burthorpe bank chest"
    }
}

Routes.TO_LUMBRIDGE_FURNACE = {
    {
        action = { lodestone = Teleports.LODESTONES.LUMBRIDGE },
        skip_if = { nearCoord = {x = 3233, y = 3221} },
        desc = "Teleport to Lumbridge lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3227, y = 3254}} } },
        desc = "Walk to Lumbridge furnace"
    }
}

Routes.TO_LUMBRIDGE_MARKET_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.LUMBRIDGE },
        skip_if = { nearCoord = {x = 3233, y = 3221} },
        desc = "Teleport to Lumbridge lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 3213, y = 3257}} } },
        desc = "Walk to Lumbridge Market bank chest"
    }
}

Routes.TO_MAX_GUILD_BANK = {
    {
        action = { teleport = "maxGuild" },
        skip_if = { nearCoord = {x = 2276, y = 3313} },
        desc = "Teleport to Max Guild"
    }
}

Routes.TO_ITHELL_BANK = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoords = {{x = 2208, y = 3360}, {x = 2154, y = 3340}, {x = 2145, y = 3346}} },
        desc = "Teleport to Prifddinas lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2185, y = 3361}, {x = 2171, y = 3345}, {x = 2154, y = 3340}} } },
        skip_if = { nearCoord = {x = 2145, y = 3346} },
        desc = "Walk to Ithell bank"
    },
    {
        action = { walk = { waypoints = {{x = 2154, y = 3340}} } },
        skip_if = { nearCoord = {x = 2154, y = 3340} },
        desc = "Walk to Ithell bank chest"
    }
}

Routes.TO_EDIMMU_CRYSTAL_SANDSTONE = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoord = {x = 2208, y = 3360} },
        desc = "Teleport to Prifddinas lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2208, y = 3384}, {x = 2230, y = 3397}} } },
        desc = "Walk to Edimmu resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 21, y = 72, z = 5448}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    },
    {
        action = { walk = { waypoints = {{x = 1388, y = 4617}} } },
        desc = "Walk to crystal-flecked sandstone"
    }
}

Routes.TO_ITHELL_CRYSTAL_SANDSTONE = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoords = {{x = 2208, y = 3360}, {x = 2153, y = 3340}} },
        desc = "Teleport to Prifddinas lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2185, y = 3361}, {x = 2162, y = 3361}, {x = 2145, y = 3352}} } },
        skip_if = { nearCoord = {x = 2153, y = 3340} },
        desc = "Walk from lodestone to crystal-flecked sandstone"
    },
    {
        action = { walk = { waypoints = {{x = 2145, y = 3352}} } },
        skip_if = { nearCoord = {x = 2145, y = 3352} },
        desc = "Walk to crystal-flecked sandstone"
    }
}

Routes.TO_ITHELL_SOFT_CLAY = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoords = {{x = 2208, y = 3360}, {x = 2153, y = 3340}} },
        desc = "Teleport to Prifddinas lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2185, y = 3361}, {x = 2162, y = 3361}, {x = 2145, y = 3346}} } },
        skip_if = { nearCoord = {x = 2153, y = 3340} },
        desc = "Walk from lodestone to soft clay rocks"
    },
    {
        action = { walk = { waypoints = {{x = 2145, y = 3346}} } },
        skip_if = { nearCoord = {x = 2145, y = 3346} },
        desc = "Walk to soft clay rocks"
    }
}

Routes.TO_PRIFDDINAS_SEREN_STONES = {
    {
        action = { lodestone = Teleports.LODESTONES.PRIFDDINAS },
        skip_if = { nearCoord = {x = 2221, y = 3301} },
        desc = "Teleport to Prifddinas lodestone"
    },
    {
        action = { walk = { waypoints = {{x = 2208, y = 3338}, {x = 2208, y = 3311}, {x = 2219, y = 3301}} } },
        desc = "Walk to Seren stones"
    }
}

Routes.TO_WARS_RETREAT_BANK = {
    {
        action = { teleport = "warsRetreat" },
        skip_if = { nearCoord = {x = 3294, y = 10127} },
        desc = "Teleport to War's Retreat"
    }
}

local RL_ALT = DATA.RESOURCE_LOCATOR.ALTERNATE_ROUTES

Routes.TO_LUMBRIDGE_SE_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.lumbridge_se },
        desc = "Locator teleport to Lumbridge SE"
    }
}

Routes.TO_LUMBRIDGE_SW_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.lumbridge_sw },
        desc = "Locator teleport to Lumbridge SW"
    }
}

Routes.TO_VARROCK_SW_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.varrock_sw },
        desc = "Locator teleport to Varrock SW"
    }
}

Routes.TO_VARROCK_SE_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.varrock_se },
        desc = "Locator teleport to Varrock SE"
    }
}

Routes.TO_AL_KHARID_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.al_kharid },
        desc = "Locator teleport near Al Kharid"
    },
    {
        action = { walk = { waypoints = {{x = 3300, y = 3294}} } },
        skip_if = { nearCoord = {x = 3300, y = 3294} },
        desc = "Walk to Al Kharid mine"
    }
}

Routes.TO_AL_KHARID_GEM_ROCKS_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.al_kharid_gem_rocks },
        desc = "Locator teleport near Al Kharid"
    },
    {
        action = { walk = { waypoints = {{x = 3299, y = 3313}} } },
        skip_if = { nearCoord = {x = 3299, y = 3313} },
        desc = "Walk to gem rocks"
    }
}

Routes.TO_AL_KHARID_RESOURCE_DUNGEON_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.al_kharid_resource_dungeon },
        desc = "Locator teleport near Al Kharid"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { region = {x = 18, y = 70, z = 4678}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    }
}

Routes.TO_RIMMINGTON_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.rimmington },
        desc = "Locator teleport to Rimmington"
    }
}

Routes.TO_KARAMJA_VOLCANO_MINE_VIA_LOCATOR = {
    {
        action = { teleport = "resourceLocatorRoute", teleportArg = RL_ALT.karamja_volcano },
        desc = "Locator teleport to Karamja Volcano"
    }
}

Routes.TO_DM_RD_DEPOSIT_BOX = {
    {
        action = { walk = { waypoints = {{x = 1042, y = 4578}} } },
        skip_if = { nearCoord = {x = 1042, y = 4578, maxDistance = 10} },
        desc = "Walk to deposit box"
    }
}

Routes.TO_DM_RD_DEPOSIT_BOX_FROM_GOLD = {
    {
        action = { walk = { waypoints = {{x = 1043, y = 4577}} } },
        desc = "Walk to deposit box"
    }
}

Routes.TO_DM_RD_DEPOSIT_BOX_FROM_DM = {
    {
        action = { walk = { waypoints = {{x = 3034, y = 9772}} } },
        skip_if = { nearCoord = {x = 3034, y = 9772} },
        desc = "Walk to resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { coord = {x = 1041, y = 4575}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    },
    {
        action = { walk = { waypoints = {{x = 1042, y = 4578}} } },
        skip_if = { nearCoord = {x = 1042, y = 4578, maxDistance = 10} },
        desc = "Walk to deposit box"
    }
}

Routes.TO_DM_RD_DEPOSIT_BOX_FROM_DM_COAL = {
    {
        action = { walk = { waypoints = {{x = 3042, y = 9796}, {x = 3034, y = 9772}} } },
        skip_if = { nearCoord = {x = 3034, y = 9772} },
        desc = "Walk to resource dungeon entrance"
    },
    {
        action = { interact = { object = "Mysterious entrance", action = "Enter" } },
        wait = { coord = {x = 1041, y = 4575}, anim = 0 },
        timeout = 20,
        desc = "Enter resource dungeon"
    },
    {
        action = { walk = { waypoints = {{x = 1042, y = 4578}} } },
        skip_if = { nearCoord = {x = 1042, y = 4578, maxDistance = 10} },
        desc = "Walk to deposit box"
    }
}

Routes.TO_DWARVEN_MINE_FROM_RD = {
    {
        action = { interact = { object = "Mysterious door", action = "Exit" } },
        wait = { region = {x = 47, y = 152, z = 12184}, anim = 0 },
        timeout = 20,
        desc = "Exit resource dungeon"
    }
}

return Routes
