local Routes = require("aio mining/mining_routes")

local MINING_LOCATIONS = {
    empty_throne_room = {
        name = "Empty Throne Room",
        route = Routes.TO_EMPTY_THRONE_ROOM,
        ores = {"dark_animica"},
        oreCoords = {
            dark_animica = {x = 2878, y = 12638}
        }
    },

    anachronia_swamp = {
        name = "Anachronia Swamp",
        route = Routes.TO_ANACHRONIA_SWAMP,
        ores = {"dark_animica"},
        oreCoords = {
            dark_animica = {x = 5616, y = 2172}
        },
        requiredLevels = {
            {skill = "SLAYER", level = 99},
            {skill = "COMBAT", level = 120}
        }
    },

    anachronia_sw = {
        name = "Anachronia South-West",
        route = Routes.TO_ANACHRONIA_SW,
        ores = {"light_animica"},
        oreCoords = {
            light_animica = {x = 5340, y = 2255}
        }
    },

    al_kharid = {
        name = "Al Kharid",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_AL_KHARID_MINE_VIA_DUNGEONEERING_CAPE },
            { condition = { archJournal = true }, route = Routes.TO_AL_KHARID_MINE_VIA_ARCH_JOURNAL },
            { route = Routes.TO_AL_KHARID_MINE }
        },
        ores = {"gold", "silver"},
        oreCoords = {
            gold = {x = 3302, y = 3290},
            silver = {x = 3299, y = 3298}
        }
    },

    al_kharid_resource_dungeon = {
        name = "Al Kharid Resource Dungeon",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_AL_KHARID_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE },
            { condition = { archJournal = true }, route = Routes.TO_AL_KHARID_RESOURCE_DUNGEON_VIA_ARCH_JOURNAL },
            { route = Routes.TO_AL_KHARID_RESOURCE_DUNGEON }
        },
        ores = {"drakolith", "necrite"},
        oreCoords = {
            drakolith = {x = 1175, y = 4516},
            necrite = {x = 1191, y = 4513}
        },
        requiredLevels = {{skill = "DUNGEONEERING", level = 75}}
    },

    varrock_sw = {
        name = "Varrock South-West",
        route = Routes.TO_VARROCK_SW_MINE,
        ores = {"copper", "tin", "iron", "mithril"},
        oreCoords = {
            copper = {x = 3177, y = 3366},
            tin = {x = 3177, y = 3370},
            iron = {x = 3181, y = 3373},
            mithril = {x = 3182, y = 3377}
        }
    },

    varrock_se = {
        name = "Varrock South-East",
        skip_if = { nearCoord = {x = 3287, y = 3365} },
        routeOptions = {
            { condition = { archJournal = true }, route = Routes.TO_VARROCK_SE_MINE_VIA_ARCH_JOURNAL },
            { route = Routes.TO_VARROCK_SE_MINE }
        },
        ores = {"copper", "tin", "mithril", "adamant"},
        oreCoords = {
            copper = {x = 3286, y = 3369},
            tin = {x = 3287, y = 3367},
            mithril = {x = 3283, y = 3366},
            adamant = {x = 3289, y = 3361}
        }
    },

    lumbridge_se = {
        name = "Lumbridge South-East",
        route = Routes.TO_LUMBRIDGE_SE_MINE,
        ores = {"copper", "tin"},
        oreCoords = {
            copper = {x = 3231, y = 3149},
            tin = {x = 3227, y = 3147}
        }
    },

    lumbridge_sw = {
        name = "Lumbridge South-West",
        route = Routes.TO_LUMBRIDGE_SW_MINE,
        ores = {"iron", "coal"},
        oreCoords = {
            iron = {x = 3145, y = 3147},
            coal = {x = 3147, y = 3145}
        }
    },

    rimmington = {
        name = "Rimmington",
        route = Routes.TO_RIMMINGTON_MINE,
        ores = {"copper", "tin", "adamant", "gold"},
        oreCoords = {
            copper = {x = 2969, y = 3234},
            tin = {x = 2969, y = 3238},
            adamant = {x = 2977, y = 3232},
            gold = {x = 2980, y = 3239}
        }
    },

    karamja_volcano = {
        name = "Karamja Volcano",
        route = Routes.TO_KARAMJA_VOLCANO_MINE,
        ores = {"runite"},
        oreCoords = {
            runite = {x = 2860, y = 9577}
        },
        requiredLevels = {{skill = "DUNGEONEERING", level = 99}},
        danger = {minCombat = 31}
    },

    lletya = {
        name = "Lletya",
        route = Routes.TO_LLETYA_MINE,
        ores = {"light_animica"},
        oreCoords = {
            light_animica = {x = 2279, y = 3160}
        }
    },

    dwarven_mine = {
        name = "Dwarven Mine",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_DWARVEN_MINE_VIA_DUNGEONEERING_CAPE },
            { route = Routes.TO_DWARVEN_MINE }
        },
        ores = {"iron", "coal", "luminite"},
        oreCoords = {
            iron = {x = 3050, y = 9782},
            coal = {x = 3052, y = 9816},
            luminite = {x = 3038, y = 9762}
        },
        oreWaypoints = {
            iron = {{x = 3049, y = 9782}},
            coal = {{x = 3043, y = 9791}, {x = 3051, y = 9815}},
            luminite = {{x = 3038, y = 9763}}
        },
        danger = {minCombat = 45}
    },

    dwarven_resource_dungeon = {
        name = "Dwarven Resource Dungeon",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_DWARVEN_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE },
            { route = Routes.TO_DWARVEN_RESOURCE_DUNGEON }
        },
        ores = {"mithril", "gold"},
        oreCoords = {
            mithril = {x = 1047, y = 4577},
            gold = {x = 1063, y = 4574}
        },
        oreWaypoints = {
            gold = {{x = 1064, y = 4573}}
        },
        requiredLevels = {{skill = "DUNGEONEERING", level = 15}},
        danger = {minCombat = 45}
    },

    mining_guild = {
        name = "Mining Guild",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_MINING_GUILD_VIA_DUNGEONEERING_CAPE },
            { condition = { nearCoord = {x = 3061, y = 3340} }, route = Routes.TO_MINING_GUILD_FROM_ARTISANS_GUILD_BANK },
            { condition = { region = {x = 47, y = 52, z = 12084} }, route = Routes.TO_MINING_GUILD_FROM_ARTISANS_WORKSHOP },
            { route = Routes.TO_MINING_GUILD }
        },
        ores = {"coal", "runite", "orichalcite"},
        oreCoords = {
            coal = {x = 3044, y = 9747},
            runite = {x = 3032, y = 9738},
            orichalcite = {x = 3044, y = 9735}
        },
        oreWaypoints = {
            runite = {{x = 3032, y = 9738}},
            orichalcite = {{x = 3044, y = 9734}},
            coal = {{x = 3045, y = 9748}}
        },
        requiredLevels = {{skill = "MINING", level = 60}}
    },

    mining_guild_resource_dungeon = {
        name = "Mining Guild Resource Dungeon",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE },
            { condition = { nearCoord = {x = 3061, y = 3340} }, route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_GUILD_BANK },
            { condition = { region = {x = 47, y = 52, z = 12084} }, route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON_FROM_ARTISANS_WORKSHOP },
            { route = Routes.TO_MINING_GUILD_RESOURCE_DUNGEON }
        },
        ores = {"luminite", "drakolith"},
        oreCoords = {
            luminite = {x = 1052, y = 4514},
            drakolith = {x = 1059, y = 4514}
        },
        requiredLevels = {
            {skill = "MINING", level = 60},
            {skill = "DUNGEONEERING", level = 45}
        }
    },

    wilderness_volcano = {
        name = "Wilderness Volcano",
        route = Routes.TO_WILDERNESS_VOLCANO_MINE,
        ores = {"drakolith"},
        oreCoords = {
            drakolith = {x = 3185, y = 3632}
        }
    },

    wilderness_hobgoblin = {
        name = "Wilderness Hobgoblin",
        route = Routes.TO_WILDERNESS_HOBGOBLIN_MINE,
        ores = {"necrite"},
        oreCoords = {
            necrite = {x = 3032, y = 3799}
        }
    },

    wilderness_pirates_hideout = {
        name = "Wilderness Pirates Hideout",
        routeOptions = {
            { condition = { slayerCape = true }, route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT_VIA_SLAYER_CAPE },
            { route = Routes.TO_WILDERNESS_PIRATES_HIDEOUT }
        },
        ores = {"banite"},
        oreCoords = {
            banite = {x = 3059, y = 3946}
        }
    },

    wilderness_south = {
        name = "Wilderness South",
        route = Routes.TO_WILDERNESS_SOUTH_MINE,
        ores = {"runite"},
        oreCoords = {
            runite = {x = 3103, y = 3568}
        }
    },

    wilderness_south_west = {
        name = "Wilderness South-West",
        route = Routes.TO_WILDERNESS_SOUTH_WEST_MINE,
        ores = {"orichalcite"},
        oreCoords = {
            orichalcite = {x = 3018, y = 3592}
        },
        danger = {}
    },

    port_phasmatys_south = {
        name = "Port Phasmatys South",
        route = Routes.TO_PORT_PHASMATYS_SOUTH_MINE,
        ores = {"phasmatite"},
        oreCoords = {
            phasmatite = {x = 3690, y = 3397}
        }
    },

    piscatoris_south = {
        name = "Piscatoris South",
        route = Routes.TO_PISCATORIS_SOUTH_MINE,
        ores = {"platinum", "iron"},
        oreCoords = {
            platinum = {x = 2333, y = 3640},
            iron = {x = 2338, y = 3643}
        }
    },

    daemonheim_southeast = {
        name = "Daemonheim Southeast",
        route = Routes.TO_DAEMONHEIM_SOUTHEAST_MINE,
        ores = {"fractite", "bathus"},
        oreCoords = {
            fractite = {x = 3473, y = 3662},
            bathus = {x = 3473, y = 3664}
        }
    },

    daemonheim_south = {
        name = "Daemonheim South",
        route = Routes.TO_DAEMONHEIM_SOUTH_MINE,
        ores = {"kratonium", "novite"},
        oreCoords = {
            kratonium = {x = 3443, y = 3642},
            novite = {x = 3440, y = 3644}
        }
    },

    daemonheim_southwest = {
        name = "Daemonheim Southwest",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_DAEMONHEIM_SOUTHWEST_MINE_VIA_DUNGEONEERING_CAPE },
            { route = Routes.TO_DAEMONHEIM_SOUTHWEST_MINE }
        },
        ores = {"argonite", "katagon"},
        oreCoords = {
            argonite = {x = 3397, y = 3666},
            katagon = {x = 3398, y = 3662}
        }
    },

    daemonheim_west = {
        name = "Daemonheim West",
        route = Routes.TO_DAEMONHEIM_WEST_MINE,
        ores = {"zephyrium"},
        oreCoords = {
            zephyrium = {x = 3393, y = 3714}
        }
    },

    daemonheim_northwest = {
        name = "Daemonheim Northwest",
        route = Routes.TO_DAEMONHEIM_NORTHWEST_MINE,
        ores = {"promethium", "fractite"},
        oreCoords = {
            promethium = {x = 3401, y = 3757},
            fractite = {x = 3399, y = 3752}
        }
    },

    daemonheim_east = {
        name = "Daemonheim East",
        route = Routes.TO_DAEMONHEIM_EAST_MINE,
        ores = {"marmaros", "gorgonite"},
        oreCoords = {
            marmaros = {x = 3503, y = 3732},
            gorgonite = {x = 3503, y = 3736}
        }
    },

    daemonheim_northeast = {
        name = "Daemonheim Northeast",
        route = Routes.TO_DAEMONHEIM_NORTHEAST_MINE,
        ores = {"bathus"},
        oreCoords = {
            bathus = {x = 3478, y = 3771}
        }
    },

    daemonheim_novite_west = {
        name = "Daemonheim Novite West",
        route = Routes.TO_DAEMONHEIM_NOVITE_WEST_MINE,
        ores = {"novite"},
        oreCoords = {
            novite = {x = 3416, y = 3720}
        }
    },

    daemonheim_resource_dungeon = {
        name = "Daemonheim Resource Dungeon",
        routeOptions = {
            { condition = { dungeoneeringCape = true }, route = Routes.TO_DAEMONHEIM_RESOURCE_DUNGEON_VIA_DUNGEONEERING_CAPE },
            { route = Routes.TO_DAEMONHEIM_RESOURCE_DUNGEON }
        },
        ores = {"promethium"},
        oreCoords = {
            promethium = {x = 3494, y = 3633}
        },
        requiredLevels = {{skill = "DUNGEONEERING", level = 30}}
    }
}

return MINING_LOCATIONS
