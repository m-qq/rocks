local Routes = require("aio mining/mining_routes")

local MINING_LOCATIONS = {
    empty_throne_room = {
        name = "Empty Throne Room",
        region = {x = 44, y = 197, z = 11461},
        route = Routes.TO_EMPTY_THRONE_ROOM,
        ores = {"dark_animica"}
    },

    anachronia_sw = {
        name = "Anachronia South-West",
        region = {x = 83, y = 35, z = 21283},
        route = Routes.TO_ANACHRONIA_SW,
        ores = {"light_animica"}
    },

    al_kharid = {
        name = "Al Kharid",
        region = {x = 51, y = 51, z = 13107},
        route = Routes.TO_AL_KHARID_MINE,
        ores = {"gold", "silver"}
    },

    al_kharid_resource_dungeon = {
        name = "Al Kharid Resource Dungeon",
        region = {x = 18, y = 70, z = 4678},
        route = Routes.TO_AL_KHARID_RESOURCE_DUNGEON,
        ores = {"drakolith", "necrite"},
        requiredLevels = {{skill = "DUNGEONEERING", level = 75}}
    },

    varrock_sw = {
        name = "Varrock South-West",
        region = {x = 49, y = 52, z = 12596},
        route = Routes.TO_VARROCK_SW_MINE,
        ores = {"copper", "tin", "iron", "mithril"}
    },

    varrock_se = {
        name = "Varrock South-East",
        region = {x = 51, y = 52, z = 13108},
        route = Routes.TO_VARROCK_SE_MINE,
        ores = {"copper", "tin", "mithril", "adamant"}
    },

    lumbridge_se = {
        name = "Lumbridge South-East",
        region = {x = 50, y = 49, z = 12849},
        route = Routes.TO_LUMBRIDGE_SE_MINE,
        ores = {"copper", "tin"}
    },

    lumbridge_sw = {
        name = "Lumbridge South-West",
        region = {x = 49, y = 49, z = 12593},
        route = Routes.TO_LUMBRIDGE_SW_MINE,
        ores = {"iron", "coal"}
    },

    rimmington = {
        name = "Rimmington",
        region = {x = 46, y = 50, z = 11826},
        route = Routes.TO_RIMMINGTON_MINE,
        ores = {"copper", "tin", "adamant", "gold"}
    },

    dwarven_mine = {
        name = "Dwarven Mine",
        route = Routes.TO_DWARVEN_MINE,
        ores = {"iron", "coal", "luminite"},
        oreWaypoints = {
            iron = {{x = 3049, y = 9782}},
            coal = {{x = 3043, y = 9791}, {x = 3051, y = 9815}},
            luminite = {{x = 3038, y = 9763}}
        },
        oreRegions = {
            iron = {x = 47, y = 152, z = 12184},
            coal = {x = 47, y = 153, z = 12185},
            luminite = {x = 47, y = 152, z = 12184}
        }
    },

    dwarven_resource_dungeon = {
        name = "Dwarven Resource Dungeon",
        region = {x = 16, y = 71, z = 4167},
        route = Routes.TO_DWARVEN_RESOURCE_DUNGEON,
        ores = {"mithril", "gold"},
        oreWaypoints = {
            gold = {{x = 1064, y = 4573}}
        },
        requiredLevels = {{skill = "DUNGEONEERING", level = 15}}
    },

    mining_guild = {
        name = "Mining Guild",
        region = {x = 47, y = 152, z = 12184},
        routeOptions = {
            { condition = { nearCoord = {x = 3061, y = 3340} }, route = Routes.TO_MINING_GUILD_FROM_ARTISANS_GUILD_BANK },
            { condition = { region = {x = 47, y = 52, z = 12084} }, route = Routes.TO_MINING_GUILD_FROM_ARTISANS_WORKSHOP },
            { route = Routes.TO_MINING_GUILD }
        },
        ores = {"coal", "runite", "orichalcite"},
        oreWaypoints = {
            runite = {{x = 3032, y = 9738}},
            orichalcite = {{x = 3044, y = 9734}},
            coal = {{x = 3045, y = 9748}}
        },
        requiredLevels = {{skill = "MINING", level = 60}}
    },

    mining_guild_resource_dungeon = {
        name = "Mining Guild Resource Dungeon",
        region = {x = 16, y = 70, z = 4166},
        routeOptions = {
            { condition = { nearCoord = {x = 3061, y = 3340} }, route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_GUILD_BANK },
            { condition = { region = {x = 47, y = 52, z = 12084} }, route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_WORKSHOP },
            { route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON }
        },
        ores = {"luminite", "drakolith"},
        requiredLevels = {
            {skill = "MINING", level = 60},
            {skill = "DUNGEONEERING", level = 45}
        }
    },

    wilderness_volcano = {
        name = "Wilderness Volcano",
        region = {x = 49, y = 56, z = 12600},
        route = Routes.TO_WILDERNESS_VOLCANO_MINE,
        ores = {"drakolith"}
    },

    wilderness_hobgoblin = {
        name = "Wilderness Hobgoblin",
        region = {x = 47, y = 59, z = 12091},
        route = Routes.TO_WILDERNESS_HOBGOBLIN_MINE,
        ores = {"necrite"}
    },

    wilderness_pirates_hideout = {
        name = "Wilderness Pirates Hideout",
        region = {x = 47, y = 61, z = 12093},
        route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT,
        ores = {"banite"}
    },

    wilderness_south = {
        name = "Wilderness South",
        region = {x = 48, y = 55, z = 12343},
        route = Routes.TO_WILDERNESS_SOUTH_MINE,
        ores = {"runite"}
    },

    wilderness_south_west = {
        name = "Wilderness South-West",
        region = {x = 47, y = 56, z = 12088},
        route = Routes.TO_WILDERNESS_SOUTH_WEST_MINE,
        ores = {"orichalcite"}
    },

    port_phasmatys_south = {
        name = "Port Phasmatys South",
        region = {x = 57, y = 53, z = 14645},
        route = Routes.TO_PORT_PHASMATYS_SOUTH_MINE,
        ores = {"phasmatite"}
    },

    piscatoris_south = {
        name = "Piscatoris South",
        region = {x = 36, y = 56, z = 9272},
        route = Routes.TO_PISCATORIS_SOUTH_MINE,
        ores = {"platinum", "iron"}
    },

    daemonheim_southeast = {
        name = "Daemonheim Southeast",
        region = {x = 54, y = 57, z = 13881},
        route = Routes.TO_DAEMONHEIM_SOUTHEAST_MINE,
        ores = {"fractite", "bathus"}
    },

    daemonheim_south = {
        name = "Daemonheim South",
        region = {x = 53, y = 56, z = 13624},
        route = Routes.TO_DAEMONHEIM_SOUTH_MINE,
        ores = {"kratonium", "novite"}
    },

    daemonheim_southwest = {
        name = "Daemonheim Southwest",
        region = {x = 53, y = 57, z = 13625},
        route = Routes.TO_DAEMONHEIM_SOUTHWEST_MINE,
        ores = {"argonite", "katagon"}
    },

    daemonheim_west = {
        name = "Daemonheim West",
        region = {x = 53, y = 58, z = 13626},
        route = Routes.TO_DAEMONHEIM_WEST_MINE,
        ores = {"zephyrium"}
    },

    daemonheim_northwest = {
        name = "Daemonheim Northwest",
        region = {x = 53, y = 58, z = 13626},
        route = Routes.TO_DAEMONHEIM_NORTHWEST_MINE,
        ores = {"promethium", "fractite"}
    },

    daemonheim_east = {
        name = "Daemonheim East",
        region = {x = 54, y = 58, z = 13882},
        route = Routes.TO_DAEMONHEIM_EAST_MINE,
        ores = {"marmaros", "gorgonite"}
    },

    daemonheim_northeast = {
        name = "Daemonheim Northeast",
        region = {x = 54, y = 58, z = 13882},
        route = Routes.TO_DAEMONHEIM_NORTHEAST_MINE,
        ores = {"bathus"}
    },

    daemonheim_novite_west = {
        name = "Daemonheim Novite West",
        region = {x = 53, y = 58, z = 13626},
        route = Routes.TO_DAEMONHEIM_NOVITE_WEST_MINE,
        ores = {"novite"}
    },

    daemonheim_resource_dungeon = {
        name = "Daemonheim Resource Dungeon",
        region = {x = 54, y = 56, z = 13880},
        route = Routes.TO_DAEMONHEIM_RESOURCE_DUNGEON,
        ores = {"promethium"},
        requiredLevels = {{skill = "DUNGEONEERING", level = 30}}
    }
}

return MINING_LOCATIONS
