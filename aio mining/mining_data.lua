local DATA = {}

DATA.ROCKERTUNITY_IDS = {7164, 7165}
DATA.ARCH_JOURNAL_ID = 49429
DATA.RING_OF_KINSHIP_ID = 15707
DATA.MEMORY_STRAND_ID = 39486
DATA.SENNTISTEN_SCROLL_ID = 39018

DATA.SLAYER_CAPE_IDS = {9786, 9787, 34274, 34275, 53810, 53839, 31282, 53782}
DATA.DUNGEONEERING_CAPE_IDS = {18508, 18509, 34294, 34295, 53820, 53849, 19709, 53792}

-- Magic Golem outfit (prevents Living Rock Creatures aggression)
DATA.MAGIC_GOLEM_OUTFIT = {
    head = 31590,
    torso = 31591,
    legs = 31592,
    gloves = 31593,
    boots = 31594
}

DATA.ALL_SKILLS = {
    "ATTACK", "STRENGTH", "RANGED", "MAGIC", "DEFENCE", "CONSTITUTION",
    "PRAYER", "SUMMONING", "DUNGEONEERING", "AGILITY", "THIEVING", "SLAYER",
    "HUNTER", "SMITHING", "CRAFTING", "FLETCHING", "HERBLORE", "RUNECRAFTING",
    "COOKING", "CONSTRUCTION", "FIREMAKING", "WOODCUTTING", "FARMING",
    "FISHING", "MINING", "DIVINATION", "INVENTION", "ARCHAEOLOGY", "NECROMANCY"
}

DATA.DUNGEONEERING_ORES = {
    "novite", "bathus", "marmaros", "kratonium", "fractite",
    "zephyrium", "argonite", "katagon", "gorgonite", "promethium"
}

DATA.VARBIT_IDS = {
    MINING_PROGRESS = 43187,
    AUTO_RETALIATE = 42166,
    COMBAT_LEVEL = 9611,
    POF_BANK_UNLOCKED = 41690,
    WARS_RETREAT_UNLOCKED = 45680,
    ALTAR_OF_WAR_UNLOCKED = 45682,
    GOTE_PORTAL_1 = 25054,
    GOTE_PORTAL_2 = 25055,
    SUMMONING_POINTS = 31524,

    ORESOME = {
        COPPER = 43189,
        TIN = 43191,
        IRON = 43193,
        COAL = 43195,
        MITHRIL = 43199,
        ADAMANTITE = 43201,
        LUMINITE = 43203,
        RUNITE = 43207,
        ORICHALCITE = 43209,
        DRAKOLITH = 43211,
        NECRITE = 43213,
        PHASMATITE = 43215,
        BANE = 43217,
        LIGHT_ANIMICA = 43219,
        DARK_ANIMICA = 43221
    },

    STILL_ORESOME = {
        NOVITE = 55881,
        BATHUS = 55884,
        MARMAROS = 55887,
        KRATONIUM = 55890,
        FRACTITE = 55893,
        ZEPHYRIUM = 55896,
        ARGONITE = 55899,
        KATAGON = 55902,
        GORGONITE = 55905,
        PROMETHIUM = 55908
    }
}

DATA.GEODES = {
    {id = 44816, name = "Sedimentary geode"},  
    {id = 44817, name = "Igneous geode"},     
    {id = 44818, name = "Metamorphic geode"}  
}

DATA.ORE_BOX_INFO = {
    [44779] = {name = "Bronze ore box",     maxTier = 1},
    [44781] = {name = "Iron ore box",       maxTier = 10},
    [44783] = {name = "Steel ore box",      maxTier = 20},
    [44785] = {name = "Mithril ore box",    maxTier = 30},
    [44787] = {name = "Adamant ore box",    maxTier = 40},
    [44789] = {name = "Rune ore box",       maxTier = 50},
    [44791] = {name = "Orikalkum ore box",  maxTier = 60},
    [44793] = {name = "Necronium ore box",  maxTier = 70},
    [44795] = {name = "Bane ore box",       maxTier = 80},
    [44797] = {name = "Elder rune ore box", maxTier = 90},
    [57172] = {name = "Primal ore box",     maxTier = 104}
}

DATA.ORE_BOX_BASE_CAPACITY = 100
DATA.MINING_LEVEL_BONUS = 20
DATA.ORESOME_BONUS = 20
DATA.STILL_ORESOME_BONUS = 10

DATA.INTERFACES = {
    LODESTONE_NETWORK = { { 1092,1,-1,0 }, { 1092,56,-1,0 }, { 1092,56,14,0 } },
    DIG_SITES = { { 667,0,-1,0 }, { 667,26,-1,0 }, { 667,26,14,0 } },
    SLAYER_MASTER_TELEPORT = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,3,-1,0 } },
    SLAYER_CAPE_MANDRITH = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,4,-1,0 }, { 720,14,-1,0 } },
    SLAYER_CAPE_LANIAKEA = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,5,-1,0 }, { 720,21,-1,0 } },
    DUNGEONEERING_CAPE_TELEPORT = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,3,-1,0 } },
    DUNGEONEERING_CAPE_AL_KHARID = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,8,-1,0 }, { 720,30,-1,0 } },
    DUNGEONEERING_CAPE_DAEMONHEIM = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,8,-1,0 }, { 720,30,-1,0 } },
    DUNGEONEERING_CAPE_DWARVEN = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,5,-1,0 }, { 720,21,-1,0 } },
    DUNGEONEERING_CAPE_KARAMJA = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,7,-1,0 }, { 720,27,-1,0 } },
    DUNGEONEERING_CAPE_MINING_GUILD = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,10,-1,0 }, { 720,36,-1,0 } },
    DUNGEONEERING_CAPE_KALGERION = { { 720,2,-1,0 }, { 720,16,-1,0 }, { 720,12,-1,0 }, { 720,42,-1,0 } },
    GEM_CUTTING = { { 1371,7,-1,0 }, { 1371,0,-1,0 }, { 1371,15,-1,0 }, { 1371,25,-1,0 }, { 1371,10,-1,0 }, { 1371,11,-1,0 }, { 1371,27,-1,0 }, { 1371,27,3,0 } },
    LAPIS_LAZULI_CUTTING = { { 1371,7,-1,0 }, { 1371,0,-1,0 }, { 1371,15,-1,0 }, { 1371,25,-1,0 }, { 1371,8,-1,0 }, { 1371,9,-1,0 }, { 1371,9,3,0 } },
    SUMMONING_POINTS = { { 1430,0,-1,0 }, { 1430,4,-1,0 }, { 1430,18,-1,0 }, { 1430,20,-1,0 }, { 1430,20,8,0 } },
    SUMMONING_FAMILIAR = { { 662,0,-1,0 }, { 662,43,-1,0 }, { 662,50,-1,0 }, { 662,58,-1,0 } },
    LRC_ROPE_WARNING = { { 1262,8,-1,0 }, { 1262,11,-1,0 }, { 1262,11,14,0 } }
}

DATA.VARBIT_IDS.INVENTORY_STATE = 21816

DATA.GEM_BAG_INFO = {
    [18338] = { name = "Gem bag", capacity = 100, useVarbits = false },
    [31455] = { name = "Upgraded gem bag", perGemCapacity = 60, useVarbits = true }
}

DATA.GEM_BAG_VARBITS = {
    sapphire = 22581,
    emerald = 22582,
    ruby = 22583,
    diamond = 22584,
    dragonstone = 22585
}

DATA.MINING_STAMINA_LEVELS = {
    {level = 88, stamina = 110},
    {level = 71, stamina = 100},
    {level = 67, stamina = 90},
    {level = 57, stamina = 80},
    {level = 46, stamina = 70},
    {level = 33, stamina = 60},
    {level = 26, stamina = 50},
    {level = 19, stamina = 40},
    {level = 15, stamina = 30}
}

DATA.MEMORY_STRAND_SLOTS = {
    { varbit = 33764, interfaceSlot = 10 },  -- Slot 1
    { varbit = 33765, interfaceSlot = 11 },  -- Slot 2
    { varbit = 33766, interfaceSlot = 12 },  -- Slot 3
    { varbit = 33767, interfaceSlot = 13 },  -- Slot 4
    { varbit = 37037, interfaceSlot = 14 },  -- Slot 5
    { varbit = 37038, interfaceSlot = 15 },  -- Slot 6
    { varbit = 37039, interfaceSlot = 16 },  -- Slot 7
    { varbit = 37040, interfaceSlot = 17 }   -- Slot 8
}

DATA.JUJU_POTIONS = {
    juju = {
        buffId = 20004,
        refreshMin = 1,
        refreshMax = 13,
        potions = {
            {id = 23131, dose = 6}, -- flask 6
            {id = 23132, dose = 5}, -- flask 5
            {id = 23133, dose = 4}, -- flask 4
            {id = 20003, dose = 4}, -- potion 4
            {id = 23134, dose = 3}, -- flask 3
            {id = 20004, dose = 3}, -- potion 3
            {id = 23135, dose = 2}, -- flask 2
            {id = 20005, dose = 2}, -- potion 2
            {id = 23136, dose = 1}, -- flask 1
            {id = 20006, dose = 1}, -- potion 1
        },
    },
    perfect = {
        buffId = 32773,
        refreshMin = 3,
        refreshMax = 120,
        potions = {
            {id = 32883, dose = 6}, -- flask 6
            {id = 32881, dose = 5}, -- flask 5
            {id = 32879, dose = 4}, -- flask 4
            {id = 32775, dose = 4}, -- potion 4
            {id = 32877, dose = 3}, -- flask 3
            {id = 32773, dose = 3}, -- potion 3
            {id = 32875, dose = 2}, -- flask 2
            {id = 32771, dose = 2}, -- potion 2
            {id = 32873, dose = 1}, -- flask 1
            {id = 32769, dose = 1}, -- potion 1
        },
    },
}

-- Build a set of all juju potion IDs for keep-items
DATA.ALL_JUJU_IDS = {}
for _, def in pairs(DATA.JUJU_POTIONS) do
    for _, potion in ipairs(def.potions) do
        DATA.ALL_JUJU_IDS[potion.id] = true
    end
end

DATA.SUMMONING_BUFF_ID = 26095
DATA.SUMMONING_REFRESH_MIN = 3
DATA.SUMMONING_REFRESH_MAX = 120

DATA.SUMMONING_FAMILIARS = {
    desert_wyrm = {
        name = "Desert wyrm",
        pouchId = 12049,
        pointsCost = 10,
        levelReq = 18,
    },
    void_ravager = {
        name = "Void ravager",
        pouchId = 12818,
        pointsCost = 40,
        levelReq = 34,
    },
    obsidian_golem = {
        name = "Obsidian golem",
        pouchId = 12792,
        pointsCost = 80,
        levelReq = 73,
    },
    gargoyle = {
        name = "Gargoyle",
        pouchId = 49408,
        pointsCost = 100,
        levelReq = 75,
    },
    lava_titan = {
        name = "Lava titan",
        pouchId = 12788,
        pointsCost = 90,
        levelReq = 83,
    },
}

DATA.SUMMONING_REFRESH_LOCATIONS = {
    wars_retreat = {
        name = "War's Retreat",
        routeKey = "TO_WARS_RETREAT_BANK",
        skip_if = { nearCoord = {x = 3294, y = 10127} },
        bank = {
            object = "Bank chest",
            action = "Use",
        },
        refreshObject = {
            name = "Altar of War",
            id = 114748,
            type = 0,
            action = "Pray",
        },
        unlockChecks = {
            { varbit = 45680, value = 1, message = "War's Retreat not unlocked" },
            { varbit = 45682, value = 1, message = "Altar of War not unlocked" },
        },
    },
}

-- Build a set of all summoning pouch IDs for keep-items
DATA.ALL_SUMMONING_POUCH_IDS = {}
for _, def in pairs(DATA.SUMMONING_FAMILIARS) do
    DATA.ALL_SUMMONING_POUCH_IDS[def.pouchId] = true
end

-- ============================================================================
-- RESOURCE LOCATOR
-- ============================================================================

DATA.RESOURCE_LOCATOR = {
    EQUIPMENT_SLOT = 3,
    MAX_CHARGES = 50,
    TELEPORT_ANIM = 11885,

    -- Ordered by tier (lowest first). scanForLocator iterates in order.
    -- To add a new tier: append entry here, everything else derives from this.
    LOCATORS = {
        { name = "Inferior locator", id = 15005, energyId = 29315, energyPerCharge = 1,
          ores = { copper = true, tin = true, iron = true } },
        { name = "Poor locator",     id = 15006, energyId = 29317, energyPerCharge = 2,
          ores = { copper = true, tin = true, iron = true, silver = true, clay = true } },
        { name = "Good locator",     id = 15007, energyId = 29319, energyPerCharge = 3,
          ores = { copper = true, tin = true, iron = true, silver = true, clay = true, gold = true, mithril = true } },
        { name = "Superior locator", id = 15008, energyId = 29321, energyPerCharge = 4,
          ores = { copper = true, tin = true, iron = true, silver = true, clay = true, gold = true, mithril = true, adamantite = true, runite = true } },
    },

    -- Ore key to interface action params for selecting ore in locator window.
    -- To add a new ore destination: add one entry here.
    DESTINATIONS = {
        copper     = { a = 0x2e, b = 0x1b4, c = 1, d = 844, e = 28, f = -1 },
        tin        = { a = 0x2e, b = 0x1b6, c = 1, d = 844, e = 29, f = -1 },
        iron       = { a = 0x2e, b = 0x1b8, c = 1, d = 844, e = 30, f = -1 },
        silver     = { a = 0x2e, b = 0x1ba, c = 1, d = 844, e = 31, f = -1 },
        clay       = { a = 0x2e, b = 0x1b2, c = 1, d = 844, e = 32, f = -1 },
        gold       = { a = 0x2e, b = 0x1bc, c = 1, d = 844, e = 33, f = -1 },
        mithril    = { a = 0x2e, b = 0x1bf, c = 1, d = 844, e = 34, f = -1 },
        adamantite = { a = 0x2e, b = 0x1c1, c = 1, d = 844, e = 35, f = -1 },
        runite     = { a = 0x2e, b = 0x1c3, c = 1, d = 844, e = 36, f = -1 },
    },

    -- Known landing coords per ore, used for retry logic when targeting a specific location.
    -- Multiple destinations per ore are possible (locator picks randomly).
    -- To add a new known landing: append entry here.
    TELEPORT_TARGETS = {
        { ore = "copper",     coord = { x = 3229, y = 3150 } },
        { ore = "copper",     coord = { x = 2276, y = 4514 } },
        { ore = "tin",        coord = { x = 3229, y = 3150 } },
        { ore = "tin",        coord = { x = 2276, y = 4514 } },
        { ore = "iron",       coord = { x = 3148, y = 3150 } },
        { ore = "iron",       coord = { x = 3179, y = 3369 } },
        { ore = "silver",     coord = { x = 3299, y = 3308 } },
        { ore = "silver",     coord = { x = 2907, y = 3345 } },
        { ore = "clay",       coord = { x = 3232, y = 3151 } },
        { ore = "clay",       coord = { x = 2277, y = 4513 } },
        { ore = "gold",       coord = { x = 3303, y = 3307 } },
        { ore = "gold",       coord = { x = 2971, y = 3236 } },
        { ore = "mithril",    coord = { x = 3281, y = 3369 } },
        { ore = "mithril",    coord = { x = 2696, y = 3331 } },
        { ore = "adamantite", coord = { x = 2971, y = 3236 } },
        { ore = "adamantite", coord = { x = 3321, y = 2872 }, questCheck = { id = 391, name = "Crocodile Tears" } },
        { ore = "runite",     coord = { x = 2860, y = 9578 }, combatCheck = { minLevel = 31 } },
        { ore = "runite",     coord = { x = 2628, y = 3140 } },
    },

    -- Mining location key to { ore, coord } for alternate route mode.
    -- Uses lowest-tier locator ore that lands near each location.
    -- To add a new alternate route: add entry here + route def in mining_routes + routeOption in mining_locations.
    ALTERNATE_ROUTES = {
        lumbridge_se                = { ore = "copper",  coord = { x = 3229, y = 3150 } },
        lumbridge_sw                = { ore = "iron",    coord = { x = 3148, y = 3150 } },
        varrock_sw                  = { ore = "iron",    coord = { x = 3179, y = 3369 } },
        varrock_se                  = { ore = "mithril", coord = { x = 3281, y = 3369 } },
        al_kharid                   = { ore = "silver",  coord = { x = 3299, y = 3308 } },
        al_kharid_gem_rocks         = { ore = "silver",  coord = { x = 3299, y = 3308 } },
        al_kharid_resource_dungeon  = { ore = "silver",  coord = { x = 3299, y = 3308 } },
        rimmington                  = { ore = "gold",    coord = { x = 2971, y = 3236 } },
        karamja_volcano             = { ore = "runite",  coord = { x = 2860, y = 9578 } },
    },

    MAX_DISTANCE = 20,

    INTERFACES = {
        LOCATOR_WINDOW    = { { 844,3,-1,0 }, { 844,52,-1,0 }, { 844,52,14,0 } },
        WARNING           = { { 1186,2,-1,0 }, { 1186,3,-1,0 } },
        CONFIRM_DONT_ASK  = { { 1188,5,-1,0 }, { 1188,2,-1,0 }, { 1188,0,-1,0 }, { 1188,18,-1,0 }, { 1188,22,-1,0 }, { 1188,35,-1,0 } },
        CONFIRM_TRAVEL    = { { 1188,5,-1,0 }, { 1188,2,-1,0 }, { 1188,0,-1,0 }, { 1188,8,-1,0 }, { 1188,12,-1,0 }, { 1188,6,-1,0 } },
        RECHARGE_DIALOG   = { { 1603,3,-1,0 }, { 1603,2,-1,0 } },
        CHAT_DIALOG       = { { 1189,2,-1,0 }, { 1189,3,-1,0 } },
        RECHARGE_CONFIRM  = { { 1189,2,-1,0 }, { 1189,3,-1,0 } },
        RECHARGE_CONFIRM2 = { { 1188,5,-1,0 }, { 1188,3,-1,0 }, { 1188,3,14,0 } },
    },
}

-- Derived lookup sets, built once from LOCATORS, used by banking/keepItems
DATA.ALL_LOCATOR_IDS = {}
DATA.ALL_ENERGY_IDS = {}
for _, loc in ipairs(DATA.RESOURCE_LOCATOR.LOCATORS) do
    DATA.ALL_LOCATOR_IDS[loc.id] = true
    DATA.ALL_ENERGY_IDS[loc.energyId] = true
end

return DATA
