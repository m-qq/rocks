local ORES = {

    copper = {
        name = "Copper rock",
        action = "Mine",
        oreIds = {436},
        tier = 1,
        vbInBox = 43188,
        oresomeKey = "COPPER",
        capacityBoostLevel = 7
    },
    tin = {
        name = "Tin rock",
        action = "Mine",
        oreIds = {438},
        tier = 1,
        vbInBox = 43190,
        oresomeKey = "TIN",
        capacityBoostLevel = 7
    },

    iron = {
        name = "Iron rock",
        action = "Mine",
        oreIds = {440},
        tier = 10,
        vbInBox = 43192,
        oresomeKey = "IRON",
        capacityBoostLevel = 18
    },

    coal = {
        name = "Coal rock",
        action = "Mine",
        oreIds = {453},
        tier = 20,
        vbInBox = 43194,
        oresomeKey = "COAL",
        capacityBoostLevel = 29
    },
    silver = {
        name = "Silver rock",
        action = "Mine",
        oreIds = {442},
        tier = 20,
        vbInBox = 43196,
        oresomeKey = nil,
        capacityBoostLevel = nil
    },
    common_gem_rock = {
        name = "Common gem rock",
        action = "Mine",
        oreIds = {1625, 1627, 1629, 21345, 1633},
        oreNames = {[1625] = "Uncut opal", [1627] = "Uncut jade", [1629] = "Uncut red topaz", [21345] = "Uncut lapis lazuli", [1633] = "Crushed gem"},
        cutIds = {1609, 1611, 1613, 21346},
        tier = 1,
        isGemRock = true,
        noGemBag = true
    },
    uncommon_gem_rock = {
        name = "Uncommon gem rock",
        action = "Mine",
        oreIds = {1623, 1621, 1619},
        oreNames = {[1623] = "Uncut sapphire", [1621] = "Uncut emerald", [1619] = "Uncut ruby"},
        cutIds = {1607, 1605, 1603},
        tier = 20,
        isGemRock = true
    },
    precious_gem_rock = {
        name = "Precious gem rock",
        action = "Mine",
        oreIds = {1621, 1619, 1617},
        oreNames = {[1621] = "Uncut emerald", [1619] = "Uncut ruby", [1617] = "Uncut diamond"},
        cutIds = {1605, 1603, 1601},
        tier = 25,
        isGemRock = true
    },

    mithril = {
        name = "Mithril rock",
        action = "Mine",
        oreIds = {447},
        tier = 30,
        vbInBox = 43198,
        oresomeKey = "MITHRIL",
        capacityBoostLevel = 37
    },

    adamant = {
        name = "Adamantite rock",
        action = "Mine",
        oreIds = {449},
        tier = 40,
        vbInBox = 43200,
        oresomeKey = "ADAMANTITE",
        capacityBoostLevel = 41
    },
    luminite = {
        name = "Luminite rock",
        action = "Mine",
        oreIds = {44820},
        tier = 40,
        vbInBox = 43202,
        oresomeKey = "LUMINITE",
        capacityBoostLevel = 41
    },
    gold = {
        name = "Gold rock",
        action = "Mine",
        oreIds = {444},
        tier = 40,
        vbInBox = 43204,
        oresomeKey = nil,
        capacityBoostLevel = nil
    },
    concentrated_gold = {
        name = "Concentrated gold deposit",
        action = "Mine",
        oreIds = {444},
        tier = 80,
        vbInBox = 43204,
        oresomeKey = nil,
        capacityBoostLevel = nil,
        noRockertunities = true,
        interactClosest = true
    },
    concentrated_coal = {
        name = "Concentrated coal deposit",
        action = "Mine",
        oreIds = {453},
        tier = 70,
        vbInBox = 43194,
        oresomeKey = "COAL",
        capacityBoostLevel = 29,
        noRockertunities = true,
        interactClosest = true
    },

    runite = {
        name = "Runite rock",
        action = "Mine",
        oreIds = {451},
        tier = 50,
        vbInBox = 43206,
        oresomeKey = "RUNITE",
        capacityBoostLevel = 55
    },

    orichalcite = {
        name = "Orichalcite rock",
        action = "Mine",
        oreIds = {44822},
        tier = 60,
        vbInBox = 43208,
        oresomeKey = "ORICHALCITE",
        capacityBoostLevel = 66
    },
    drakolith = {
        name = "Drakolith rock",
        action = "Mine",
        oreIds = {44824},
        tier = 60,
        vbInBox = 43210,
        oresomeKey = "DRAKOLITH",
        capacityBoostLevel = 66
    },

    necrite = {
        name = "Necrite rock",
        action = "Mine",
        oreIds = {44826},
        tier = 70,
        vbInBox = 43212,
        oresomeKey = "NECRITE",
        capacityBoostLevel = 72
    },
    phasmatite = {
        name = "Phasmatite rock",
        action = "Mine",
        oreIds = {44828},
        tier = 70,
        vbInBox = 43214,
        oresomeKey = "PHASMATITE",
        capacityBoostLevel = 72
    },

    banite = {
        name = "Banite rock",
        action = "Mine",
        oreIds = {21778},
        tier = 80,
        vbInBox = 43216,
        oresomeKey = "BANE",
        capacityBoostLevel = 85
    },

    light_animica = {
        name = "Light animica rock",
        action = "Mine",
        oreIds = {44830},
        tier = 90,
        vbInBox = 43218,
        oresomeKey = "LIGHT_ANIMICA",
        capacityBoostLevel = 95
    },
    dark_animica = {
        name = "Dark animica rock",
        action = "Mine",
        oreIds = {44832},
        tier = 90,
        vbInBox = 43220,
        oresomeKey = "DARK_ANIMICA",
        capacityBoostLevel = 95
    },

    novite = {
        name = "Novite rock",
        action = "Mine",
        oreIds = {57175},
        tier = 100,
        vbInBox = 55880,
        oresomeKey = "NOVITE",
        capacityBoostLevel = 102,
    },
    bathus = {
        name = "Bathus rock",
        action = "Mine",
        oreIds = {57177},
        tier = 100,
        vbInBox = 55883,
        oresomeKey = "BATHUS",
        capacityBoostLevel = 102,
    },
    marmaros = {
        name = "Marmaros rock",
        action = "Mine",
        oreIds = {57179},
        tier = 100,
        vbInBox = 55886,
        oresomeKey = "MARMAROS",
        capacityBoostLevel = 102,
        rockertunityDist = {
            [130805] = math.sqrt(2),
        },
    },
    kratonium = {
        name = "Kratonium rock",
        action = "Mine",
        oreIds = {57181},
        tier = 100,
        vbInBox = 55889,
        oresomeKey = "KRATONIUM",
        capacityBoostLevel = 102,
    },
    fractite = {
        name = "Fractite rock",
        action = "Mine",
        oreIds = {57183},
        tier = 100,
        vbInBox = 55892,
        oresomeKey = "FRACTITE",
        capacityBoostLevel = 102,
    },
    zephyrium = {
        name = "Zephyrium rock",
        action = "Mine",
        oreIds = {57185},
        tier = 100,
        vbInBox = 55895,
        oresomeKey = "ZEPHYRIUM",
        capacityBoostLevel = 102,
    },
    argonite = {
        name = "Argonite rock",
        action = "Mine",
        oreIds = {57187},
        tier = 100,
        vbInBox = 55898,
        oresomeKey = "ARGONITE",
        capacityBoostLevel = 102,
    },
    katagon = {
        name = "Katagon rock",
        action = "Mine",
        oreIds = {57189},
        tier = 100,
        vbInBox = 55901,
        oresomeKey = "KATAGON",
        capacityBoostLevel = 102,
    },
    gorgonite = {
        name = "Gorgonite rock",
        action = "Mine",
        oreIds = {57191},
        tier = 100,
        vbInBox = 55904,
        oresomeKey = "GORGONITE",
        capacityBoostLevel = 102,
        rockertunityDist = {
            [130793] = math.sqrt(2),
        },
    },
    promethium = {
        name = "Promethium rock",
        action = "Mine",
        oreIds = {57193},
        tier = 100,
        vbInBox = 55907,
        oresomeKey = "PROMETHIUM",
        capacityBoostLevel = 102,
    },

    platinum = {
        name = "Platinum rock",
        action = "Mine",
        oreIds = {59207},
        tier = 104,
        vbInBox = 58113,
        oresomeKey = nil,
        capacityBoostLevel = nil
    },
    crystal_sandstone = {
        name = "Crystal-flecked sandstone",
        action = "Mine",
        oreIds = {32847},
        oreNames = {[32847] = "Crystal-flecked sandstone"},
        tier = 81,
        noOreBox = true,
        noRockertunities = true,
        noStamina = true,
    },
    soft_clay = {
        name = "Soft clay rock",
        action = "Mine",
        oreIds = {1761},
        oreNames = {[1761] = "Soft clay"},
        tier = 75,
        noOreBox = true,
        noRockertunities = true,
    },

    seren_stones = {
        name = "Seren stone",
        action = "Mine",
        oreIds = {32262},
        oreNames = {[32262] = "Corrupted ore"},
        tier = 89,
        isStackable = true,
        noStamina = true,
        noOreBox = true,
        noRockertunities = true,
    },
}

return ORES
