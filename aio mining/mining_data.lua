local DATA = {}

DATA.ROCKERTUNITY_IDS = {7164, 7165}
DATA.ARCH_JOURNAL_ID = 49429
DATA.RING_OF_KINSHIP_ID = 15707
DATA.MEMORY_STRAND_ID = 39486

DATA.DUNGEONEERING_ORES = {
    "novite", "bathus", "marmaros", "kratonium", "fractite",
    "zephyrium", "argonite", "katagon", "gorgonite", "promethium"
}

DATA.VARBIT_IDS = {
    MINING_PROGRESS = 43187,
    AUTO_RETALIATE = 42166,
    COMBAT_LEVEL = 9611,
    POF_BANK_UNLOCKED = 41690,

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
    DIG_SITES = { { 667,0,-1,0 }, { 667,26,-1,0 }, { 667,26,14,0 } }
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

return DATA
