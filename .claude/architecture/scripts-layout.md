# Content Scripts Layout (src/server/scripts/)

~492 files organized by continent/category. Scripts follow a registration pattern:
1. Class inherits from CreatureScript, SpellScript, InstanceMapScript, etc.
2. AddSC_*() function registers the script
3. Regional *_script_loader.cpp calls all AddSC_*() functions

## Categories

### Commands/ (52 files)
GM/admin chat commands: .account, .ban, .character, .gm, .go, .lookup, .npc, .quest, .reload, .reset, .server, .teleport, etc.

### Spells/ (14 files)
Spell scripts organized by class:
- spell_dk.cpp, spell_druid.cpp, spell_hunter.cpp, spell_mage.cpp
- spell_paladin.cpp, spell_priest.cpp, spell_rogue.cpp, spell_shaman.cpp
- spell_warlock.cpp, spell_warrior.cpp
- spell_generic.cpp (cross-class), spell_holiday.cpp, spell_item.cpp, spell_pet.cpp

### Pet/ (7 files)
Pet-specific scripts for hunter, DK, mage, and generic pets.

### World/ (23 files)
Global scripts: achievement_scripts, areatrigger_scripts, boss_emerald_dragons, guards, item_scripts, npcs_special, npc_professions, npc_taxi, player_scripts, server_mail, etc.

### Events/ (21 files)
Seasonal/holiday event scripts, firework shows.

### OutdoorPvP/ (15 files)
Outdoor PvP zone controllers (Eastern Plaguelands, Hellfire Peninsula, Nagrand, Silithus, Zangarmarsh, Grizzly Hills).

## Dungeon/Raid Scripts by Continent

### EasternKingdoms/ (163 files, 17 instances)
| Instance | Files | Notable |
|---|---|---|
| BlackrockMountain/ | 55 | BRD, BRS, BWL, Molten Core |
| Karazhan/ | 16 | Full raid with chess event |
| SunwellPlateau/ | 8 | End-game TBC raid |
| ZulGurub/ | 16 | 20-man raid |
| ZulAman/ | 9 | 10-man raid |
| ScarletMonastery/ | 2 | 4-wing dungeon |
| Scholomance/ | 5 | |
| Stratholme/ | 4 | |
| ShadowfangKeep/ | 3 | |
| Deadmines/ | 3 | |
| MagistersTerrace/ | 6 | |
| ScarletEnclave/ | 5 | DK starting zone |
| Others | ~27 | Gnomeregan, Uldaman, SunkenTemple, TheStockade |

### Kalimdor/ (92 files, 12 instances)
| Instance | Files | Notable |
|---|---|---|
| CavernsOfTime/ | 28 | Old Hillsbrad, Black Morass, Hyjal, Culling of Stratholme |
| TempleOfAhnQiraj/ | 13 | AQ40 |
| RuinsOfAhnQiraj/ | 9 | AQ20 |
| OnyxiasLair/ | 3 | |
| Others | ~39 | BFD, DM, Maraudon, RFC, RFD, RFK, WC, ZF |

### Outland/ (118 files, 6 instance groups)
| Instance | Files | Notable |
|---|---|---|
| CoilfangReservoir/ | 27 | Slave Pens, Underbog, Steamvault, SSC |
| TempestKeep/ | 27 | Mechanar, Botanica, Arcatraz, The Eye |
| Auchindoun/ | 20 | Mana-Tombs, Auchenai, Sethekk, Shadow Lab |
| HellfireCitadel/ | 19 | Ramparts, Blood Furnace, Shattered Halls, Magtheridon |
| BlackTemple/ | 11 | End-game TBC raid |
| GruulsLair/ | 4 | |

### Northrend/ (185 files, 13 instances) - Largest
| Instance | Files | Notable |
|---|---|---|
| Ulduar/ | 29 | Complex raid with hard modes |
| IcecrownCitadel/ | 16 | End-game WotLK raid |
| Naxxramas/ | 17 | 4-wing raid |
| Nexus/ | 17 | Nexus, Oculus, Eye of Eternity |
| FrozenHalls/ | 16 | Forge of Souls, Pit of Saron, Halls of Reflection |
| CrusadersColiseum/ | 14 | Trial of the Champion/Crusader |
| UtgardeKeep/ | 13 | UK and UP |
| AzjolNerub/ | 12 | AN and Old Kingdom |
| ChamberOfAspects/ | 9 | Obsidian Sanctum, Ruby Sanctum |
| VioletHold/ | 10 | |
| Gundrak/ | 7 | |
| VaultOfArchavon/ | 6 | |
| DraktharonKeep/ | 6 | |
