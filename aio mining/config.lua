-- Mining Script Configuration UI

SM:AddTab("Main")
SM:Dropdown("Mining Location", "MiningLocation", {"al_kharid", "al_kharid_resource_dungeon", "anachronia_sw", "daemonheim_east", "daemonheim_northeast", "daemonheim_northwest", "daemonheim_novite_west", "daemonheim_resource_dungeon", "daemonheim_south", "daemonheim_southeast", "daemonheim_southwest", "daemonheim_west", "dwarven_mine", "dwarven_resource_dungeon", "empty_throne_room", "lumbridge_se", "lumbridge_sw", "mining_guild", "mining_guild_resource_dungeon", "piscatoris_south", "port_phasmatys_south", "rimmington", "varrock_se", "varrock_sw", "wilderness_hobgoblin", "wilderness_pirates_hideout", "wilderness_south", "wilderness_south_west", "wilderness_volcano"}, "al_kharid")
SM:Dropdown("Ore", "Ore", {"copper", "tin", "iron", "coal", "silver", "mithril", "adamant", "luminite", "gold", "runite", "orichalcite", "drakolith", "necrite", "phasmatite", "banite", "dark_animica", "light_animica", "novite", "bathus", "marmaros", "kratonium", "fractite", "zephyrium", "argonite", "katagon", "gorgonite", "promethium", "platinum"}, "dark_animica")
SM:Dropdown("Banking Location", "BankingLocation", {"archaeology_campus", "artisans_guild_bank", "artisans_guild_furnace", "daemonheim_banker", "edgeville", "falador_east", "falador_west", "fort_forinthry", "fort_forinthry_furnace", "memorial_to_guthix", "player_owned_farm", "wilderness_pirates_hideout_anvil"}, "archaeology_campus")

SM:AddTab("Options")
SM:Checkbox("Drop Ores", "DropOres", false)
SM:Checkbox("Use Ore Box", "UseOreBox", true)
SM:Checkbox("Chase Rockertunities", "ChaseRockertunities", true)
SM:Checkbox("3-tick Mining", "ThreeTickMining", false)
SM:Dropdown("Refresh Stamina At", "StaminaRefreshPercent", {"70%", "75%", "80%", "85%", "90%", "95%"}, "85%")
SM:TextInput("Bank PIN", "BankPin", "")
